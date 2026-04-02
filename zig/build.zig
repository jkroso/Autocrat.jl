const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const events_mod = b.createModule(.{
        .root_source_file = b.path("events.zig"),
        .target = target,
        .optimize = optimize,
    });
    events_mod.linkFramework("CoreGraphics", .{});
    events_mod.linkFramework("CoreFoundation", .{});
    events_mod.linkFramework("ApplicationServices", .{});

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_mod.addImport("events.zig", events_mod);

    const lib = b.addLibrary(.{
        .name = "autocrat_events",
        .root_module = lib_mod,
        .linkage = .dynamic,
    });
    lib.root_module.linkFramework("CoreGraphics", .{});
    lib.root_module.linkFramework("CoreFoundation", .{});
    lib.root_module.linkFramework("ApplicationServices", .{});

    b.installArtifact(lib);
}
