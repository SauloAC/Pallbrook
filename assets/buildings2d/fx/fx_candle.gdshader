shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// A candle's flame, drawn in a few big pixels: a teardrop, white-yellow at the heart and orange at the
// edge, that leans and flickers a little. Each flame keeps its own rhythm (from where it stands).
uniform vec2 grid = vec2(4.0, 7.0);       // its pixels across and up
uniform vec3 hot : source_color = vec3(1.0, 0.95, 0.7);
uniform vec3 cool : source_color = vec3(1.0, 0.5, 0.12);

void fragment() {
	vec2 cell = (floor(UV * grid) + 0.5) / grid;
	float seed = NODE_POSITION_WORLD.x * 3.1 + NODE_POSITION_WORLD.z * 1.7;
	float t = floor(TIME * 8.0) / 8.0;
	float lean = sin(t * 3.0 + seed) * 0.08;
	float stretch = 1.0 + sin(t * 5.3 + seed * 2.0) * 0.12;
	// UV y runs down; the flame's foot at the bottom
	vec2 p = vec2(cell.x - 0.5 - lean * (1.0 - cell.y), (1.0 - cell.y) * 1.0 / stretch);
	float w = 0.42 * (1.0 - smoothstep(0.15, 0.95, p.y)) * smoothstep(-0.05, 0.25, p.y);
	float inside = step(abs(p.x), w);
	if (inside < 0.5) {
		discard;
	}
	float core = step(abs(p.x), w * 0.45) * step(p.y, 0.55);
	ALBEDO = mix(cool, hot, core) * 1.4;
}
