shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

// Chimney smoke (Cainos Village FX): a wavy ribbon scrolling up, faded by a ramp from the chimney mouth.
uniform sampler2D smoke : source_color, filter_linear, repeat_enable;
uniform sampler2D ramp : source_color, filter_linear;
uniform float speed = 0.12;          // how fast the ribbon climbs (texture heights per second)
uniform float strength = 0.55;
uniform vec3 day_color : source_color = vec3(0.86, 0.84, 0.80);
uniform vec3 night_color : source_color = vec3(0.30, 0.33, 0.40);
global uniform float sprite_daylight;

void fragment() {
	// UV.y is 0 at the top of the quad, 1 at the chimney
	float s = texture(smoke, vec2(UV.x, UV.y + TIME * speed)).a;
	float fade = texture(ramp, vec2(0.5, UV.y)).a;
	float a = s * fade * strength;
	if (a < 0.02) {
		discard;
	}
	ALBEDO = mix(night_color, day_color, smoothstep(0.12, 0.8, sprite_daylight));
	ALPHA = a;
}
