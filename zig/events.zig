// Passive event listener for macOS using CGEventTap.
// Listens for mouse, keyboard, and scroll events on a background thread
// via a kCGEventTapOptionListenOnly tap. Requires Accessibility permissions.

const std = @import("std");
const builtin = @import("builtin");

const c = if (builtin.target.os.tag == .macos) @cImport({
    @cInclude("CoreGraphics/CoreGraphics.h");
    @cInclude("CoreFoundation/CoreFoundation.h");
    @cInclude("ApplicationServices/ApplicationServices.h");
}) else struct {};

// ── Types ──

pub const EventType = enum(u8) {
    mouse_move = 0,
    mouse_down = 1,
    mouse_up = 2,
    scroll = 3,
    key_down = 4,
    key_up = 5,
    flags_changed = 6,
};

pub const EventData = struct {
    type: EventType,
    timestamp: f64, // seconds since system boot
    x: f64,
    y: f64,
    button: u8, // 0=left, 1=right, 2=middle
    click_count: u8,
    scroll_dx: f64,
    scroll_dy: f64,
    keycode: u16,
    modifiers: u32,
};

pub const EventCallback = *const fn (*const EventData) void;

// ── State machine ──

const State = enum(u8) {
    idle = 0,
    starting = 1,
    running = 2,
    stopping = 3,
};

var state = std.atomic.Value(u8).init(@intFromEnum(State.idle));
var stored_callback: ?EventCallback = null;
var run_loop_ref: if (builtin.target.os.tag == .macos) c.CFRunLoopRef else ?*anyopaque = null;
var thread: ?std.Thread = null;

// ── CGEventTap callback ──

fn eventTapCallback(
    _: c.CGEventTapProxy,
    cg_type: c.CGEventType,
    cg_event: c.CGEventRef,
    _: ?*anyopaque,
) callconv(.c) c.CGEventRef {
    const cb = stored_callback orelse return cg_event;

    const mapped = mapEventType(cg_type) orelse return cg_event;

    const location = c.CGEventGetLocation(cg_event);
    const raw_timestamp = c.CGEventGetTimestamp(cg_event); // nanoseconds
    const timestamp: f64 = @as(f64, @floatFromInt(raw_timestamp)) / 1_000_000_000.0;
    const flags: u64 = @bitCast(c.CGEventGetFlags(cg_event));
    const modifiers: u32 = @truncate(flags);

    const button = mapButton(cg_type);

    const click_count: u8 = if (mapped == .mouse_down)
        @intCast(std.math.clamp(c.CGEventGetIntegerValueField(cg_event, c.kCGMouseEventClickState), 0, 255))
    else
        0;

    const scroll_dy: f64 = if (mapped == .scroll)
        @floatFromInt(c.CGEventGetIntegerValueField(cg_event, c.kCGScrollWheelEventDeltaAxis1))
    else
        0;

    const scroll_dx: f64 = if (mapped == .scroll)
        @floatFromInt(c.CGEventGetIntegerValueField(cg_event, c.kCGScrollWheelEventDeltaAxis2))
    else
        0;

    const keycode: u16 = if (mapped == .key_down or mapped == .key_up or mapped == .flags_changed)
        @intCast(std.math.clamp(c.CGEventGetIntegerValueField(cg_event, c.kCGKeyboardEventKeycode), 0, 0xFFFF))
    else
        0;

    const event_data = EventData{
        .type = mapped,
        .timestamp = timestamp,
        .x = location.x,
        .y = location.y,
        .button = button,
        .click_count = click_count,
        .scroll_dx = scroll_dx,
        .scroll_dy = scroll_dy,
        .keycode = keycode,
        .modifiers = modifiers,
    };
    cb(&event_data);

    return cg_event;
}

fn mapEventType(cg_type: c.CGEventType) ?EventType {
    return switch (cg_type) {
        c.kCGEventMouseMoved,
        c.kCGEventLeftMouseDragged,
        c.kCGEventRightMouseDragged,
        c.kCGEventOtherMouseDragged,
        => .mouse_move,

        c.kCGEventLeftMouseDown,
        c.kCGEventRightMouseDown,
        c.kCGEventOtherMouseDown,
        => .mouse_down,

        c.kCGEventLeftMouseUp,
        c.kCGEventRightMouseUp,
        c.kCGEventOtherMouseUp,
        => .mouse_up,

        c.kCGEventScrollWheel => .scroll,
        c.kCGEventKeyDown => .key_down,
        c.kCGEventKeyUp => .key_up,
        c.kCGEventFlagsChanged => .flags_changed,

        else => null,
    };
}

