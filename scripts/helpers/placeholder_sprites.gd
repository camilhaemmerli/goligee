class_name PlaceholderSprites
extends RefCounted
## Generates colored placeholder textures at runtime for towers, enemies,
## and projectiles when no sprite asset is assigned.

static func create_diamond(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size / 2.0
	var quarter := size / 4.0

	for y in size:
		for x in size:
			# Isometric diamond: |x - half| / half + |y - half| / quarter <= 1
			var dx := absf(x - half + 0.5) / half
			var dy := absf(y - half + 0.5) / quarter
			if dx + dy <= 1.0:
				# Darken lower half for depth
				var shade := color
				if y > half:
					shade = color.darkened(0.25)
				img.set_pixel(x, y, shade)

	return ImageTexture.create_from_image(img)


static func create_circle(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := size / 2.0
	var radius := center - 0.5

	for y in size:
		for x in size:
			var dx := x - center + 0.5
			var dy := y - center + 0.5
			if dx * dx + dy * dy <= radius * radius:
				img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)
