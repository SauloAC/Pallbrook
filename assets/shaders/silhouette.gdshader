shader_type spatial;
// The doctor's silhouette, drawn only where a building (or anything solid) hides him.
// Used as a material_overlay on his meshes: each pixel of his body is compared with the depth
// of what's already on screen, and only drawn when something stands clearly in front of him.
// Two tests, so his own big head in front of his body never counts as "hidden":
//  - the thing in front must be closer to the camera than the top of his head
//  - and well in front of this very pixel of his body
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_back, blend_mix, shadows_disabled, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec4 color : source_color = vec4(0.94, 0.86, 0.66, 0.55);
uniform float body_height = 1.4;  // Feet to the top of the head, in meters
uniform float min_gap = 0.4;      // Meters in front of this pixel

varying float feet_dist;

void vertex() {
	// The model's origin is at his feet
	feet_dist = -(MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).z;
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).x;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_dist = -view.z / view.w;
	float body_dist = -VERTEX.z;
	if (scene_dist > feet_dist - body_height || body_dist - scene_dist < min_gap) {
		discard;
	}
	// A soft rim makes it read as a shape, not a flat sticker
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = color.rgb;
	ALPHA = color.a * (0.6 + 0.4 * rim);
}
