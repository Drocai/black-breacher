shader_type canvas_item;

// Red edge vignette that intensifies as the player's health drops.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv) * 1.5;
	float v = smoothstep(0.45, 0.95, d) * intensity;
	COLOR = vec4(0.65, 0.0, 0.0, v);
}
