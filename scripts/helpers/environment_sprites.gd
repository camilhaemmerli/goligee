class_name EnvironmentSprites
extends RefCounted
## Procedurally generates small environmental prop textures for
## barricades, rubble, graffiti, vehicles, puddles, etc.


static func create_rubble(seed_val: int) -> ImageTexture:
	# 16x16 transparent with scattered debris pixels
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var colors := [Color("#28282C"), Color("#3A3A3E"), Color("#2E2E32"), Color("#242428")]
	for i in range(10):
		var h := _hash3(seed_val, i, 0)
		var x := h % 14 + 1
		var y := (h / 17) % 14 + 1
		var c := colors[h % colors.size()]
		img.set_pixel(x, y, c)
		# Some debris is 2px
		if h % 3 == 0 and x + 1 < 16:
			img.set_pixel(x + 1, y, c.darkened(0.1))
	return ImageTexture.create_from_image(img)


static func create_barricade() -> ImageTexture:
	# Isometric box shape, toppled — 32x16
	var img := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	var main := Color("#484850")
	var shadow := Color("#3A3A3E")
	var stripe := Color("#D8A040")  # Warning stripe

	# Main body (angled rectangle)
	for y in range(4, 14):
		for x in range(4, 28):
			var color := main if y < 9 else shadow
			# Warning stripes
			if (x + y) % 8 < 2:
				color = stripe
			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)


static func create_wire_coil() -> ImageTexture:
	# Concertina wire spiral — 24x12
	var img := Image.create(24, 12, false, Image.FORMAT_RGBA8)
	var wire_color := Color("#585860")
	# Spiral approximation
	for i in range(48):
		var t := i / 48.0 * TAU * 2.0
		var x := int(12.0 + cos(t) * (4.0 + i * 0.15))
		var y := int(6.0 + sin(t) * 3.0)
		if x >= 0 and x < 24 and y >= 0 and y < 12:
			img.set_pixel(x, y, wire_color)
	return ImageTexture.create_from_image(img)


static func create_graffiti_tag(seed_val: int) -> ImageTexture:
	# Small pixel text/tag — 12x6
	var img := Image.create(12, 6, false, Image.FORMAT_RGBA8)
	var colors := [Color("#D04040"), Color("#D8A040"), Color("#A0D8A0")]
	var tag_color := colors[seed_val % colors.size()]
	# Random pixel cluster resembling a tag
	for i in range(8):
		var h := _hash3(seed_val, i, 7)
		var x := 1 + h % 10
		var y := 1 + (h / 11) % 4
		if x < 12 and y < 6:
			img.set_pixel(x, y, tag_color)
			if x + 1 < 12:
				img.set_pixel(x + 1, y, tag_color.darkened(0.15))
	return ImageTexture.create_from_image(img)


static func create_burned_vehicle() -> ImageTexture:
	# Elongated dark shape with ember pixels — 48x24
	var img := Image.create(48, 24, false, Image.FORMAT_RGBA8)
	var body := Color("#1E1E22")
	var frame := Color("#28282C")
	var ember := Color("#D06030")
	var ember_dim := Color("#903020")

	# Vehicle body silhouette
	for y in range(8, 20):
		var x_start := 4 + (20 - y) / 3 if y < 14 else 4
		var x_end := 44 - (20 - y) / 3 if y < 14 else 44
		for x in range(max(x_start, 0), min(x_end, 48)):
			img.set_pixel(x, y, body)

	# Frame/chassis
	for x in range(6, 42):
		img.set_pixel(x, 19, frame)
	for x in range(8, 16):
		for y in range(6, 10):
			img.set_pixel(x, y, frame)

	# Wheels (darker circles)
	for wx in [12, 34]:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if dx * dx + dy * dy <= 4:
					var px := wx + dx
					var py := 19 + dy
					if px >= 0 and px < 48 and py >= 0 and py < 24:
						img.set_pixel(px, py, Color("#121216"))

	# Ember pixels
	img.set_pixel(18, 10, ember)
	img.set_pixel(22, 8, ember_dim)
	img.set_pixel(30, 11, ember)

	return ImageTexture.create_from_image(img)


static func create_puddle() -> ImageTexture:
	# 12x6 ellipse — dark reflective
	var img := Image.create(12, 6, false, Image.FORMAT_RGBA8)
	var puddle_color := Color("#1A1A1E")
	var highlight := Color("#28282C")

	for y in 6:
		for x in 12:
			var dx := (x - 6.0) / 6.0
			var dy := (y - 3.0) / 3.0
			if dx * dx + dy * dy <= 1.0:
				var color := puddle_color
				if y == 2 and x > 4 and x < 8:
					color = highlight  # Tiny reflection
				img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)


static func create_sandbag_stack() -> ImageTexture:
	# 20x12 — stacked bags
	var img := Image.create(20, 12, false, Image.FORMAT_RGBA8)
	var bag_light := Color("#605848")
	var bag_dark := Color("#484038")
	var seam := Color("#383028")

	# Bottom row (2 bags)
	for y in range(6, 12):
		for x in range(2, 18):
			var color := bag_light if x < 10 else bag_dark
			if x == 10:
				color = seam
			img.set_pixel(x, y, color)

	# Top bag (1 bag centered)
	for y in range(2, 7):
		for x in range(5, 15):
			var color := bag_light
			if y > 4:
				color = bag_dark
			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)


static func _hash3(a: int, b: int, c: int) -> int:
	var v := (a * 73856093 + b * 19349663 + c * 83492791) & 0xFFFFFF
	return absi(v)
