shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float scanline_count : hint_range(0.0, 1080.0) = 540.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.06;
uniform float curvature : hint_range(0.0, 0.1) = 0.006;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.12;

vec2 curve_uv(vec2 uv) {
	uv = (uv - 0.5) * 2.0;
	uv *= 1.0 + pow(length(uv) * curvature, 2.0);
	return (uv / 2.0) + 0.5;
}

void fragment() {
	vec2 uv = curve_uv(SCREEN_UV);
	
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec4 text = texture(screen_texture, uv);
		
		// Subtle chromatic aberration
		float r = texture(screen_texture, uv + vec2(0.0003, 0.0)).r;
		float g = text.g;
		float b = texture(screen_texture, uv - vec2(0.0003, 0.0)).b;
		vec3 col = vec3(r, g, b);
		
		// Scanlines
		float scanline = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
		col -= scanline * scanline_intensity;
		
		// Vignette
		float vignette = length(uv - 0.5);
		col *= 1.0 - (vignette * vignette_intensity);
		
		COLOR = vec4(col, 1.0);
	}
}
