const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const mode: std.builtin.OptimizeMode = .ReleaseFast;

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

    const stl = b.addModule("stl", .{
        .root_source_file = b.path("src/stl.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "vec", .module = vec },
            .{ .name = "map", .module = map },
        },
    });

    const eng = b.addModule("engine", .{
        .root_source_file = b.path("src/engine.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "stl", .module = stl },
        },
    });

    const probs = b.addModule("probs", .{
        .root_source_file = b.path("src/probs.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "stl", .module = stl },
        },
    });

    const bot = b.addModule("bot", .{
        .root_source_file = b.path("src/bot.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "stl", .module = stl },
            .{ .name = "probs", .module = probs },
        },
    });

    switch (mode) {
        .Debug => {
            const exe = b.addExecutable(.{
                .name = "main",
                .root_module = b.createModule(.{
                    .root_source_file = b.path("src/main.zig"),
                    .target = target,
                    .optimize = .Debug,
                    .imports = &.{
                        .{ .name = "stl", .module = stl },
                        .{ .name = "bot", .module = bot },
                        .{ .name = "engine", .module = eng },
                    },
                }),
            });

            exe.use_llvm = true;

            b.installArtifact(exe);
            const run_step = b.step("run", "Run in Debug mode");
            const run_cmd = b.addRunArtifact(exe);
            run_step.dependOn(&run_cmd.step);
            run_cmd.step.dependOn(b.getInstallStep());
            if (b.args) |args| {
                run_cmd.addArgs(args);
            }
        },
        .ReleaseFast => {
            const exesfast = b.addExecutable(.{
                .name = "mainfast",
                .root_module = b.createModule(.{
                    .root_source_file = b.path("src/main.zig"),
                    .target = target,
                    .optimize = .ReleaseFast,
                    .imports = &.{
                        .{ .name = "stl", .module = stl },
                        .{ .name = "bot", .module = bot },
                        .{ .name = "engine", .module = eng },
                    },
                    // .single_threaded = true,
                    .strip = true,
                    .unwind_tables = .none,
                    .stack_protector = false,
                    .stack_check = false,
                    .sanitize_c = .off,
                    .sanitize_thread = false,
                    .fuzz = false,
                    .valgrind = false,
                    .red_zone = true,
                    .omit_frame_pointer = true,
                    .error_tracing = false,
                    .no_builtin = false,
                }),
            });

            b.installArtifact(exesfast);
            const run_step_fast = b.step("run", "Run in ReleaseFast mode");
            const run_cmd_fast = b.addRunArtifact(exesfast);
            run_step_fast.dependOn(&run_cmd_fast.step);
            run_cmd_fast.step.dependOn(b.getInstallStep());
            if (b.args) |args| {
                run_cmd_fast.addArgs(args);
            }
        },
        else => {},
    }
}
