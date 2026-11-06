shader_type spatial;
// Cel shading straight onto the interiors' own colours: four shades of one material, picked by how
// squarely a face meets the light (from the upper left, in front), as the Cainos art is lit. Boards
// can show their planks: a seam every "planks.w" metres along the axis in planks.xyz, a shade darker,
// and each plank a touch lighter or darker than the next.
render_mode unshaded, cull_back, depth_draw_opaque;
uniform vec3 c0 : source_color;   // in shadow (faces turned right)
uniform vec3 c1 : source_color;   // side light
uniform vec3 c2 : source_color;   // lit (fronts, left sides)
uniform vec3 c3 : source_color;   // full light (tops)
uniform vec4 planks = vec4(0.0);
uniform vec3 light_dir = vec3(-0.55, 0.75, 0.55);
varying vec3 wn;
varying vec3 wp;
void vertex() {
	wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float d = dot(normalize(wn), normalize(light_dir));
	int band = d > 0.6 ? 3 : (d > 0.3 ? 2 : (d > -0.2 ? 1 : 0));
	vec3 ramp[4] = {c0, c1, c2, c3};
	vec3 col = ramp[band];
	if (planks.w > 0.0) {
		float t = dot(wp, planks.xyz) / planks.w;
		float f = fract(t);
		float edge = fwidth(t) * 1.2;
		if (f < edge && band > 0) {
			col = mix(col, ramp[band - 1], 0.85);
		} else {
			float h = fract(sin(floor(t) * 91.7) * 4375.85);
			col *= 0.95 + 0.1 * h;
		}
	}
	ALBEDO = col;
}
