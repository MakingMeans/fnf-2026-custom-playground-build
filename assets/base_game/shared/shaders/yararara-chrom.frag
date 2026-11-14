#pragma header
vec2 uv = openfl_TextureCoordv.xy;
vec2 fragCoord = openfl_TextureCoordv*openfl_TextureSize;
vec2 iResolution = openfl_TextureSize;
uniform float iTime;
#define iChannel0 bitmap
#define texture flixel_texture2D
#define fragColor gl_FragColor
#define mainImage main
                
void mainImage()
{
    vec2 p = fragCoord.xy/iResolution.xy;
    
	vec4 col = texture(iChannel0, p);
	
	
	if (p.x<.9999)
	{
		vec2 offset = vec2(.0025,.0);
		col.r = texture(iChannel0, p+offset.xy).r;
		col.g = texture(iChannel0, p          ).g;
		col.b = texture(iChannel0, p+offset.yx).b;
	}
	
    fragColor = col;
}