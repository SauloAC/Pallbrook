shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Hearth fire (Cainos Village FX): a grey flame flip-book, coloured from deep orange to pale yellow.
uniform sampler2D frames : filter_nearest;
uniform int columns = 6;
uniform int rows = 6;
uniform int count = 35;
uniform float fps = 12.0;
uniform vec3 hot : source_color = vec3(1.0, 0.86, 0.45);
uniform vec3 cool : source_color = vec3(0.95, 0.38, 0.10);

void fragment() {
	int f = int(mod(TIME * fps, float(count)));
	vec2 cell = vec2(float(f % columns), float(f / columns));
	vec2 uv = (cell + UV) / vec2(float(columns), float(rows));
	vec4 c = texture(frames, uv);
	float v = c.r * c.a;
	if (v < 0.15) {
		discard;
	}
	ALBEDO = mix(cool, hot, smoothstep(0.4, 1.0, v)) * v;
}
