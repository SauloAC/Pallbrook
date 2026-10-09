shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float dist = distance(UV, vec2(0.5));           // 0 at center, ~0.7 at corners
	float inner = mix(0.75, 0.15, intensity);        // Dark area grows with intensity
	float alpha = smoothstep(inner, inner + 0.35, dist);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
