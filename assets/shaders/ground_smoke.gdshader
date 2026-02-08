shader_type canvas_item;

// Ground-level rolling smoke. Thickest at the bottom, warmer color than fog.
// Apply to a full-screen ColorRect on a CanvasLayer below fog.

uniform sampler2D noise_texture : hint_default_white, filter_linear, repeat_enable;
uniform vec4 smoke_color : source_color = vec4(0.28, 0.25, 0.25, 0.35);
uniform float scroll_speed : hint_range(0.0, 0.2) = 0.025;
uniform float density : hint_range(0.0, 1.0) = 0.25;
uniform float noise_scale : hint_range(0.1, 10.0) = 3.0;

void fragment() {
	vec2 uv = UV * noise_scale;

	float t = TIME;
	vec2 offset1 = vec2(t * scroll_speed, t * scroll_speed * 0.4);
	vec2 offset2 = vec2(-t * scroll_speed * 0.6, t * scroll_speed * 0.8);

	float noise1 = texture(noise_texture, uv + offset1).r;
	float noise2 = texture(noise_texture, uv * 0.7 + offset2).r;
	float combined = (noise1 + noise2) * 0.5;

	// Inverted vertical fade: thickest at the bottom
	float vertical = smoothstep(0.3, 0.95, UV.y);

	float alpha = smoke_color.a * combined * density * vertical;

	COLOR = vec4(smoke_color.rgb, alpha);
}
