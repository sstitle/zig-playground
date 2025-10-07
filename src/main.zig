const std = @import("std");
const graphics = @import("graphics.zig");

pub fn main() !void {
    var state = try graphics.init();
    defer graphics.deinit(&state);

    while (!graphics.shouldClose(&state)) {
        graphics.update(&state);
        graphics.draw(&state);
    }
}
