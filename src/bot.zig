const std = @import("std");
const stl = @import("stl");
const probs = @import("probs");

const A = error{
    ProbsError,
};

pub const Bot = struct {
    suggests: stl.vec.dvec16,
    prob: probs.Probs,

    pub fn init(w: u8, h: u8, m: u8, cache: *stl.vec.vecneis) !Bot {
        const bot = Bot{
            .suggests = try stl.vec.dvec16.new(10),
            .prob = try probs.Probs.init(w, h, m, cache),
        };
        return bot;
    }

    pub fn clicks(self: *Bot, field: stl.vec.vec8) !stl.vec.dvec16 {
        self.suggests.clear();
        const prob_field = try self.prob.probs_field(field);
        const code = prob_field.at(0);
        if (code == 20 or code == 21 or code == 22) {
            std.debug.print("Error {d}\n", .{code});
            // return self.suggests;
            return A.ProbsError;
        }

        var min_val: u8 = std.math.maxInt(u8);
        var min_idx: u16 = 0;

        var i: u16 = 0;
        while (i < self.prob.field_size) : (i += 1) {
            if (prob_field.at(i) == 27) {
                try self.suggests.add(i);
            } else if (prob_field.at(i) < min_val and prob_field.at(i) > 27) {
                min_val = prob_field.at(i);
                min_idx = i;
            }
        }

        if (self.suggests.size == 0) {
            try self.suggests.add(min_idx);
        }

        return self.suggests;
    }

    pub fn deinit(self: *Bot) void {
        self.prob.deinit();
        self.suggests.free();
    }
};
