const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.addModule("zzip", .{
        .root_source_file = b.path("src/main.zig"),
    });

    // TODO: look into clearing this out; not sure what needs to stay for testing

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
