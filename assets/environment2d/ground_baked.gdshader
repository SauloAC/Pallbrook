shader_type spatial;
render_mode specular_disabled;

// The town's ground painted as one picture (ground_baked.png, made by art_source/tools/env2d/bake.py):
// Cainos grass, dirt paths and cobbled streets with soft, hand-drawn edges, one art pixel to a screen
// pixel. Placed by world position (PX east-west, PX / sin 50 north-south). Outside the picture, the
// plain grass tile repeats. Lit like the painted buildings (tile_surface.gdshader).
uniform sampler2D baked : source_color, filter_nearest;
uniform sampler2D grass : source_color, filter_nearest, repeat_enable;
uniform vec2 origin = vec2(-34.0, -72.0);   // World x, z of the picture's top-left corner
uniform vec2 size_px = vec2(1920.0, 2136.0);
uniform float px = 0.04375;
uniform float lit_share = 0.5;
uniform float own_light = 0.85;
uniform vec3 night_tint : source_color = vec3(0.55, 0.66, 0.95);
global uniform float sprite_daylight;
varying vec2 at_px;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	at_px = vec2((w.x - origin.x) / px, (w.z - origin.y) * 0.76604444 / px);
}

void fragment() {
	vec3 c;
	if (at_px.x >= 0.0 && at_px.y >= 0.0 && at_px.x < size_px.x && at_px.y < size_px.y) {
		c = texture(baked, (floor(at_px) + 0.5) / size_px).rgb;
	} else {
		c = texture(grass, at_px / 128.0).rgb;
	}
	ALBEDO = c * lit_share;
	vec3 moon = mix(night_tint, vec3(1.0), smoothstep(0.12, 0.8, sprite_daylight));
	EMISSION = c * own_light * sprite_daylight * moon;
	ROUGHNESS = 1.0;
}
