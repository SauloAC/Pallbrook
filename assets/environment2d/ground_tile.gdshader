shader_type spatial;
render_mode specular_disabled;

// Painted ground tiles laid over the 3D ground (Nature2D), lit like the painted buildings
// (tile_surface.gdshader). The tile is placed by world position, one art pixel to a screen pixel:
// PX metres east-west, PX / sin(50 deg) north-south (the camera's 50-degree tilt squashes the ground).
uniform sampler2D tex : source_color, filter_nearest, repeat_enable;
uniform float tile_px = 128.0;
uniform float px = 0.04375;
uniform float lit_share = 0.5;
uniform float own_light = 0.85;
uniform vec3 night_tint : source_color = vec3(0.55, 0.66, 0.95);
global uniform float sprite_daylight;
varying vec2 tile_uv;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tile_uv = vec2(w.x / px, w.z * 0.76604444 / px) / tile_px;
}

void fragment() {
	vec3 c = texture(tex, tile_uv).rgb;
	ALBEDO = c * lit_share;
	vec3 moon = mix(night_tint, vec3(1.0), smoothstep(0.12, 0.8, sprite_daylight));
	EMISSION = c * own_light * sprite_daylight * moon;
	ROUGHNESS = 1.0;
}
