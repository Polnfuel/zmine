const std = @import("std");
const stl = @import("stl");
const Engine = @import("engine");
const Bot = @import("bot");

const FieldParams = struct {
    w: u8,
    h: u8,
    m: u16,
};

pub fn main() !void {
    const allocator = std.heap.smp_allocator;
    stl.set_alloc(allocator);

    var stdout_buffer: [2000]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const prms = FieldParams{ .w = 30, .h = 16, .m = 99 };
    try Engine.init(prms.w, prms.h, prms.m);
    defer Engine.deinit();

    try Bot.init(prms.w, prms.h, prms.m, Engine.get_cache_ptr());
    defer Bot.deinit();

    const file = try std.fs.cwd().openFile("flds", .{ .mode = .read_only });
    defer file.close();

    var file_buffer = try allocator.alloc(u8, 1000 * 480);
    defer allocator.free(file_buffer);
    var reader = file.reader(file_buffer);
    var handle = &reader.interface;
    try handle.readSliceAll(file_buffer);

    const attempt_count: u32 = 1000;
    var succesful: u32 = 0;
    var queries: u32 = 0;
    var max_row: u32 = 0;
    var row: u32 = 0;

    const start = try std.time.Instant.now();

    for (0..attempt_count) |attempt| {
        try Engine.start_game(0, file_buffer[attempt * Engine.real_size .. attempt * Engine.real_size + 480]);

        while (Engine.playing) {
            const to_click = try Bot.clicks(Engine.visible_field);

            var i: u16 = 0;
            while (i < to_click.size) : (i += 1) {
                const to = to_click.at(i);
                try Engine.open_cell(to);
            }
            queries += 1;
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
    }

    const end = try std.time.Instant.now();
    const micros = end.since(start) / 1000;

    // const suc: f32 = @floatFromInt(succesful * 100);
    // const percent = (suc / @as(f32, attempt_count));
    // try stdout.print("\n{d} sucess ({d}/{d})\n", .{ percent, succesful, attempt_count });
    // try stdout.print("{d} queries to probs()\n", .{queries});
    // try stdout.print("{d} maximum row\n", .{max_row});
    try stdout.print("{d} micros\n", .{micros});
    try stdout.flush();
}
