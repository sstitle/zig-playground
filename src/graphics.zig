const std = @import("std");
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const zgui = @import("zgui");

pub const GraphicsState = struct {
    gctx: *zgpu.GraphicsContext,
    pipeline: zgpu.RenderPipelineHandle,
    allocator: std.mem.Allocator,
};

fn loadShaderFile(allocator: std.mem.Allocator, path: []const u8) ![:0]const u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = (try file.stat()).size;
    const buffer = try allocator.allocSentinel(u8, file_size, 0);
    const bytes_read = try file.readAll(buffer);

    return buffer[0..bytes_read :0];
}

pub fn init(allocator: std.mem.Allocator) !GraphicsState {
    // Initialize GLFW
    try zglfw.init();

    // Set window hints
    zglfw.windowHintTyped(.client_api, .no_api);
    zglfw.windowHintTyped(.cocoa_retina_framebuffer, true);

    // Create window
    const window = try zglfw.Window.create(800, 600, "Zig + WGPU Graphics", null);

    // Create graphics context
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
            .fn_getWaylandSurface = @ptrCast(&zglfw.getWaylandSurface),
            .fn_getCocoaWindow = @ptrCast(&zglfw.getCocoaWindow),
        },
        .{},
    );

    std.debug.print("Created graphics context\n", .{});

    // Load shader from external file
    const shader_source = try loadShaderFile(allocator, "src/shaders/triangle.wgsl");
    defer allocator.free(shader_source);
    std.debug.print("Loaded shader ({} bytes)\n", .{shader_source.len});

    // Create shader module from external WGSL file
    const wgsl_module = zgpu.createWgslShaderModule(gctx.device, shader_source, "triangle");
    defer wgsl_module.release();

    // Create render pipeline
    const pipeline_layout = gctx.device.createPipelineLayout(&.{
        .bind_group_layout_count = 0,
        .bind_group_layouts = null,
    });
    defer pipeline_layout.release();

    const color_targets = [_]zgpu.wgpu.ColorTargetState{.{
        .format = zgpu.GraphicsContext.swapchain_format,
        .blend = &.{
            .color = .{
                .operation = .add,
                .src_factor = .one,
                .dst_factor = .zero,
            },
            .alpha = .{
                .operation = .add,
                .src_factor = .one,
                .dst_factor = .zero,
            },
        },
        .write_mask = zgpu.wgpu.ColorWriteMaskFlags.all,
    }};

    const pipeline_descriptor = zgpu.wgpu.RenderPipelineDescriptor{
        .vertex = .{
            .module = wgsl_module,
            .entry_point = "vs_main",
        },
        .primitive = .{
            .topology = .triangle_list,
            .front_face = .ccw,
            .cull_mode = .none,
        },
        .fragment = &.{
            .module = wgsl_module,
            .entry_point = "fs_main",
            .target_count = color_targets.len,
            .targets = &color_targets,
        },
    };

    const pipeline = gctx.createRenderPipeline(pipeline_layout, pipeline_descriptor);

    std.debug.print("Graphics initialization complete\n", .{});

    return GraphicsState{
        .gctx = gctx,
        .pipeline = pipeline,
        .allocator = allocator,
    };
}

pub fn deinit(state: *GraphicsState) void {
    state.gctx.destroy(state.allocator);
    zglfw.terminate();
}

pub fn shouldClose(state: *GraphicsState) bool {
    return state.gctx.window.shouldClose();
}

pub fn update(state: *GraphicsState) void {
    zglfw.pollEvents();
    zgui.backend.newFrame(
        state.gctx.swapchain_descriptor.width,
        state.gctx.swapchain_descriptor.height,
    );
}

pub fn draw(state: *GraphicsState) void {
    const gctx = state.gctx;

    const back_buffer_view = gctx.swapchain.getCurrentTextureView();
    defer back_buffer_view.release();

    const commands = commands: {
        const encoder = gctx.device.createCommandEncoder(null);
        defer encoder.release();

        // Render pass
        {
            const color_attachments = [_]zgpu.wgpu.RenderPassColorAttachment{.{
                .view = back_buffer_view,
                .load_op = .clear,
                .store_op = .store,
                .clear_value = .{ .r = 0.1, .g = 0.1, .b = 0.1, .a = 1.0 },
            }};

            const render_pass_info = zgpu.wgpu.RenderPassDescriptor{
                .color_attachment_count = color_attachments.len,
                .color_attachments = &color_attachments,
            };

            const pass = encoder.beginRenderPass(render_pass_info);
            defer pass.release();

            pass.setPipeline(gctx.lookupResource(state.pipeline).?);
            pass.draw(3, 1, 0, 0);

            pass.end();
        }

        // GUI pass
        {
            const color_attachments = [_]zgpu.wgpu.RenderPassColorAttachment{.{
                .view = back_buffer_view,
                .load_op = .load,
                .store_op = .store,
            }};

            const render_pass_info = zgpu.wgpu.RenderPassDescriptor{
                .color_attachment_count = color_attachments.len,
                .color_attachments = &color_attachments,
            };

            const pass = encoder.beginRenderPass(render_pass_info);
            defer pass.release();

            zgui.backend.draw(pass);

            pass.end();
        }

        break :commands encoder.finish(null);
    };
    defer commands.release();

    gctx.submit(&.{commands});
    _ = gctx.present();
}
