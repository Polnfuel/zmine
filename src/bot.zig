const std = @import("std");
const stl = @import("stl");
const Probs = @import("probs");

const A = error{
    ProbsError,
};

var suggests: stl.vec.dvec16 = undefined;

pub fn init(w: u8, h: u8, m: u16, cache: *stl.vec.vecneis) !void {
    suggests = try stl.vec.dvec16.new(10);
    try Probs.init(w, h, m, cache);
}

pub fn clicks(field: stl.vec.vec8) !stl.vec.dvec16 {
    suggests.clear();
    const prob_field = try Probs.probs_field(field);
    const code = prob_field.at(0);
    if (code == 20 or code == 21 or code == 22) {
        std.debug.print("Error {d}\n", .{code});
        return A.ProbsError;
    }

    const p27: @Vector(16, u8) = @splat(27);
    var i: u16 = 0;
    while (i < prob_field.array.len) : (i += 16) {
        const data: @Vector(16, u8) = prob_field.array[i..][0..16].*;
        const cmp = data == p27;
        var mask: u16 = @bitCast(cmp);
        while (mask > 0) {
            const idx: u16 = @ctz(mask);
            try suggests.add(i + idx);
            mask &= mask - 1;
        }
    }

    if (suggests.size == 0) {
        var min_val: u8 = std.math.maxInt(u8);
        var min_idx: u16 = 0;

        const max: @Vector(16, u8) = @splat(std.math.maxInt(i8));
        var best = max;

        i = 0;
        while (i < prob_field.array.len) : (i += 16) {
            const data: @Vector(16, u8) = prob_field.array[i..][0..16].*;
            var valid: @Vector(16, u8) = @intFromBool(data > p27);
            valid = valid * max;
            const masked: @Vector(16, u8) = (valid & data) | (~valid & max);
            best = @min(best, masked);
        }
        min_val = @reduce(.Min, best);

        if (min_val != std.math.maxInt(i8)) {
            for (prob_field.array, 0..prob_field.array.len) |val, ind| {
                if (val == min_val) {
                    min_idx = @intCast(ind);
                    break;
                }
            }
            try suggests.add(min_idx);
        }
    }

    return suggests;
}

pub fn deinit() void {
    Probs.deinit();
    suggests.free();
}
