const std = @import("std");
const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub const GraphicsState = struct {
    window: *c.GLFWwindow,
};

pub fn init() !GraphicsState {
    if (c.glfwInit() == c.GLFW_FALSE) {
        return error.GLFWInitFailed;
    }

    const window = c.glfwCreateWindow(800, 600, "Zig Graphics", null, null) orelse {
        c.glfwTerminate();
        return error.WindowCreationFailed;
    };

    c.glfwMakeContextCurrent(window);

    return GraphicsState{
        .window = window,
    };
}

pub fn deinit(state: *GraphicsState) void {
    c.glfwDestroyWindow(state.window);
    c.glfwTerminate();
}

pub fn shouldClose(state: *GraphicsState) bool {
    return c.glfwWindowShouldClose(state.window) != 0;
}

pub fn update(_: *GraphicsState) void {
    c.glfwPollEvents();
}

pub fn draw(state: *GraphicsState) void {
    // Simple rainbow background that changes over time
    const time = @as(f32, @floatCast(c.glfwGetTime()));

    const r = (@sin(time) + 1.0) * 0.5;
    const g = (@sin(time + 2.094) + 1.0) * 0.5; // 2π/3 offset
    const b = (@sin(time + 4.189) + 1.0) * 0.5; // 4π/3 offset

    c.glClearColor(r, g, b, 1.0);
    c.glClear(c.GL_COLOR_BUFFER_BIT);

    c.glfwSwapBuffers(state.window);
}
