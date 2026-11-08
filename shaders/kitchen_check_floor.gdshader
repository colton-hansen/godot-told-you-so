shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D tex_white : source_color, filter_nearest, repeat_enable;
uniform sampler2D tex_black : source_color, filter_nearest, repeat_enable;
uniform float tile_m : hint_range(0.15, 0.8) = 0.36;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz / max(tile_m, 0.05);
	vec2 uv = fract(p);
	ivec2 cell = ivec2(floor(p));
	bool is_black = ((cell.x + cell.y) & 1) == 1;
	vec3 col = is_black ? texture(tex_black, uv).rgb : texture(tex_white, uv).rgb;
	ALBEDO = col;
	ROUGHNESS = is_black ? 0.84 : 0.72;
	SPECULAR = 0.18;
}
