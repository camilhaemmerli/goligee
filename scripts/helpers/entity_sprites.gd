class_name EntitySprites
extends RefCounted
## Procedurally generates themed tower, enemy, and projectile sprites.
## Replaces the generic placeholder diamonds with recognizable shapes.


# -- TOWERS (32x32) --

static func create_tower_turret(base_color: Color, accent_color: Color) -> ImageTexture:
	# Isometric turret: pedestal base + barrel
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var dark := base_color.darkened(0.2)
	var light := base_color.lightened(0.15)

	# Pedestal base (isometric box, bottom half)
	var half := size / 2.0
	for y in range(16, 28):
		for x in size:
			var dx := absf(x - half + 0.5) / half
			var dy := absf(y - 22.0 + 0.5) / 6.0
			if dx + dy <= 1.0:
				var color := dark if x < int(half) else base_color
				if y > 24:
					color = color.darkened(0.15)
				img.set_pixel(x, y, color)

	# Turret body (upper portion)
	for y in range(8, 18):
		for x in range(10, 22):
			var color := base_color
			if x < 16:
				color = dark
			else:
				color = light
			img.set_pixel(x, y, color)

	# Barrel (horizontal line from center-right)
	for x in range(18, 28):
		for y in range(11, 14):
			img.set_pixel(x, y, accent_color)

	# Muzzle tip
	img.set_pixel(28, 12, accent_color.lightened(0.3))

	return ImageTexture.create_from_image(img)


static func create_arrow_tower() -> ImageTexture:
	return create_tower_turret(Color("#606068"), Color("#90A0B8"))


static func create_cannon_tower() -> ImageTexture:
	return create_tower_turret(Color("#585850"), Color("#A08060"))


static func create_ice_tower() -> ImageTexture:
	# Distinct look: crystalline shape
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var base := Color("#80A0C0")
	var dark := Color("#506880")
	var glow := Color("#B0D0E8")

	# Crystal base
	var half := size / 2.0
	for y in range(14, 28):
		for x in size:
			var dx := absf(x - half + 0.5) / half
			var dy := absf(y - 22.0 + 0.5) / 6.0
			if dx + dy <= 1.0:
				var color := dark if x < int(half) else base
				img.set_pixel(x, y, color)

	# Crystal spire
	for y in range(4, 16):
		var width_at_y := int((16.0 - y) / 12.0 * 6.0) + 2
		for x in range(16 - width_at_y, 16 + width_at_y):
			if x >= 0 and x < size:
				var color := base
				if x < 16:
					color = dark
				if y < 8:
					color = glow
				img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)


# -- ENEMIES (16x16) --

static func create_enemy_figure(body_color: Color, accent_color: Color) -> ImageTexture:
	# Small humanoid figure silhouette
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var dark := body_color.darkened(0.25)

	# Head (circle at top)
	for y in range(2, 6):
		for x in range(6, 10):
			var dx := x - 8.0
			var dy := y - 4.0
			if dx * dx + dy * dy <= 4.5:
				img.set_pixel(x, y, body_color)

	# Body (torso)
	for y in range(6, 11):
		for x in range(5, 11):
			img.set_pixel(x, y, body_color if x >= 8 else dark)

	# Legs
	for y in range(11, 15):
		img.set_pixel(6, y, dark)
		img.set_pixel(7, y, dark)
		img.set_pixel(9, y, body_color)
		img.set_pixel(10, y, body_color)

	# Accent (sign/banner held — small horizontal line)
	for x in range(3, 8):
		img.set_pixel(x, 8, accent_color)

	return ImageTexture.create_from_image(img)


static func create_protestor() -> ImageTexture:
	return create_enemy_figure(Color("#D06040"), Color("#D8A040"))


static func create_agitator_elite() -> ImageTexture:
	return create_enemy_figure(Color("#A04050"), Color("#D04040"))


static func create_mob_boss() -> ImageTexture:
	# Larger, more imposing figure
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var body := Color("#802030")
	var dark := body.darkened(0.2)
	var glow := Color("#D04040")

	# Head
	for y in range(1, 5):
		for x in range(5, 11):
			var dx := x - 8.0
			var dy := y - 3.0
			if dx * dx + dy * dy <= 6:
				img.set_pixel(x, y, body)

	# Broad body
	for y in range(5, 12):
		for x in range(3, 13):
			img.set_pixel(x, y, body if x >= 8 else dark)

	# Legs
	for y in range(12, 16):
		for x in [5, 6, 10, 11]:
			img.set_pixel(x, y, dark)

	# Glow effect around edges
	for x in [3, 12]:
		for y in range(6, 11):
			img.set_pixel(x, y, glow)

	return ImageTexture.create_from_image(img)


# -- PROJECTILES (8x8) --

static func create_projectile_streak(color: Color) -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var bright := color.lightened(0.3)

	# Streak: horizontal bright line with trail
	for x in range(2, 7):
		img.set_pixel(x, 3, color)
		img.set_pixel(x, 4, color)
	# Bright tip
	img.set_pixel(6, 3, bright)
	img.set_pixel(6, 4, bright)
	# Dim trail
	img.set_pixel(1, 3, color.darkened(0.3))
	img.set_pixel(1, 4, color.darkened(0.3))

	return ImageTexture.create_from_image(img)


static func create_cannonball() -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var color := Color("#484850")
	var highlight := Color("#60606A")

	for y in 8:
		for x in 8:
			var dx := x - 4.0
			var dy := y - 4.0
			if dx * dx + dy * dy <= 9:
				var c := color
				if dx < 0 and dy < 0:
					c = highlight
				img.set_pixel(x, y, c)

	return ImageTexture.create_from_image(img)


static func create_ice_shard() -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var color := Color("#80C0E0")
	var bright := Color("#B0E0F0")

	# Diamond/shard shape
	for y in 8:
		for x in 8:
			var dx := absf(x - 4.0) / 4.0
			var dy := absf(y - 4.0) / 2.0
			if dx + dy <= 1.0:
				var c := color
				if y < 4:
					c = bright
				img.set_pixel(x, y, c)

	return ImageTexture.create_from_image(img)


static func create_tear_gas_canister() -> ImageTexture:
	## 8x8 dark metal cylinder with orange warning band.
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var body := Color("#404048")
	var dark := Color("#303038")
	var band := Color("#E08040")
	var cap := Color("#505058")

	# Top cap
	for x in range(2, 6):
		img.set_pixel(x, 0, cap)

	# Body with shading
	for y in range(1, 7):
		for x in range(2, 6):
			var c := body if x >= 4 else dark
			# Orange warning band in the middle
			if y >= 3 and y <= 4:
				c = band if x >= 4 else band.darkened(0.2)
			img.set_pixel(x, y, c)

	# Bottom cap
	for x in range(2, 6):
		img.set_pixel(x, 7, dark)

	return ImageTexture.create_from_image(img)
