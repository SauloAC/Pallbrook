shader_type canvas_item;

// Brightness setting (Settings.gd): a gamma curve over the 3D picture underneath.
// gamma > 1 lifts the shadows a lot and the highlights very little.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float gamma = 1.0;

void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	COLOR = vec4(pow(c, vec3(1.0 / gamma)), 1.0);
}
