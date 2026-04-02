const std = @import("std");
const events = @import("events.zig");

// Ring buffer lives in Zig — Julia polls it, no callback into Julia needed.
const RING_SIZE = 1024;

const CEvent = extern struct {
    type: c_int,
    timestamp: f64,
    x: f64,
    y: f64,
    button: c_int,
    click_count: c_int,
    scroll_dx: f64,
    scroll_dy: f64,
    keycode: c_int,
    modifiers: c_uint,
};

var ring: [RING_SIZE]CEvent = undefined;
var ring_count = std.atomic.Value(i64).init(0);

fn ringCallback(data: *const events.EventData) void {
    const n = ring_count.load(.monotonic);
    const idx: usize = @intCast(@mod(n, RING_SIZE));
    ring[idx] = .{
        .type = @intFromEnum(data.type),
        .timestamp = data.timestamp,
        .x = data.x,
        .y = data.y,
        .button = @as(c_int, data.button),
        .click_count = @as(c_int, data.click_count),
        .scroll_dx = data.scroll_dx,
        .scroll_dy = data.scroll_dy,
        .keycode = @as(c_int, data.keycode),
        .modifiers = @as(c_uint, data.modifiers),
    };
    _ = ring_count.fetchAdd(1, .release);
}

export fn uc_events_start() c_int {
    events.start(ringCallback) catch |err| {
        setError(switch (err) {
            error.AlreadyRunning => "event listener already running",
            error.AccessibilityPermissionRequired => "Accessibility permission required",
            error.ThreadSpawnFailed => "failed to spawn event listener thread",
            else => "failed to start event listener",
        });
        return -1;
    };
    return 0;
}

export fn uc_events_stop() c_int {
    events.stop();
    return 0;
}

export fn uc_events_ring() [*]const CEvent {
    return &ring;
}

export fn uc_events_count() *const i64 {
    return @ptrCast(&ring_count);
}

// ── Error handling ──

const err_buf_len = 256;
threadlocal var err_buf: [err_buf_len]u8 = undefined;
threadlocal var err_set: bool = false;
threadlocal var err_end: usize = 0;

fn setError(msg: []const u8) void {
    const n = @min(msg.len, err_buf_len - 1);
    @memcpy(err_buf[0..n], msg[0..n]);
    err_buf[n] = 0;
    err_end = n;
    err_set = true;
}

export fn uc_events_last_error() [*c]const u8 {
    if (!err_set) return null;
    return &err_buf;
}
