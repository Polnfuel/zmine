const std = @import("std");
const stl = @import("stl");

var indices: stl.vec.vec16 = undefined;
var rng_state: u32 = undefined;
var neis_cache: stl.vec.vecneis = undefined;

var game_field: stl.vec.vec8 = undefined;
pub var visible_field: stl.vec.vec8 = undefined;
var field_size: u16 = undefined;
var field_width: u8 = undefined;
var field_height: u8 = undefined;
var total_mines: u16 = undefined;
pub var real_size: u16 = undefined;
pub var playing: bool = undefined;
pub var won: bool = undefined;

pub fn init(w: u8, h: u8, m: u8) !void {
    field_size = @as(u16, w) * h;
    field_height = h;
    field_width = w;
    total_mines = m;
    real_size = @as(u16, w) * h;
    game_field = undefined;
    visible_field = try stl.vec.vec8.new(@as(usize, w) * h);
    playing = false;
    won = false;

    try set_neis_cache();
    indices = try stl.vec.vec16.new(real_size);
    set_indices();
    rng_state = @intCast(std.time.timestamp());
}

pub fn start_game(first_click: u16, field_start: []u8) !void {
    gen_field(field_start);
    playing = true;
    won = false;
    try open_cell(first_click);
}

fn set_indices() void {
    var i: u16 = 0;
    while (i < real_size) : (i += 8) {
        const a = [8]u16{ i + 7, i + 6, i + 5, i + 4, i + 3, i + 2, i + 1, i };
        @memcpy(indices.array[i .. i + 8], a[0..8]);
    }
}

fn set_neis_cache() !void {
    neis_cache = try stl.vec.vecneis.new(field_size);
    const fw = field_width;
    for (0..field_size) |cc| {
        const c: u16 = @intCast(cc);
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
        } else if (row == field_height - 1) {
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

fn count_mines(cell: u16) u8 {
    const neighbors = get_neis(cell);
    const f = game_field.array;
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

fn gen_field(field_start: []u8) void {
    game_field.array = field_start;
    visible_field.fill(9);

    @memset(visible_field.array[field_size..real_size], 26);
    set_indices();
}

fn check_end() bool {
    var count: u16 = 0;
    const nine: @Vector(16, u8) = @splat(9);
    var i: usize = 0;
    while (i < real_size) : (i += 16) {
        const data: @Vector(16, u8) = visible_field.array[i..][0..16].*;
        const cmp = data < nine;
        const mask: u16 = @bitCast(cmp);
        count += @popCount(mask);
    }
    return (count == field_size - total_mines);
}

fn open_zero(cell: u16) !void {
    var neis_checked: u16 = 0;
    var zero_cells = try stl.vec.dvec16.new(8);
    defer zero_cells.free();
    var edge_cells = try stl.vec.dvec16.new(8);
    defer edge_cells.free();
    try zero_cells.add(cell);
    try edge_cells.add(cell);

    while (true) {
        for (neis_checked..zero_cells.size) |i| {
            const neighbors = get_neis(zero_cells.at(i));
            for (neighbors.cells[0..neighbors.size]) |nei| {
                if (game_field.at(nei) == 0 and !zero_cells.has(nei)) {
                    try zero_cells.add(nei);
                }
                if (game_field.at(nei) < 9 and !edge_cells.has(nei)) {
                    try edge_cells.add(nei);
                }
            }
            neis_checked += 1;
        }

        if (neis_checked == zero_cells.size) {
            break;
        }
    }

    for (edge_cells.array[0..edge_cells.size]) |to| {
        visible_field.set(to, game_field.at(to));
    }
}

pub fn open_cell(cell: u16) !void {
    if (playing) {
        if (game_field.at(cell) == 12) {
            playing = false;
            visible_field.set(cell, 12);
            return;
        } else if (game_field.at(cell) == 0 and visible_field.at(cell) == 9) {
            try open_zero(cell);
        }
        visible_field.set(cell, game_field.at(cell));
        if (check_end()) {
            playing = false;
            won = true;
        }
    }
}

pub fn deinit() void {
    indices.free();
    neis_cache.free();
    visible_field.free();
}
