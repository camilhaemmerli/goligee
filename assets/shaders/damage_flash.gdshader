shader_type canvas_item;

// Flash a sprite white/color when taking damage.
// Set flash_amount to 1.0 then tween it back to 0.0.

uniform vec4 flash_color : source_color = vec4(0.88, 0.69, 0.72, 1.0);  // #E0B0B8
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Mix original sprite with flash color, preserving alpha
	vec3 flashed = mix(tex.rgb, flash_color.rgb, flash_amount);
	COLOR = vec4(flashed, tex.a);
}
