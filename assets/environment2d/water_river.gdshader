shader_type spatial;
render_mode specular_disabled;

// The river in the painted style (Nature2D.gd): flat pixel-art water, one art pixel to a screen pixel
// like the ground (PX east-west, PX on screen north-south). A dark line under the bank's lip, a
// lighter shallow band, and the Cainos pack's foam pattern (TX FX Water Foam) drifting slowly
// downstream, stepped a few times a second like hand-drawn frames. Lit like the painted buildings.
// Where the water touches something it froths: rings that rise and fade around each rock (and the
// bridge's feet), a short wake downstream of them, and foam lapping at the banks.
uniform sampler2D foam : filter_nearest, repeat_enable;
uniform vec2 banks = vec2(-15.0, -10.0);     // World x of the west and east water's edge
uniform float px = 0.04375;
uniform vec3 deep : source_color = vec3(0.196, 0.290, 0.318);
uniform vec3 shallow : source_color = vec3(0.247, 0.357, 0.373);
uniform vec3 edge : source_color = vec3(0.110, 0.149, 0.157);
uniform vec3 froth : source_color = vec3(0.62, 0.71, 0.69);
uniform float flow = 6.0;                    // Art pixels a second, southward (+z)
uniform float fps = 6.0;
uniform vec4 rocks[48];                     // Each rock's foot (art pixel x, screen row), half width and depth in pixels
uniform int rock_count = 0;
uniform float lit_share = 0.5;
uniform float own_light = 0.85;
uniform vec3 night_tint : source_color = vec3(0.55, 0.66, 0.95);
global uniform float sprite_daylight;
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// Art pixel this fragment is in: rows as on screen (z * sin50 - y * cos50), so they line up with the ground's
	vec2 p = floor(vec2(world.x / px, (world.z * 0.76604444 - world.y * 0.64278761) / px));
	float d = min(world.x - banks.x, banks.y - world.x) / px;   // Pixels from the nearer bank
	float t = floor(TIME * fps) / fps;
	vec3 c = mix(shallow, deep, smoothstep(4.0, 22.0, d));
	// Two layers of the foam's cells, drifting at different speeds: where a line shows, it froths
	float a = texture(foam, (p + vec2(0.0, -floor(t * flow))) / 256.0).a;
	float b = texture(foam, (p.yx * vec2(1.0, -1.0) + vec2(37.0, floor(t * flow * 0.6))) / 256.0).a;
	float near = 1.0 - smoothstep(3.0, 14.0, d);
	float lines = a * (0.07 + 0.28 * near) + b * a * 0.10;
	c = mix(c, froth, clamp(lines, 0.0, 0.6));
	// Glints: now and then a single bright pixel far from the banks
	float g = hash(p + floor(t * 2.0) * 13.0);
	if (g > 0.9975 && d > 6.0) {
		c = mix(c, froth, 0.7);
	}
	// Foam lapping at the banks: a broken line that comes in and goes out, and froth at the edge
	float wave = 4.0 + 1.6 * sin(p.y * 0.21 + t * 1.7 + (world.x < (banks.x + banks.y) * 0.5 ? 0.0 : 2.1))
			+ 0.8 * sin(p.y * 0.53 - t * 2.3);
	if (abs(d - wave) < 0.6 && hash(vec2(floor(p.y / 3.0), floor(t * 1.5))) > 0.25) {
		c = mix(c, froth, 0.55);
	}
	if (d >= 1.0 && d < 2.0 && hash(vec2(floor(p.y / 5.0), floor(t * 2.0) + 7.0)) > 0.45) {
		c = mix(c, froth, 0.45);
	}
	// Around the rocks
	for (int i = 0; i < rock_count; i++) {
		vec4 r = rocks[i];
		vec2 q = p - vec2(r.x, r.y - r.w * 0.5);   // From the middle of where it meets the water
		if (abs(q.x) > r.z * 2.4 + 4.0 || q.y < -r.w * 3.0 || q.y > r.z * 3.5 + 6.0) {
			continue;
		}
		vec2 radii = vec2(r.z * 0.95, max(r.w * 0.5, 2.0));
		float e = length(q / radii);
		float px_e = 1.0 / radii.y;                 // About one pixel, in e
		float seed = fract(r.x * 0.137 + r.y * 0.071);
		// Froth hugging the rock
		if (e > 0.85 && e < 1.0 + 1.6 * px_e && hash(floor(p / 2.0) + floor(t * 3.0)) > 0.2) {
			c = mix(c, froth, 0.75);
		}
		// Two rings rising out from it and fading
		for (int k = 0; k < 2; k++) {
			float phase = fract(t * 0.45 + seed + float(k) * 0.5);
			float ring = 1.15 + phase * 0.9;
			float ang = atan(q.y, q.x);
			if (abs(e - ring) < px_e * 0.9 && hash(vec2(floor(ang * 6.0), floor(phase * 4.0) + float(k) * 9.0 + seed * 50.0)) > 0.3) {
				c = mix(c, froth, 0.6 * (1.0 - phase));
			}
		}
		// A short wake downstream (south), in streaks that drift with the water
		float behind = q.y - radii.y;
		float wake_len = r.z * 2.5 + 4.0;
		if (behind > 0.0 && behind < wake_len && abs(q.x) < r.z * 0.8 * (1.0 - behind / wake_len) + 0.5) {
			float streak = hash(vec2(floor(q.x * 0.5), floor((p.y - t * flow) / 3.0) + seed * 30.0));
			if (streak > 0.62) {
				c = mix(c, froth, 0.4 * (1.0 - behind / wake_len));
			}
		}
	}
	// The bank: a dark line where the water meets it, and its lip's shadow on the water
	if (d < 1.0) {
		c = edge;
	} else if (d < 3.0) {
		c *= 0.78;
	}
	ALBEDO = c * lit_share;
	vec3 moon = mix(night_tint, vec3(1.0), smoothstep(0.12, 0.8, sprite_daylight));
	EMISSION = c * own_light * sprite_daylight * moon;
	ROUGHNESS = 1.0;
}
