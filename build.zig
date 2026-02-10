const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "visicalc",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    exe.root_module.linkSystemLibrary("ncurses", .{});

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run VisiCalc");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const test_step = b.step("test", "Run unit tests");

    const functions_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/functions.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(functions_tests).step);

    const data_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/data.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(data_tests).step);

    // Clean
    const clean_step = b.step("clean", "Remove build artifacts");
    clean_step.dependOn(&b.addSystemCommand(&.{ "rm", "-rf", "zig-out", ".zig-cache" }).step);
}
