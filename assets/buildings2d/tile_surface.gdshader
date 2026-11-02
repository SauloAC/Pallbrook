shader_type spatial;
render_mode specular_disabled;  // Back faces culled: through the art's transparent edges you see the ground, not the hidden faces

// Painted 2D art projected onto simple 3D volumes (see the design doc, "Prédios em 2D"). The art already has its
// light painted in, so part of it is shown as it was drawn (emission, by day) and part is lit by
// the scene (sun, shadows, lamps). sprite_daylight comes from DayNightCycle: 1 by day, low at night.
uniform sampler2D tex : source_color, filter_nearest, repeat_enable;  // Tiled floors and walls
uniform float lit_share = 0.55;  // How much of the colour the scene's light shapes
uniform float own_light = 0.6;   // How much of the painted light shows by day
uniform vec3 night_tint : source_color = vec3(0.55, 0.66, 0.95);  // Moonlight, as the 3D town gets it
global uniform float sprite_daylight;

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb * lit_share;
	// By day the painted light shows as drawn; toward night it cools to the moon's colour
	vec3 tint = mix(night_tint, vec3(1.0), smoothstep(0.12, 0.8, sprite_daylight));
	EMISSION = c.rgb * own_light * sprite_daylight * tint;
	ROUGHNESS = 1.0;
}