fn mapButton(cg_type: c.CGEventType) u8 {
    return switch (cg_type) {
        c.kCGEventLeftMouseDown,
        c.kCGEventLeftMouseUp,
        c.kCGEventLeftMouseDragged,
        => 0, // left

        c.kCGEventRightMouseDown,
        c.kCGEventRightMouseUp,
        c.kCGEventRightMouseDragged,
        => 1, // right

        c.kCGEventOtherMouseDown,
        c.kCGEventOtherMouseUp,
        c.kCGEventOtherMouseDragged,
        => 2, // middle

        else => 0,
    };
}

// ── Start / stop lifecycle ──

pub const StartError = error{
    AlreadyRunning,
    AccessibilityPermissionRequired,
    EventTapFailed,
    RunLoopSourceFailed,
    ThreadSpawnFailed,
};

pub fn start(cb: EventCallback) StartError!void {
    if (comptime builtin.target.os.tag != .macos) {
        return error.EventTapFailed; // unsupported platform
    }

    // Transition idle → starting (atomically)
    const prev = state.cmpxchgStrong(
        @intFromEnum(State.idle),
        @intFromEnum(State.starting),
        .acquire,
        .monotonic,
    );
    if (prev != null) return error.AlreadyRunning;

    // Check accessibility permissions before spawning thread
    if (c.AXIsProcessTrusted() == 0) {
        state.store(@intFromEnum(State.idle), .release);
        return error.AccessibilityPermissionRequired;
    }

    stored_callback = cb;

    thread = std.Thread.spawn(.{}, threadMain, .{}) catch {
        stored_callback = null;
        state.store(@intFromEnum(State.idle), .release);
        return error.ThreadSpawnFailed;
    };

    // Spin-wait for the thread to signal running or fall back to idle (failure)
    while (true) {
        const s = state.load(.acquire);
        if (s == @intFromEnum(State.running)) return; // success
        if (s == @intFromEnum(State.idle)) {
            // Thread failed and cleaned up
            if (thread) |t| t.join();
            thread = null;
            stored_callback = null;
            return error.EventTapFailed;
        }
        std.Thread.yield() catch {};
    }
}

fn threadMain() void {
    // Create event tap
    const event_mask: u64 = (1 << c.kCGEventMouseMoved) |
        (1 << c.kCGEventLeftMouseDown) |
        (1 << c.kCGEventLeftMouseUp) |
        (1 << c.kCGEventRightMouseDown) |
        (1 << c.kCGEventRightMouseUp) |
        (1 << c.kCGEventOtherMouseDown) |
        (1 << c.kCGEventOtherMouseUp) |
        (1 << c.kCGEventLeftMouseDragged) |
        (1 << c.kCGEventRightMouseDragged) |
        (1 << c.kCGEventOtherMouseDragged) |
        (1 << c.kCGEventScrollWheel) |
        (1 << c.kCGEventKeyDown) |
        (1 << c.kCGEventKeyUp) |
        (1 << c.kCGEventFlagsChanged);

    const tap = c.CGEventTapCreate(
        c.kCGSessionEventTap,
        c.kCGHeadInsertEventTap,
        c.kCGEventTapOptionListenOnly,
        @bitCast(event_mask),
        eventTapCallback,
        null,
    );

    if (tap == null) {
        // Signal failure
        state.store(@intFromEnum(State.idle), .release);
        return;
    }

    const source = c.CFMachPortCreateRunLoopSource(c.kCFAllocatorDefault, tap, 0);
    if (source == null) {
        c.CFRelease(tap);
        state.store(@intFromEnum(State.idle), .release);
        return;
    }

    const loop = c.CFRunLoopGetCurrent();
    run_loop_ref = loop;
    c.CFRunLoopAddSource(loop, source, c.kCFRunLoopCommonModes);
    c.CGEventTapEnable(tap, true);

    // Signal running to the caller
    state.store(@intFromEnum(State.running), .release);

    // Block — CFRunLoopRun returns when CFRunLoopStop is called from stop()
    c.CFRunLoopRun();

    // Cleanup
    c.CGEventTapEnable(tap, false);
    c.CFRunLoopRemoveSource(loop, source, c.kCFRunLoopCommonModes);
    c.CFRelease(source);
    c.CFRelease(tap);
    run_loop_ref = null;
}

pub fn stop() void {
    if (comptime builtin.target.os.tag != .macos) return;

    // Transition running → stopping
    const prev = state.cmpxchgStrong(
        @intFromEnum(State.running),
        @intFromEnum(State.stopping),
        .acquire,
        .monotonic,
    );
    if (prev != null) return; // not running

    // Tell the run loop to stop
    if (run_loop_ref) |ref| {
        c.CFRunLoopStop(ref);
    }

    // Join the background thread
    if (thread) |t| {
        t.join();
    }
    thread = null;
    stored_callback = null;
    state.store(@intFromEnum(State.idle), .release);
}

pub fn isRunning() bool {
    return state.load(.acquire) == @intFromEnum(State.running);
}
