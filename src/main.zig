const std = @import("std");
const zigmine = @import("zigmine");

var win_width: i32 = undefined;
var win_heigth: i32 = undefined;
var third: i32 = undefined;
var fld_woffset: i32 = undefined;
var stat_woffset: i32 = undefined;
var prms: zigmine.FieldParams = undefined;

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
    try buffer.print("\x1b[2J", .{});
    try buffer.print("\x1b[1;{}HConsole size: ({}x{})", .{ third - 10, win_width, win_heigth });
    try buffer.print("\x1b[4;{}H\x1b[1m\x1b[37mMINESWEEPER\x1b[5;{}HGAME\x1b[m\x1b[7;{}H(enter)", .{ third - 5, third - 2, third - 4 });
    try buffer.flush();
}

fn print_stat(buffer: *std.io.Writer, att: i32, attall: i32, suc: i32, row: i32, maxrow: i32) !void {
    try buffer.print("\x1b[0m", .{});
    try buffer.print("\x1b[3;{}H  Game #{}/{}", .{ stat_woffset, att + 1, attall });
    try buffer.print("\x1b[4;{}H    Row {}/max row {}", .{ stat_woffset, row, maxrow });
    try buffer.print("\x1b[5;{}HWinrate {}/{}({:.2}%)", .{ stat_woffset, suc, att, @as(f32, @as(f32, @floatFromInt(suc)) / @as(f32, @floatFromInt(att)) * 100.0) });
    try buffer.print("\x1b[{};{}H", .{ prms.h + 4, @divFloor(win_width, 4) - 3 });
    try buffer.flush();
}

fn print_field(buffer: *std.io.Writer, game_field: zigmine.stl.vec.vec8, w: u8) !void {
    try buffer.print("\x1b[2H\x1b[0J", .{});
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

pub fn main() !void {
    const allocator = std.heap.c_allocator;
    zigmine.stl.set_alloc(allocator);

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

    prms = zigmine.FieldParams{ .w = 30, .h = 16, .m = 99 };
    var eng = try zigmine.eng.Engine.init(prms.w, prms.h, prms.m);
    defer eng.deinit();

    var bot = try zigmine.bot.Bot.init(prms.w, prms.h, prms.m, zigmine.eng.Engine.get_cache_ptr(), print_field, stdout);
    defer bot.deinit();

    fld_woffset = @divFloor(win_width, 4) - prms.w;
    if (fld_woffset < 2) fld_woffset = 2;
    stat_woffset = fld_woffset + 2 * prms.w + 6;

    const attempt_count: u32 = 1000;
    var succesful: u32 = 0;
    var queries: u32 = 0;
    var max_row: u32 = 0;
    var row: u32 = 0;

    try print_starting_screen(stdout);
    _ = try stdin.takeByte();
    try stdout.print("\x1b[1H\x1b[K\x1b[1;{}Hwidth: {}  height: {}  mines: {}\x1b[K", .{ fld_woffset + prms.w - 15, prms.w, prms.h, prms.m });
    try stdout.flush();

    // const start = try std.time.Instant.now();

    var attempt: u32 = 0;
    while (attempt < attempt_count) : (attempt += 1) {
        try eng.start_game(0);

        while (eng.playing) {
            const to_click = try bot.clicks(eng.visible_field);

            var i: u16 = 0;
            while (i < to_click.size) : (i += 1) {
                const to = to_click.at(i);
                try eng.open_cell(to);
            }
            queries += 1;

            try print_stat(stdout, @intCast(attempt), attempt_count, @intCast(succesful), @intCast(row), @intCast(max_row));
            sleeptime(0.2);
        }
        if (eng.won) {
            succesful += 1;
            row += 1;
        } else {
            row = 0;
        }
        if (row > max_row) {
            max_row = row;
        }
        try print_field(stdout, eng.visible_field, eng.field_width);
        try print_stat(stdout, @intCast(attempt + 1), attempt_count, @intCast(succesful), @intCast(row), @intCast(max_row));
        try stdout.print("\x1b[0m(next)", .{});
        try stdout.flush();
        _ = try stdin.takeByte();
    }

    // const end = try std.time.Instant.now();
    // const micros = end.since(start) / 1000;

    const suc: f32 = @floatFromInt(succesful * 100);
    const percent = (suc / @as(f32, attempt_count));
    try stdout.print("\n{d} sucess ({d}/{d})\n", .{ percent, succesful, attempt_count });
    try stdout.print("{d} queries to probs()\n", .{queries});
    try stdout.print("{d} maximum row\n", .{max_row});
    // try stdout.print("{d} micros\n", .{micros});
    try stdout.flush();
}
