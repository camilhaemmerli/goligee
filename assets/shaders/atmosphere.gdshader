shader_type canvas_item;

// Full-screen atmosphere/vignette/color grading post-process.
// Apply to a full-screen ColorRect on the topmost CanvasLayer.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint_color : source_color = vec4(0.29, 0.19, 0.31, 1.0);  // #4A3050
uniform float tint_strength : hint_range(0.0, 1.0) = 0.1;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.6;
uniform float vignette_radius : hint_range(0.0, 1.5) = 0.8;
uniform float brightness : hint_range(0.5, 1.5) = 1.0;
uniform float contrast : hint_range(0.5, 1.5) = 1.05;

void fragment() {
	vec4 screen = texture(screen_texture, SCREEN_UV);
	vec3 color = screen.rgb;

	// Color tint
	color = mix(color, tint_color.rgb, tint_strength);

	// Brightness & contrast
	color = (color - 0.5) * contrast + 0.5;
	color *= brightness;

	// Vignette
	vec2 center = SCREEN_UV - 0.5;
	float dist = length(center);
	float vignette = smoothstep(vignette_radius, vignette_radius - 0.3, dist);
	color *= mix(1.0 - vignette_strength, 1.0, vignette);

	COLOR = vec4(color, 1.0);
}
