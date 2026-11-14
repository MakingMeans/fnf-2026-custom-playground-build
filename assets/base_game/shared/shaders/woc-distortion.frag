#pragma header

uniform float time;
uniform float strength;

float rand(vec2 n)
{
    return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

float noise(vec2 n)
{
    const vec2 d = vec2(0.0, 1.0);

    vec2 b = floor(n);
    vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(n));

    return mix(
        mix(rand(b), rand(b + d.yx), f.x),
        mix(rand(b + d.xy), rand(b + d.yy), f.x),
        f.y
    );
}

void main()
{
    vec2 uv = openfl_TextureCoordv;

    vec2 p = uv;
    p.y += time * 1.0;

    float noiseX = noise(p * 30.0);
    float noiseY = noise((p + vec2(10.0, 10.0)) * 30.0);

    vec2 dst_offset = vec2(noiseX, noiseY);
    dst_offset -= vec2(0.3);
    dst_offset *= strength * 0.03;

    gl_FragColor = flixel_texture2D(bitmap, uv + dst_offset);
}