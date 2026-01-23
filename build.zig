const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const vec = b.addModule("vec", .{
        .root_source_file = b.path("src/vec.zig"),
        .target = target,
    });

    const map = b.addModule("map", .{
        .root_source_file = b.path("src/map.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "vec", .module = vec },
        },
    });

    const stl = b.addModule("stl", .{ .root_source_file = b.path("src/stl.zig"), .target = target, .imports = &.{
        .{ .name = "vec", .module = vec },
        .{ .name = "map", .module = map },
    } });

    const eng = b.addModule("engine", .{ .root_source_file = b.path("src/engine.zig"), .target = target, .imports = &.{
        .{ .name = "stl", .module = stl },
    } });

    const probs = b.addModule("probs", .{ .root_source_file = b.path("src/probs.zig"), .target = target, .imports = &.{
        .{ .name = "stl", .module = stl },
    } });

    const bot = b.addModule("bot", .{ .root_source_file = b.path("src/bot.zig"), .target = target, .imports = &.{
        .{ .name = "stl", .module = stl },
        .{ .name = "probs", .module = probs },
    } });

    const mod = b.addModule("zigmine", .{ .root_source_file = b.path("src/root.zig"), .target = target, .imports = &.{
        .{ .name = "stl", .module = stl },
        .{ .name = "engine", .module = eng },
        .{ .name = "bot", .module = bot },
    } });

    const install_flds_step = b.addInstallFile(b.path("flds"), "flds");

    const exe = b.addExecutable(.{
        .name = "main",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = b.standardOptimizeOption(.{}),
            .imports = &.{
                .{ .name = "zigmine", .module = mod },
            },
            .link_libc = true,
        }),
    });
    exe.use_llvm = true;
    b.installArtifact(exe);
    b.getInstallStep().dependOn(&install_flds_step.step);
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // const exesmall = b.addExecutable(.{
    //     .name = "mainsmall",
    //     .root_module = b.createModule(.{
    //         .root_source_file = b.path("src/main.zig"),
    //         .target = target,
    //         .optimize = .ReleaseSmall,
    //         .imports = &.{
    //             .{ .name = "zigmine", .module = mod },
    //         },
    //     }),
    // });
    // b.installArtifact(exesmall);
    // const run_step_small = b.step("runsmall", "Run in release small mode");
    // const run_cmd_small = b.addRunArtifact(exesmall);
    // run_step_small.dependOn(&run_cmd_small.step);
    // run_cmd_small.step.dependOn(b.getInstallStep());
    // if (b.args) |args| {
    //     run_cmd_small.addArgs(args);
    // }

    const exesfast = b.addExecutable(.{
        .name = "mainfast",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "zigmine", .module = mod },
            },
            .link_libc = true,
            .strip = true,
            .single_threaded = true,
            .error_tracing = false,
            .omit_frame_pointer = true,
        }),
    });

    b.installArtifact(exesfast);
    b.getInstallStep().dependOn(&install_flds_step.step);
    const run_step_fast = b.step("runfast", "Run in release fast mode");
    const run_cmd_fast = b.addRunArtifact(exesfast);
    run_step_fast.dependOn(&run_cmd_fast.step);
    run_cmd_fast.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd_fast.addArgs(args);
    }

    // const test_exe = b.addTest(.{
    //     .name = "unit_tests",
    //     .root_module = b.createModule(.{
    //         .root_source_file = b.path("src/main.zig"),
    //         .target = target,
    //         .imports = &.{
    //             .{ .name = "zigmine", .module = mod },
    //         },
    //     }),
    // });

    // const install_flds_step = b.addInstallFile(b.path("flds"), "flds");

    // b.installArtifact(test_exe);
    // b.getInstallStep().dependOn(&install_flds_step.step);
    // const run_cmd_tests = b.addRunArtifact(test_exe);
    // const run_step_tests = b.step("tests", "Run unit tests");
    // run_step_tests.dependOn(&run_cmd_tests.step);
}
