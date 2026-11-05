shader_type spatial;
render_mode specular_disabled;

// Painted plants in the wind (Nature2D.gd): the picture of a tree, a bush or a tuft of grass sways
// sideways by whole art pixels, more toward the top, while its foot (the trunk) stays put. Stepped a
// few times a second like hand-drawn frames, each plant on its own rhythm (from where it stands).
// Lit like the painted buildings (sprite_surface.gdshader).
uniform sampler2D tex : source_color, filter_nearest;
uniform float lit_share = 0.5;
uniform float own_light = 0.85;
uniform vec3 night_tint : source_color = vec3(0.55, 0.66, 0.95);
uniform float px = 0.04375;      // The sprite's pixel size: rows are counted from its foot
uniform float still_px = 30.0;   // Rows from the foot that never move (the trunk)
uniform float bend_px = 40.0;    // Rows over which the sway grows to its full amount
uniform float amount = 1.4;      // Pixels at the top, in a strong gust
uniform float speed = 1.0;
uniform float fps = 5.0;
global uniform float sprite_daylight;
varying float row;
varying float seed;

void vertex() {
	row = VERTEX.y / px;
	// The same for a plant and its unseen shadow caster on the ground: the painted one is pulled toward
	// the camera, (0, 0.766, 0.643) per metre, so the height is taken back out of the depth
	vec3 at = NODE_POSITION_WORLD;
	seed = at.x * 0.73 + (at.z - at.y * 0.8391) * 1.31;
}

void fragment() {
	float t = floor(TIME * fps) / fps;
	// A slow breeze and the odd gust, out of step from plant to plant
	float wind = sin(t * 1.1 * speed + seed) * 0.6 + sin(t * 0.41 * speed + seed * 0.37) * 0.55;
	float k = clamp((floor(row) - still_px) / bend_px, 0.0, 1.0);
	float shift = round(wind * amount * k);
	vec2 uv = UV;
	uv.x -= shift / float(textureSize(tex, 0).x);
	vec4 c = texture(tex, uv);
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb * lit_share;
	vec3 tint = mix(night_tint, vec3(1.0), smoothstep(0.12, 0.8, sprite_daylight));
	EMISSION = c.rgb * own_light * sprite_daylight * tint;
	ROUGHNESS = 1.0;
}
