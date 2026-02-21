// Fullscreen-triangle video renderer with aspect-ratio-correct letterboxing.

struct Uniforms {
    uv_scale: vec2<f32>,
    uv_offset: vec2<f32>,
};

@group(0) @binding(0) var video_tex: texture_2d<f32>;
@group(0) @binding(1) var video_sampler: sampler;
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
};

@vertex
fn vs_main(@builtin(vertex_index) idx: u32) -> VertexOutput {
    // Fullscreen triangle trick: 3 vertices cover the entire viewport.
    var pos = array<vec2<f32>, 3>(
        vec2<f32>(-1.0, -1.0),
        vec2<f32>( 3.0, -1.0),
        vec2<f32>(-1.0,  3.0),
    );
    // UV: (0,1) at bottom-left, (1,0) at top-right.
    var uv = array<vec2<f32>, 3>(
        vec2<f32>(0.0, 1.0),
        vec2<f32>(2.0, 1.0),
        vec2<f32>(0.0, -1.0),
    );

    var out: VertexOutput;
    out.position = vec4<f32>(pos[idx], 0.0, 1.0);
    out.uv = uv[idx];
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    // Map widget UV to video UV using aspect-ratio correction uniforms.
    let video_uv = (in.uv - uniforms.uv_offset) / uniforms.uv_scale;

    // Black for letterbox/pillarbox areas outside the video.
    if video_uv.x < 0.0 || video_uv.x > 1.0 || video_uv.y < 0.0 || video_uv.y > 1.0 {
        return vec4<f32>(0.0, 0.0, 0.0, 1.0);
    }

    return textureSample(video_tex, video_sampler, video_uv);
}
