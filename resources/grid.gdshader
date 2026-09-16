shader_type spatial;
render_mode diffuse_burley;

uniform vec4 base_color : source_color = vec4(0.65, 0.72, 0.70, 1.0);
uniform vec4 line_color : source_color = vec4(0.48, 0.59, 0.58, 1.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = world_position.xz / 2.0;
	vec2 nearest = abs(fract(cell - 0.5) - 0.5);
	vec2 width = max(fwidth(cell), vec2(0.001));
	float grid = 1.0 - min(min(nearest.x / width.x, nearest.y / width.y), 1.0);
	ALBEDO = mix(base_color.rgb, line_color.rgb, grid * 0.55);
	ROUGHNESS = 0.92;
}
