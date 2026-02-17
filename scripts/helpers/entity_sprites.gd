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


static func create_press_drone() -> ImageTexture:
	## 16x16 quadcopter body: center module, 4 arms, motor mounts, camera lens.
	## Rotors are a separate overlay — see create_press_drone_rotors().
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var body := Color("#3A3A4A")
	var body_hi := Color("#4A4A5A")
	var arm := Color("#505060")
	var motor := Color("#2A2A38")
	var motor_hi := Color("#606070")
	var lens := Color("#D04040")
	var led_front := Color("#40D060")
	var led_rear := Color("#D04040")

	# Central body: 4x4 with shading (top-left lighter)
	for y in range(6, 10):
		for x in range(6, 10):
			img.set_pixel(x, y, body_hi if (x + y < 14) else body)
	# Camera gimbal (slightly darker center underside)
	img.set_pixel(7, 8, Color("#2A2A38"))
	img.set_pixel(8, 8, Color("#2A2A38"))
	# Camera lens
	img.set_pixel(7, 9, lens)
	img.set_pixel(8, 9, lens)
	# Front LED
	img.set_pixel(7, 6, led_front)
	# Rear LEDs
	img.set_pixel(7, 9, led_rear)

	# Four diagonal arms (2px thick for visibility)
	# NW arm
	img.set_pixel(5, 5, arm); img.set_pixel(4, 4, arm); img.set_pixel(5, 4, arm)
	# NE arm
	img.set_pixel(10, 5, arm); img.set_pixel(11, 4, arm); img.set_pixel(10, 4, arm)
	# SW arm
	img.set_pixel(5, 10, arm); img.set_pixel(4, 11, arm); img.set_pixel(5, 11, arm)
	# SE arm
	img.set_pixel(10, 10, arm); img.set_pixel(11, 11, arm); img.set_pixel(10, 11, arm)

	# Motor mounts at arm tips (2x2 dark blocks)
	for center in [Vector2i(3, 3), Vector2i(12, 3), Vector2i(3, 12), Vector2i(12, 12)]:
		for dy in range(0, 2):
			for dx in range(0, 2):
				var px: int = center.x - 1 + dx
				var py: int = center.y - 1 + dy
				if px >= 0 and px < size and py >= 0 and py < size:
					img.set_pixel(px, py, motor if (dx + dy < 2) else motor_hi)

	return ImageTexture.create_from_image(img)


static func create_press_drone_rotors(frame: int) -> ImageTexture:
	## 16x16 rotor overlay for quadcopter. Alternates blade orientation.
	## frame 0: blades horizontal (—), frame 1: blades vertical (|)
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var blade := Color("#A0A8B8", 0.7)
	var blur := Color("#808898", 0.35)

	# Motor centers (same as body motor mounts)
	var centers := [Vector2i(3, 3), Vector2i(12, 3), Vector2i(3, 12), Vector2i(12, 12)]
	for c in centers:
		if frame == 0:
			# Horizontal blades: 5px wide line through motor
			for dx in range(-2, 3):
				var px: int = c.x + dx
				if px >= 0 and px < size:
					img.set_pixel(px, c.y, blade)
					# Blur above and below
					if c.y - 1 >= 0:
						img.set_pixel(px, c.y - 1, blur)
					if c.y + 1 < size:
						img.set_pixel(px, c.y + 1, blur)
		else:
			# Vertical blades: 5px tall line through motor
			for dy in range(-2, 3):
				var py: int = c.y + dy
				if py >= 0 and py < size:
					img.set_pixel(c.x, py, blade)
					# Blur left and right
					if c.x - 1 >= 0:
						img.set_pixel(c.x - 1, py, blur)
					if c.x + 1 < size:
						img.set_pixel(c.x + 1, py, blur)

	return ImageTexture.create_from_image(img)


