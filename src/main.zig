const std = @import("std");
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;

const window_title = "Triangle with External WGSL Shader";

const DemoState = struct {
    gctx: *zgpu.GraphicsContext,
    pipeline: zgpu.RenderPipelineHandle,
};

fn init(allocator: std.mem.Allocator, window: *zglfw.Window) !DemoState {
    const gctx = try zgpu.GraphicsContext.create(
        allocator,
        .{
            .window = window,
            .fn_getTime = @ptrCast(&zglfw.getTime),
            .fn_getFramebufferSize = @ptrCast(&zglfw.Window.getFramebufferSize),
            .fn_getWin32Window = @ptrCast(&zglfw.getWin32Window),
            .fn_getX11Display = @ptrCast(&zglfw.getX11Display),
            .fn_getX11Window = @ptrCast(&zglfw.getX11Window),
            .fn_getWaylandDisplay = @ptrCast(&zglfw.getWaylandDisplay),
            .fn_getWaylandSurface = @ptrCast(&zglfw.getWaylandWindow),
            .fn_getCocoaWindow = @ptrCast(&zglfw.getCocoaWindow),
        },
        .{},
    );
    errdefer gctx.destroy(allocator);

    // Load shader from external file
    const shader_source = try std.fs.cwd().readFileAllocOptions(
        allocator,
        "src/shaders/triangle.wgsl",
        16 * 1024,
        null,
        1,
        0,
    );
    defer allocator.free(shader_source);

    std.debug.print("Loaded external WGSL shader ({} bytes)\n", .{shader_source.len});

    // Create an empty pipeline layout (no bind groups needed for simple triangle)
    const pipeline_layout = gctx.createPipelineLayout(&.{});
    defer gctx.releaseResource(pipeline_layout);

    const pipeline = pipeline: {
        const shader_module = zgpu.createWgslShaderModule(gctx.device, shader_source, "triangle");
        defer shader_module.release();

        const color_targets = [_]wgpu.ColorTargetState{.{
            .format = zgpu.GraphicsContext.swapchain_format,
        }};

        const pipeline_descriptor = wgpu.RenderPipelineDescriptor{
            .vertex = .{
                .module = shader_module,
                .entry_point = "vs_main",
            },
            .primitive = .{
                .topology = .triangle_list,
                .front_face = .ccw,
                .cull_mode = .none,
            },
            .fragment = &.{
                .module = shader_module,
                .entry_point = "fs_main",
                .target_count = color_targets.len,
                .targets = &color_targets,
            },
        };

        break :pipeline gctx.createRenderPipeline(pipeline_layout, pipeline_descriptor);
    };

    return DemoState{
        .gctx = gctx,
        .pipeline = pipeline,
    };
}

fn deinit(demo: *DemoState, allocator: std.mem.Allocator) void {
    demo.gctx.destroy(allocator);
}

fn update(_: *DemoState) void {
    zglfw.pollEvents();
}

fn draw(demo: *DemoState) void {
    const gctx = demo.gctx;
    const back_buffer_view = gctx.swapchain.getCurrentTextureView();
    defer back_buffer_view.release();

    const commands = commands: {
        const encoder = gctx.device.createCommandEncoder(null);
        defer encoder.release();

        // Render triangle pass
        {
            const color_attachments = [_]wgpu.RenderPassColorAttachment{.{
                .view = back_buffer_view,
                .load_op = .clear,
                .store_op = .store,
                .clear_value = .{ .r = 0.1, .g = 0.1, .b = 0.1, .a = 1.0 },
            }};

            const render_pass_info = wgpu.RenderPassDescriptor{
                .color_attachment_count = color_attachments.len,
                .color_attachments = &color_attachments,
            };

            const pass = encoder.beginRenderPass(render_pass_info);
            defer pass.release();

            pass.setPipeline(gctx.lookupResource(demo.pipeline).?);
            pass.draw(3, 1, 0, 0);

            pass.end();
        }

        break :commands encoder.finish(null);
    };
    defer commands.release();

    gctx.submit(&.{commands});
    _ = gctx.present();
}

pub fn main() !void {
    try zglfw.init();
    defer zglfw.terminate();

    zglfw.windowHint(.client_api, .no_api);
    zglfw.windowHint(.cocoa_retina_framebuffer, true);

    const window = try zglfw.Window.create(800, 600, window_title, null);
    defer window.destroy();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var demo = try init(allocator, window);
    defer deinit(&demo, allocator);

    while (!window.shouldClose()) {
        update(&demo);
        draw(&demo);
    }
}
