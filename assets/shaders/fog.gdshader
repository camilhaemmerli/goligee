shader_type canvas_item;

// Atmospheric fog overlay for chemical tower gas buildup.
// Applied to a world-space Sprite2D (z_index=40) so PointLight2D can illuminate it.

uniform sampler2D noise_texture : hint_default_white, filter_linear, repeat_enable;
uniform vec4 fog_color_near : source_color = vec4(0.29, 0.19, 0.31, 0.4);  // #4A3050
uniform vec4 fog_color_far  : source_color = vec4(0.42, 0.29, 0.37, 0.6);  // #6B4A60
uniform float scroll_speed : hint_range(0.0, 0.1) = 0.015;
uniform float density : hint_range(0.0, 1.0) = 0.35;
uniform float noise_scale : hint_range(0.1, 10.0) = 2.0;
uniform float vertical_fade_start : hint_range(0.0, 1.0) = 0.3;
uniform float vertical_fade_end : hint_range(0.0, 1.0) = 0.8;
uniform float time_scale : hint_range(0.0, 2.0) = 1.0;
uniform vec2 camera_position = vec2(0.0);
uniform vec2 viewport_size = vec2(1280.0, 720.0);

void fragment() {
	// World-space UV so noise stays anchored when camera pans
	vec2 world_uv = (camera_position + (UV - 0.5) * viewport_size) / viewport_size * noise_scale;

	// Two scrolling noise layers for organic movement
	float t = TIME * time_scale;
	vec2 offset1 = vec2(t * scroll_speed, t * scroll_speed * 0.3);
	vec2 offset2 = vec2(-t * scroll_speed * 0.7, t * scroll_speed * 0.5);

	float noise1 = texture(noise_texture, world_uv + offset1).r;
	float noise2 = texture(noise_texture, world_uv * 0.5 + offset2).r;
	float combined_noise = (noise1 + noise2) * 0.5;

	// Vertical fade: fog is thickest near the bottom
	float vertical_factor = smoothstep(vertical_fade_start, vertical_fade_end, UV.y);

	// Blend between near and far fog colors based on vertical position
	vec4 fog = mix(fog_color_far, fog_color_near, vertical_factor);

	// Apply noise to fog alpha
	float alpha = fog.a * combined_noise * density * vertical_factor;

	COLOR = vec4(fog.rgb, alpha);
}

void light() {
	// Explosion PointLight2D illuminates the fog from below
	float intensity = length(LIGHT_COLOR.rgb) * LIGHT_ENERGY;
	LIGHT = vec4(LIGHT_COLOR.rgb * intensity, intensity * 0.5);
}
