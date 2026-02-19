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
		var c: Color = colors[h % colors.size()]
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
	var stripe := Color("#F0F0F0")  # Warning stripe

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
	var colors := [Color("#D04040"), Color("#F0F0F0"), Color("#A0D8A0")]
	var tag_color: Color = colors[seed_val % colors.size()]
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
					var px: int = wx + dx
					var py: int = 19 + dy
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


static func create_oil_barrel() -> ImageTexture:
	# 16x20 isometric oil barrel — dark metal with rust patches and top ellipse
	var img := Image.create(16, 20, false, Image.FORMAT_RGBA8)
	var body := Color("#2A2A30")
	var rust := Color("#5A3828")
	var rim := Color("#3A3A42")
	var top := Color("#383840")
	var highlight := Color("#44444C")

	# Barrel body (rounded rectangle)
	for y in range(6, 20):
		for x in range(3, 13):
			var dx := absf(x - 7.5)
			if dx > 5.0:
				continue
			var color := body
			# Vertical highlight on left side
			if x == 5 or x == 6:
				color = highlight
			# Rust patches (deterministic)
			if (x * 7 + y * 13) % 17 < 2:
				color = rust
			# Bottom rim
			if y >= 18:
				color = rim
			img.set_pixel(x, y, color)

	# Top ellipse
	for y in range(4, 8):
		for x in range(3, 13):
			var dx := (x - 7.5) / 5.0
			var dy := (y - 5.5) / 1.8
			if dx * dx + dy * dy <= 1.0:
				var color := top
				if dy < -0.3:
					color = rim
				img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)


static func create_fire_particle(seed_val: int) -> ImageTexture:
	# 8x10 flame shape — core white-yellow to outer orange-red, wobble per seed
	var img := Image.create(8, 10, false, Image.FORMAT_RGBA8)
	var core := Color("#FFFBE0")       # white-yellow
	var mid := Color("#FFA820")        # orange
	var outer := Color("#E04010")      # red-orange
	var tip := Color("#C03008")        # dark tip

	var wobble := (seed_val % 5) - 2  # -2 to +2 px horizontal wobble

	for y in 10:
		for x in 8:
			var cx := 3.5 + wobble * (y / 10.0) * 0.3
			var dx := absf(x - cx)
			# Flame narrows toward top
			var width := 3.5 * (1.0 - y / 12.0)
			if dx > width:
				continue
			var t := y / 10.0  # 0=top, 1=bottom
			var color: Color
			if t < 0.25:
				color = tip.lerp(outer, t / 0.25)
			elif t < 0.5:
				color = outer.lerp(mid, (t - 0.25) / 0.25)
			elif t < 0.8:
				color = mid.lerp(core, (t - 0.5) / 0.3)
			else:
				color = core
			# Fade edges
			var edge_t := dx / width
			color.a = clampf(1.0 - edge_t * 0.6, 0.3, 1.0)
			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)


static func create_fire_glow() -> ImageTexture:
	# 24x12 radial gradient ellipse — warm orange, max 25% alpha
	var img := Image.create(24, 12, false, Image.FORMAT_RGBA8)
	var glow_color := Color("#FF8020")

	for y in 12:
		for x in 24:
			var dx := (x - 11.5) / 12.0
			var dy := (y - 5.5) / 6.0
			var dist := dx * dx + dy * dy
			if dist > 1.0:
				continue
			var alpha := (1.0 - dist) * 0.25
			img.set_pixel(x, y, Color(glow_color.r, glow_color.g, glow_color.b, alpha))

	return ImageTexture.create_from_image(img)


static func create_tire_stack() -> ImageTexture:
	# 16x12 two stacked rubber tires
	var img := Image.create(16, 12, false, Image.FORMAT_RGBA8)
	var rubber := Color("#1E1E22")
	var tread := Color("#2A2A30")
	var rim := Color("#343438")

	# Bottom tire (ellipse)
	for y in range(6, 12):
		for x in range(1, 15):
			var dx := (x - 7.5) / 7.0
			var dy := (y - 9.0) / 3.0
			if dx * dx + dy * dy <= 1.0:
				var color := rubber
				if absf(dy) < 0.4:
					color = tread
				img.set_pixel(x, y, color)

	# Top tire (offset slightly)
	for y in range(1, 8):
		for x in range(2, 14):
			var dx := (x - 7.5) / 6.0
			var dy := (y - 4.0) / 3.0
			if dx * dx + dy * dy <= 1.0:
				var color := rubber
				if absf(dy) < 0.4:
					color = tread
				# Rim highlight
				if dx * dx + dy * dy > 0.5 and dx * dx + dy * dy < 0.7:
					color = rim
				img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)


static func create_fallen_sign(seed_val: int) -> ImageTexture:
	# 20x10 fallen cardboard protest sign with random text color
	var img := Image.create(20, 10, false, Image.FORMAT_RGBA8)
	var cardboard := Color("#8A7858")
	var cardboard_dark := Color("#706048")
	var text_colors := [Color("#D04040"), Color("#2040A0"), Color("#206020")]
	var text_color: Color = text_colors[seed_val % text_colors.size()]

	# Sign body (slight angle via row offset)
	for y in range(2, 9):
		var x_off := (y - 2) / 4  # slight lean
		for x in range(2 + x_off, 18 + x_off):
			if x >= 20:
				continue
			var color := cardboard if y < 6 else cardboard_dark
			img.set_pixel(x, y, color)

	# "Text" scribbles
	for i in range(6):
		var h := _hash3(seed_val, i, 33)
		var x := 4 + h % 12
		var y := 3 + (h / 13) % 4
		if x < 19 and y < 8:
			img.set_pixel(x, y, text_color)
			if x + 1 < 19:
				img.set_pixel(x + 1, y, text_color.darkened(0.2))

	# Stick (pole fragment)
	for y in range(5, 10):
		img.set_pixel(1, y, Color("#605040"))

	return ImageTexture.create_from_image(img)


static func _hash3(a: int, b: int, c: int) -> int:
	var v := (a * 73856093 + b * 19349663 + c * 83492791) & 0xFFFFFF
	return absi(v)
