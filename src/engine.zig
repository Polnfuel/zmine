const std = @import("std");
const stl = @import("stl");

var indices: stl.vec.vec16 = undefined;
var rng_state: u32 = undefined;
var neis_cache: stl.vec.vecneis = undefined;

pub const Engine = struct {
    game_field: stl.vec.vec8,
    visible_field: stl.vec.vec8,
    field_size: u16,
    field_width: u8,
    field_height: u8,
    total_mines: u16,
    real_size: u16,
    playing: bool,
    won: bool,

    pub fn init(w: u8, h: u8, m: u8) !Engine {
        var eng = Engine{
            .field_size = @as(u16, w) * h,
            .field_height = h,
            .field_width = w,
            .total_mines = m,
            .real_size = @as(u16, w) * h,
            .game_field = try stl.vec.vec8.new(@as(usize, w) * h),
            .visible_field = try stl.vec.vec8.new(@as(usize, w) * h),
            .playing = false,
            .won = false,
        };
        try eng.set_neis_cache();
        indices = try stl.vec.vec16.new(eng.real_size);
        eng.set_indices();
        rng_state = @intCast(std.time.timestamp());

        return eng;
    }

    pub fn start_game(self: *Engine, first_click: u16) !void {
        self.gen_field(first_click);
        self.playing = true;
        self.won = false;
        try self.open_cell(first_click);
    }

    fn set_indices(self: *Engine) void {
        var i: u16 = 0;
        while (i < self.real_size) : (i += 8) {
            const a = [8]u16{ i + 7, i + 6, i + 5, i + 4, i + 3, i + 2, i + 1, i };
            @memcpy(indices.array[i .. i + 8], a[0..8]);
        }
    }

    fn set_neis_cache(self: *Engine) !void {
        neis_cache = try stl.vec.vecneis.new(self.field_size);
        const fw = self.field_width;
        var c: u16 = 0;
        while (c < self.field_size) : (c += 1) {
            const row = c / fw;
            const col = c % fw;

            if (row == 0) {
                if (col == 0) {
                    neis_cache.add3(1, fw, fw + 1);
                } else if (col == fw - 1) {
                    neis_cache.add3(c - 1, c + fw - 1, c + fw);
                } else {
                    neis_cache.add5(c - 1, c + 1, c + fw - 1, c + fw, c + 1 + fw);
                }
            } else if (row == self.field_height - 1) {
                if (col == 0) {
                    neis_cache.add3(c - fw, c + 1 - fw, c + 1);
                } else if (col == fw - 1) {
                    neis_cache.add3(c - 1, c - 1 - fw, c - fw);
                } else {
                    neis_cache.add5(c - 1, c + 1, c + 1 - fw, c - 1 - fw, c - fw);
                }
            } else {
                if (col == 0) {
                    neis_cache.add5(c - fw, c + 1 - fw, c + 1, c + fw, c + fw + 1);
                } else if (col == fw - 1) {
                    neis_cache.add5(c - 1 - fw, c - fw, c - 1, c - 1 + fw, c + fw);
                } else {
                    neis_cache.add8(c - 1 - fw, c - fw, c + 1 - fw, c - 1, c + 1, c - 1 + fw, c + fw, c + fw + 1);
                }
            }
        }
    }

    pub fn get_cache_ptr() *stl.vec.vecneis {
        return &neis_cache;
    }

    fn get_neis(c: u16) stl.vec.neis {
        return neis_cache.at(c);
    }

    fn count_mines(self: *Engine, cell: u16) u8 {
        const neighbors = get_neis(cell);
        const f = self.game_field.array;
        const n = neighbors.cells;
        switch (neighbors.size) {
            8 => {
                @branchHint(.likely);
                return @as(u8, @intFromBool(f[n[0]] == 12)) + @as(u8, @intFromBool(f[n[1]] == 12)) +
                    @as(u8, @intFromBool(f[n[2]] == 12)) + @as(u8, @intFromBool(f[n[3]] == 12)) +
                    @as(u8, @intFromBool(f[n[4]] == 12)) + @as(u8, @intFromBool(f[n[5]] == 12)) +
                    @as(u8, @intFromBool(f[n[6]] == 12)) + @as(u8, @intFromBool(f[n[7]] == 12));
            },
            5 => {
                return @as(u8, @intFromBool(f[n[0]] == 12)) + @as(u8, @intFromBool(f[n[1]] == 12)) +
                    @as(u8, @intFromBool(f[n[2]] == 12)) + @as(u8, @intFromBool(f[n[3]] == 12)) +
                    @as(u8, @intFromBool(f[n[4]] == 12));
            },
            3 => {
                return @as(u8, @intFromBool(f[n[0]] == 12)) + @as(u8, @intFromBool(f[n[1]] == 12)) +
                    @as(u8, @intFromBool(f[n[2]] == 12));
            },
            else => {
                unreachable;
            },
        }
    }

    fn xorshift_rnd() u32 {
        var x = rng_state;
        x ^= x << 13;
        x ^= x >> 17;
        x ^= x << 5;
        rng_state = x;
        return x;
    }

    fn gen_field(self: *Engine, first_click: u16) void {
        self.game_field.fill(0);
        self.visible_field.fill(9);

        var i: u16 = 0;
        while (i < self.total_mines) : (i += 1) {
            var j: u16 = 0;
            while (true) {
                const a: u16 = @truncate(xorshift_rnd() % (self.field_size - i));
                j = i + a;

                if (indices.at(j) != first_click) {
                    break;
                }
            }
            const tmp = indices.at(i);
            indices.set(i, indices.at(j));
            indices.set(j, tmp);
            self.game_field.set(indices.at(i), 12);
        }
        var cell: u16 = 0;
        while (cell < self.field_size) : (cell += 1) {
            if (self.game_field.at(cell) != 12) {
                self.game_field.set(cell, self.count_mines(cell));
            }
        }

        @memset(self.visible_field.array[self.field_size..self.real_size], 26);
        self.set_indices();
    }

    fn check_end(self: *Engine) bool {
        var count: u16 = 0;
        var i: usize = 0;
        const nine: @Vector(16, u8) = @splat(9);
        while (i < self.real_size) : (i += 16) {
            const data: @Vector(16, u8) = self.visible_field.array[i..][0..16].*;
            const cmp = data < nine;
            const mask: u16 = @bitCast(cmp);
            count += @popCount(mask);
        }
        return (count == self.field_size - self.total_mines);
    }

    fn open_zero(self: *Engine, cell: u16) !void {
        var neis_checked: u16 = 0;
        var zero_cells = try stl.vec.dvec16.new(8);
        defer zero_cells.free();
        var edge_cells = try stl.vec.dvec16.new(8);
        defer edge_cells.free();
        try zero_cells.add(cell);
        try edge_cells.add(cell);

        while (true) {
            var i = neis_checked;
            while (i < zero_cells.size) : (i += 1) {
                const neighbors = get_neis(zero_cells.at(i));
                var j: usize = 0;
                while (j < neighbors.size) : (j += 1) {
                    const nei = neighbors.at(j);
                    if (self.game_field.at(nei) == 0 and !zero_cells.has(nei)) {
                        try zero_cells.add(nei);
                    }
                    if (self.game_field.at(nei) < 9 and !edge_cells.has(nei)) {
                        try edge_cells.add(nei);
                    }
                }
                neis_checked += 1;
            }

            if (neis_checked == zero_cells.size) {
                break;
            }
        }

        var i: usize = 0;
        while (i < edge_cells.size) : (i += 1) {
            const to = edge_cells.at(i);
            self.visible_field.set(to, self.game_field.at(to));
        }
    }

    pub fn open_cell(self: *Engine, cell: u16) !void {
        if (self.playing) {
            if (self.game_field.at(cell) == 12) {
                self.playing = false;
                self.visible_field.set(cell, 12);
                return;
            } else if (self.game_field.at(cell) == 0 and self.visible_field.at(cell) == 9) {
                try self.open_zero(cell);
            }
            self.visible_field.set(cell, self.game_field.at(cell));
            if (self.check_end()) {
                self.playing = false;
                self.won = true;
            }
        }
    }

    pub fn deinit(self: *Engine) void {
        indices.free();
        neis_cache.free();
        self.game_field.free();
        self.visible_field.free();
    }

    pub fn print_field(self: *Engine) !void {
        var stdout_buffer: [2000]u8 = undefined;
        var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
        const stdout = &stdout_writer.interface;
        var i: usize = 0;
        while (i < self.field_height) : (i += 1) {
            var j: usize = 0;
            while (j < self.field_width) : (j += 1) {
                const val = self.visible_field.at(i * self.field_width + j);
                switch (val) {
                    0 => {
                        _ = try stdout.write("  ");
                    },
                    1 => {
                        _ = try stdout.write("\x1b[34m1 \x1b[0m");
                    },
                    2 => {
                        _ = try stdout.write("\x1b[32m2 \x1b[0m");
                    },
                    3 => {
                        _ = try stdout.write("\x1b[31m3 \x1b[0m");
                    },
                    4 => {
                        _ = try stdout.write("\x1b[96m4 \x1b[0m");
                    },
                    5 => {
                        _ = try stdout.write("\x1b[35m5 \x1b[0m");
                    },
                    6 => {
                        _ = try stdout.write("\x1b[36m6 \x1b[0m");
                    },
                    7 => {
                        _ = try stdout.write("7 ");
                    },
                    8 => {
                        _ = try stdout.write("8 ");
                    },
                    9 => {
                        _ = try stdout.write("\x1b[0;100m  \x1b[0m");
                    },
                    11 => {
                        _ = try stdout.write("\x1b[0;101m  \x1b[0m");
                    },
                    12 => {
                        _ = try stdout.write("\x1b[0;101m  \x1b[0m");
                    },
                    27 => {
                        _ = try stdout.write("\x1b[0;42m  \x1b[0m");
                    },
                    28...36 => {
                        try stdout.print("\x1b[30;100m{d} \x1b[0m", .{val - 27});
                    },
                    37...126 => {
                        try stdout.print("\x1b[30;100m{d}\x1b[0m", .{val - 27});
                    },
                    127 => {
                        _ = try stdout.write("\x1b[0;101m  \x1b[0m");
                    },
                    else => {
                        _ = try stdout.write("\x1b[30;100m  \x1b[0m");
                    },
                }
            }
            _ = try stdout.write("\n");
            try stdout.flush();
        }
        try stdout.flush();
    }
};
