shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;
uniform sampler2D tex : source_color, filter_nearest;
uniform vec3 light_dir = vec3(-0.55, 0.75, 0.55);
varying vec3 wn;
void vertex() { wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz; }
void fragment() {
	vec3 n = normalize(wn);
	float d = dot(n, normalize(light_dir));
	float b = d > 0.55 ? 1.0 : (d > 0.12 ? 0.82 : 0.64);
	ALBEDO = texture(tex, UV).rgb * b;
}
