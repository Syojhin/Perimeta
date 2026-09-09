shader_type canvas_item;

uniform float prestige_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 prestige_glow_color : source_color = vec4(1.0, 0.84, 0.0, 1.0);

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (prestige_intensity > 0.0) {
		float pulse = (sin(TIME * (3.0 + prestige_intensity * 8.0)) + 1.0) * 0.5;
		vec3 glow = mix(col.rgb, prestige_glow_color.rgb, prestige_intensity * 0.45 * (0.8 + 0.4 * pulse));
		col.rgb = glow + (prestige_glow_color.rgb * prestige_intensity * 0.5 * pulse);
	}
	COLOR = col;
}