static func create_news_helicopter() -> ImageTexture:
	## 16x16 helicopter body: fuselage, tail boom, cockpit window, skids.
	## Main rotor is a separate overlay — see create_news_helicopter_rotor().
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var body := Color("#505868")
	var body_hi := Color("#606878")
	var dark := Color("#383E48")
	var window := Color("#70B0D0")
	var window_hi := Color("#90D0E8")
	var tail := Color("#404850")
	var tail_dark := Color("#303840")
	var stripe := Color("#D04040")
	var hub := Color("#2A2A38")
	var skid := Color("#303038")

	# Fuselage: oval body, shaded (top-right lighter for top-down iso)
	for y in range(5, 12):
		var row_half: int = 4 if (y >= 7 and y <= 9) else (3 if (y >= 6 and y <= 10) else 2)
		for x in range(8 - row_half, 8 + row_half):
			var c := body_hi if (x >= 8 and y <= 8) else body
			if y == 5 or y == 11:
				c = dark  # Top/bottom edge darker
			img.set_pixel(x, y, c)

	# Cockpit windshield (front/right of fuselage)
	img.set_pixel(10, 7, window_hi)
	img.set_pixel(10, 8, window)
	img.set_pixel(11, 7, window_hi)
	img.set_pixel(11, 8, window)
	img.set_pixel(9, 7, window)

	# Stripe along fuselage side
	for x in range(5, 10):
		img.set_pixel(x, 10, stripe)

	# Tail boom (extends left from body)
	for x in range(1, 5):
		img.set_pixel(x, 8, tail)
		img.set_pixel(x, 9, tail_dark)

	# Tail fin
	img.set_pixel(1, 7, tail)
	img.set_pixel(1, 6, tail)
	img.set_pixel(0, 7, tail_dark)

	# Tail rotor disc (small horizontal blur at tail tip)
	img.set_pixel(0, 5, Color("#A0A8B8", 0.5))
	img.set_pixel(1, 5, Color("#A0A8B8", 0.5))
	img.set_pixel(2, 5, Color("#A0A8B8", 0.5))

	# Rotor hub on top of fuselage (dark dot)
	img.set_pixel(7, 7, hub)
	img.set_pixel(8, 7, hub)

	# Skids (landing gear, visible below fuselage)
	for x in range(5, 11):
		img.set_pixel(x, 13, skid)
	for x in range(6, 10):
		img.set_pixel(x, 12, skid)

	return ImageTexture.create_from_image(img)


static func create_news_helicopter_rotor(frame: int) -> ImageTexture:
	## 16x16 main rotor overlay for helicopter. 2-blade rotor in 2 orientations.
	## frame 0: diagonal NE-SW, frame 1: diagonal NW-SE
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var blade := Color("#B0B8C8", 0.6)
	var tip := Color("#C0C8D8", 0.8)
	var blur := Color("#808898", 0.25)

	# Rotor hub center at (7.5, 7) — between pixels 7 and 8
	var cx := 7
	var cy := 7

	if frame == 0:
		# Blade A: extends upper-right to lower-left
		for i in range(-6, 7):
			var px: int = cx + i
			var py: int = cy - (i / 2)
			if px >= 0 and px < size and py >= 0 and py < size:
				var c := tip if (abs(i) >= 5) else blade
				img.set_pixel(px, py, c)
				# Motion blur: adjacent pixels
				if py - 1 >= 0:
					img.set_pixel(px, py - 1, blur)
				if py + 1 < size:
					img.set_pixel(px, py + 1, blur)
	else:
		# Blade B: rotated ~90deg — extends upper-left to lower-right
		for i in range(-6, 7):
			var px: int = cx + i
			var py: int = cy + (i / 2)
			if px >= 0 and px < size and py >= 0 and py < size:
				var c := tip if (abs(i) >= 5) else blade
				img.set_pixel(px, py, c)
				if py - 1 >= 0:
					img.set_pixel(px, py - 1, blur)
				if py + 1 < size:
					img.set_pixel(px, py + 1, blur)

	return ImageTexture.create_from_image(img)


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
