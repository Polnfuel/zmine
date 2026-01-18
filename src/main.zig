const std = @import("std");
const zigmine = @import("zigmine");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = false }).init;
    const allocator = gpa.allocator();
    zigmine.stl.set_alloc(allocator);

    var stdout_buffer: [2000]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const prms = zigmine.FieldParams{ .w = 30, .h = 16, .m = 99 };
    var eng = try zigmine.eng.Engine.init(prms.w, prms.h, prms.m);
    defer eng.deinit();

    var bot = try zigmine.bot.Bot.init(prms.w, prms.h, prms.m, zigmine.eng.Engine.get_cache_ptr());
    defer bot.deinit();

    const attempt_count: u32 = 1000;
    var succesful: u32 = 0;
    var queries: u32 = 0;
    var max_row: u32 = 0;
    var row: u32 = 0;

    const start = try std.time.Instant.now();

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
        // try eng.print_field();
    }

    const end = try std.time.Instant.now();
    const micros = end.since(start) / 1000;

    const suc: f32 = @floatFromInt(succesful * 100);
    const percent = (suc / @as(f32, attempt_count));
    try stdout.print("\n{d} sucess ({d}/{d})\n", .{ percent, succesful, attempt_count });
    try stdout.print("{d} queries to probs()\n", .{queries});
    try stdout.print("{d} maximum row\n", .{max_row});
    try stdout.print("{d} micros\n", .{micros});
    try stdout.flush();
}
