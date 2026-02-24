const std = @import("std");
const stl = @import("stl");
const Engine = @import("engine");
const Bot = @import("bot");

const FieldParams = struct {
    w: u8,
    h: u8,
    m: u16,
};

var win_width: i32 = undefined;
var win_heigth: i32 = undefined;
var third: i32 = undefined;
var fld_woffset: i32 = undefined;
var stat_woffset: i32 = undefined;
var prms: FieldParams = undefined;

fn sleeptime(seconds: f32) void {
    const sec = @floor(seconds);
    const nsec: i64 = @intFromFloat((seconds - sec) * 1000000000.0);
    var req: std.os.linux.timespec = undefined;
    req.sec = @intFromFloat(sec);
    req.nsec = nsec;
    while (std.os.linux.nanosleep(&req, &req) == -1) {
        continue;
    }
}

fn print_starting_screen(buffer: *std.io.Writer) !void {
    _ = try buffer.write("\x1b[2J");
    try buffer.print("\x1b[1;{}HConsole size: ({}x{})", .{ third - 10, win_width, win_heigth });
    try buffer.print("\x1b[4;{}H\x1b[1m\x1b[37mMINESWEEPER\x1b[5;{}HGAME\x1b[m\x1b[7;{}H(enter)", .{ third - 5, third - 2, third - 4 });
    try buffer.flush();
}

fn print_in_game_stat(buffer: *std.io.Writer, att: i32, attall: i32, suc: i32, row: i32, maxrow: i32) !void {
    var winrate = @as(f32, @as(f32, @floatFromInt(suc)) / @as(f32, @floatFromInt(att)) * 100.0);
    if (std.math.isNan(winrate)) {
        winrate = 0.0;
    }
    _ = try buffer.write("\x1b[0m");
    try buffer.print("\x1b[3;{}H  Game #{}/{}", .{ stat_woffset, att + 1, attall });
    try buffer.print("\x1b[4;{}H   Row: {} (max: {})", .{ stat_woffset, row, maxrow });
    try buffer.print("\x1b[5;{}HWinrate {}/{}({:.2}%)", .{ stat_woffset, suc, att, winrate });
    try buffer.print("\x1b[{};{}H", .{ prms.h + 4, @divFloor(win_width, 4) - 3 });
    try buffer.flush();
}

fn print_post_game_stat(buffer: *std.io.Writer, att: i32, attall: i32, suc: i32, row: i32, maxrow: i32) !void {
    _ = try buffer.write("\x1b[0m");
    try buffer.print("\x1b[3;{}H  Game #{}/{}", .{ stat_woffset, att + 1, attall });
    try buffer.print("\x1b[4;{}H   Row: {} (max: {})", .{ stat_woffset, row, maxrow });
    try buffer.print("\x1b[5;{}HWinrate {}/{}({:.2}%)", .{ stat_woffset, suc, att + 1, @as(f32, @as(f32, @floatFromInt(suc)) / @as(f32, @floatFromInt(att + 1)) * 100.0) });
    try buffer.print("\x1b[{};{}H", .{ prms.h + 4, @divFloor(win_width, 4) - 3 });
    try buffer.flush();
}

fn print_field(buffer: *std.io.Writer, game_field: stl.vec.vec8, w: u8) !void {
    _ = try buffer.write("\x1b[2H\x1b[0J");
    const h = @divFloor(game_field.array.len, w);
    var i: usize = 0;
    while (i < h) : (i += 1) {
        try buffer.print("\x1b[{};{}H", .{ i + 3, fld_woffset });
        var j: usize = 0;
        while (j < w) : (j += 1) {
            const val = game_field.at(i * w + j);
            switch (val) {
                0 => {
                    _ = try buffer.write("  ");
                },
                1 => {
                    _ = try buffer.write("\x1b[34m1 \x1b[0m");
                },
                2 => {
                    _ = try buffer.write("\x1b[32m2 \x1b[0m");
                },
                3 => {
                    _ = try buffer.write("\x1b[31m3 \x1b[0m");
                },
                4 => {
                    _ = try buffer.write("\x1b[96m4 \x1b[0m");
                },
                5 => {
                    _ = try buffer.write("\x1b[35m5 \x1b[0m");
                },
                6 => {
                    _ = try buffer.write("\x1b[36m6 \x1b[0m");
                },
                7 => {
                    _ = try buffer.write("7 ");
                },
                8 => {
                    _ = try buffer.write("8 ");
                },
                9 => {
                    _ = try buffer.write("\x1b[0;100m  \x1b[0m");
                },
                11 => {
                    _ = try buffer.write("\x1b[0;101m  \x1b[0m");
                },
                12 => {
                    _ = try buffer.write("\x1b[0;101m  \x1b[0m");
                },
                27 => {
                    _ = try buffer.write("\x1b[0;42m  \x1b[0m");
                },
                28...36 => {
                    try buffer.print("\x1b[30;100m{d} \x1b[0m", .{val - 27});
                },
                37...126 => {
                    try buffer.print("\x1b[30;100m{d}\x1b[0m", .{val - 27});
                },
                127 => {
                    _ = try buffer.write("\x1b[0;101m  \x1b[0m");
                },
                else => {
                    _ = try buffer.write("\x1b[30;100m  \x1b[0m");
                },
            }
        }
        _ = try buffer.write("\n\x1b[0m\x1b[K");
        try buffer.flush();
    }
    try buffer.flush();
}

