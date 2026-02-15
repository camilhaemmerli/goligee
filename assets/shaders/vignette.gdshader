shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform float radius : hint_range(0.0, 1.5) = 0.8;
uniform vec3 vignette_color : source_color = vec3(0.055, 0.055, 0.07);

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;
	float vignette = smoothstep(radius, radius + 0.5, dist) * intensity;
	COLOR = vec4(vignette_color, vignette);
}
