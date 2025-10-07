// Vertex shader
struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) color: vec3<f32>,
}

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> VertexOutput {
    var out: VertexOutput;

    // Triangle vertices in clip space
    let x = f32(i32(vertex_index) - 1) * 0.5;
    let y = f32(i32(vertex_index & 1u) * 2 - 1) * 0.5;

    out.position = vec4<f32>(x, y, 0.0, 1.0);

    // RGB colors for each vertex
    if (vertex_index == 0u) {
        out.color = vec3<f32>(1.0, 0.0, 0.0); // Red
    } else if (vertex_index == 1u) {
        out.color = vec3<f32>(0.0, 1.0, 0.0); // Green
    } else {
        out.color = vec3<f32>(0.0, 0.0, 1.0); // Blue
    }

    return out;
}

// Fragment shader
@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    return vec4<f32>(in.color, 1.0);
}
