shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec2 center;              // wave origin in SCREEN_UV coords (0-1)
uniform float radius;             // current expanding radius (0.0 -> ~0.5)
uniform float strength;           // distortion intensity (fades over time)
uniform float wave_width;         // thickness of the active distortion band
uniform float ring_freq;          // number of concentric rings in the band

void fragment() {
	float dist = distance(SCREEN_UV, center);

	// Band mask: only distort within the expanding ring zone
	float inner = radius - wave_width;
	float mask = smoothstep(inner - 0.01, inner, dist) * (1.0 - smoothstep(radius, radius + 0.01, dist));

	// Concentric sine rings within the band
	float wave = sin((dist - inner) * ring_freq * TAU / wave_width) * mask * strength;

	// Radial UV displacement
	vec2 dir = normalize(SCREEN_UV - center + vec2(0.0001));
	vec2 displaced_uv = SCREEN_UV + dir * wave;

	vec4 color = texture(screen_texture, displaced_uv);

	// Subtle green tint in the distortion band
	color.g += mask * strength * 0.4;

	COLOR = color;
}