fn clear_stdin(buffer: *std.io.Reader) !void {
    var c = try buffer.takeByte();
    while (c != '\n') {
        c = try buffer.takeByte();
    }
}

fn to_quit(buffer: *std.io.Reader) !bool {
    const c = try buffer.takeByte();
    if (c != '\n') {
        try clear_stdin(buffer);
    }
    if (c == 'q') {
        return true;
    }
    return false;
}

pub fn main() !void {
    const allocator = std.heap.smp_allocator;
    stl.set_alloc(allocator);

    var stdout_buffer: [2048]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var stdin_buffer: [64]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
    const stdin = &stdin_reader.interface;

    var buf: std.posix.winsize = undefined;
    _ = std.posix.system.ioctl(std.posix.system.STDOUT_FILENO, std.posix.T.IOCGWINSZ, @intFromPtr(&buf));
    win_width = buf.col;
    win_heigth = buf.row;
    third = @divFloor(win_width, 3);

    prms = FieldParams{ .w = 80, .h = 30, .m = 550 };
    try Engine.init(prms.w, prms.h, prms.m);
    defer Engine.deinit();

    try Bot.init(prms.w, prms.h, prms.m, Engine.get_cache_ptr(), print_field, stdout);
    defer Bot.deinit();

    fld_woffset = @divFloor(win_width, 4) - prms.w;
    if (fld_woffset < 2) fld_woffset = 2;
    stat_woffset = fld_woffset + 2 * prms.w + 6;

    const attempt_count: u32 = 50;
    var succesful: u32 = 0;
    var queries: u32 = 0;
    var max_row: u32 = 0;
    var row: u32 = 0;

    try print_starting_screen(stdout);
    if (try to_quit(stdin)) {
        _ = try stdout.write("\x1b[2\x1b[H");
        return;
    }
    try stdout.print("\x1b[1H\x1b[K\x1b[1;{}Hwidth: {}  height: {}  mines: {}\x1b[K", .{ fld_woffset + prms.w - 15, prms.w, prms.h, prms.m });
    try stdout.flush();

    for (0..attempt_count) |attempt| {
        try Engine.start_game(0);

        while (Engine.playing) {
            const to_click = try Bot.clicks(Engine.visible_field);

            for (to_click.array[0..to_click.size]) |to| {
                try Engine.open_cell(@truncate(to));
            }
            queries += 1;

            try print_in_game_stat(stdout, @intCast(attempt), attempt_count, @intCast(succesful), @intCast(row), @intCast(max_row));
            sleeptime(0.15);
        }
        if (Engine.won) {
            succesful += 1;
            row += 1;
        } else {
            row = 0;
        }
        if (row > max_row) {
            max_row = row;
        }

        try print_field(stdout, Engine.visible_field, prms.w);
        try print_post_game_stat(stdout, @intCast(attempt + 1), attempt_count, @intCast(succesful), @intCast(row), @intCast(max_row));
        _ = try stdout.write("\x1b[0m(next)");
        try stdout.flush();
        if (try to_quit(stdin)) {
            break;
        }
    }

    const suc: f32 = @floatFromInt(succesful * 100);
    const percent = (suc / @as(f32, attempt_count));
    try stdout.print("\n{d} success ({d}/{d})\n", .{ percent, succesful, attempt_count });
    try stdout.print("{d} queries to probs()\n", .{queries});
    try stdout.print("{d} maximum row\n", .{max_row});
    try stdout.flush();
}
