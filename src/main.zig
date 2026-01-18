const std = @import("std");
const zigmine = @import("zigmine");

// test "vectors" {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
//     const allocator = gpa.allocator();
//     const neis = zigmine.stl.vec.neis;
//     var array: []neis = undefined;

//     array = try allocator.alloc(neis, 40);
//     defer allocator.free(array);

//     array[0] = neis{ .cells = [8]u16{ 1, 20, 23, 0, 0, 0, 0, 0 }, .size = 3 };
//     array[8] = neis{ .cells = [8]u16{ 2, 20, 23, 0, 0, 0, 0, 0 }, .size = 3 };

//     array = try allocator.realloc(array, 92);
//     array[80] = neis{ .cells = [8]u16{ 3, 20, 23, 0, 0, 0, 0, 0 }, .size = 3 };

//     try std.testing.expect(array[0].cells[0] == 1);
//     try std.testing.expect(array[80].cells[0] == 3);
//     std.debug.print("Tested", .{});
// }

// test "stltest" {
//     const vecneis = zigmine.stl.vec.vecneis;
//     zigmine.init_all();
//     var array: vecneis = try zigmine.stl.vec.vecneis.new(40);
//     defer array.free();

//     array.add3(1, 20, 23);

//     try std.testing.expect(array.at(0).cells[1] == 20);
//     // try std.testing.expect(array[80].cells[0] == 3);
//     std.debug.print("Tested", .{});
// }

pub fn main() !void {
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
