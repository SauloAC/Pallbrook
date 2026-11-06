shader_type spatial;
// Cel shading in the way pixel art is painted: four shades of one material, picked by how squarely a
// face meets the light (from the upper left, in front), and two more made from them, a lit edge and
// a deep shade (warmer up, toward purple down, as the shades of the references shift). Every board is
// bevelled: its top edge (the front lip of a top) a pixel lighter, its foot a pixel darker. Boards can
// show their planks: a dark seam every "planks.w" metres along planks.xyz, the lit edge beside it, and
// each plank a touch lighter or darker than the next; wood has a grain, short dark streaks along it.
render_mode unshaded, cull_back, depth_draw_opaque;
uniform vec3 c0 : source_color;   // in shadow (faces turned right)
uniform vec3 c1 : source_color;   // side light
uniform vec3 c2 : source_color;   // lit (fronts, left sides)
uniform vec3 c3 : source_color;   // full light (tops)
uniform vec4 planks = vec4(0.0);
uniform float grain = 0.0;        // 1: wood
uniform vec3 box_half = vec3(0.0);   // a box's half size (its bevels), or 0
uniform vec2 cyl = vec2(0.0);        // a cylinder's top radius and half height (its rim), or 0
uniform vec3 light_dir = vec3(-0.55, 0.75, 0.55);
uniform bool flat_colour = false;     // the id and layer passes: c0 as it is
varying vec3 wn;
varying vec3 wp;
varying vec3 lp;
varying vec3 ln;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	vec3 col = c0;
	if (!flat_colour) {
		float d = dot(normalize(wn), normalize(light_dir));
		int i = d > 0.6 ? 4 : (d > 0.3 ? 3 : (d > -0.2 ? 2 : 1));
		vec3 lo = mix(c0 * 0.68, vec3(0.13, 0.03, 0.1), 0.25);
		vec3 hi = min(c3 * 1.12 + vec3(0.05, 0.03, 0.0), vec3(1.0));
		vec3 ramp[6] = {lo, c0, c1, c2, c3, hi};
		vec3 n = normalize(ln);
		vec3 px = fwidth(lp);
		int bevel = 0;
		if (box_half.x > 0.0) {
			if (n.z > 0.5) {                                  // a front: its top edge lit, its foot dark
				if (box_half.y - lp.y < px.y) bevel = 1;
				else if (lp.y + box_half.y < px.y) bevel = -1;
			} else if (n.y > 0.5) {                           // a top: its front lip lit
				if (box_half.z - lp.z < px.z) bevel = 1;
				else if (lp.z + box_half.z < px.z) bevel = -1;
			} else if (n.x < -0.5 || n.x > 0.5) {             // a side (a turned piece): its top edge lit
				if (box_half.y - lp.y < px.y) bevel = 1;
			}
		} else if (cyl.x > 0.0) {
			if (n.y > 0.5) {                                  // the top: its rim lit toward the camera
				if (length(lp.xz) > cyl.x - max(px.x, px.z) * 1.2 && lp.z > 0.0) bevel = 1;
			} else if (n.y > -0.5) {                          // the side: its top edge lit, its foot dark
				if (cyl.y - lp.y < px.y) bevel = 1;
				else if (lp.y + cyl.y < px.y) bevel = -1;
			}
		}
		bool seam = false;
		float plank = 0.0;
		if (planks.w > 0.0) {
			float t = dot(wp, planks.xyz * vec3(-1.0, 1.0, 1.0)) / planks.w;   // boards upright: lit on their left
			float f = fract(t);
			float e = fwidth(t);
			plank = floor(t);
			if (f < e) {
				seam = true;
			} else if (f > 1.0 - e && bevel == 0) {
				bevel = 1;
			}
		}
		if (seam) {
			i = max(i - 2, 0);
		} else {
			i = clamp(i + bevel, 0, 5);
			if (grain > 0.0 && bevel == 0) {
				bool upright = abs(planks.x) > 0.5;
				vec2 key = upright ? vec2(floor(FRAGCOORD.x), floor(FRAGCOORD.y / 5.0) + plank * 7.0)
						: vec2(floor(FRAGCOORD.x / 5.0) + plank * 7.0, floor(FRAGCOORD.y));
				if (hash(key) > 0.86) i = max(i - 1, 0);
			}
		}
		col = ramp[i];
		if (planks.w > 0.0 && !seam) {
			col *= 0.95 + 0.1 * fract(sin(plank * 91.7) * 4375.85);
		}
	}
	ALBEDO = col;
}
