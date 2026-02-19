class_name BuildingSprites
extends RefCounted
## Procedurally generates isometric building textures at runtime.
## Buildings are 3-face isometric boxes with windows, doors, and detail.

const TILE_W := 64
const TILE_H := 32


static func create_government_building() -> ImageTexture:
	# ~4 tiles wide, 2 tiles deep, ~80px tall — brutalist with columns
	var w := 192
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)

	var roof_color := Color("#585860")
	var wall_lit := Color("#484850")
	var wall_shadow := Color("#3A3A3E")
	var wall_dark := Color("#2E2E32")
	var window_lit := Color("#F0F0F0")   # Cool white glow
	var window_dark := Color("#1E1E22")
	var door_color := Color("#1A1A1E")
	var column_color := Color("#60606A")
	var step_color := Color("#484850")

	# Building dimensions in the image
	var bx := 16   # left margin
	var by := 8    # top margin for roof overhang
	var bw := 160  # building width
	var bh := 80   # building height (wall)
	var roof_h := 8

	# Draw the main building body
	# Right wall (lit side)
	for y in range(by + roof_h, by + roof_h + bh):
		for x in range(bx + bw / 2, bx + bw):
			var color := wall_lit
			# Subtle vertical gradient (darker at bottom)
			var t := float(y - by - roof_h) / bh
			color = color.darkened(t * 0.15)
			img.set_pixel(x, y, color)

	# Left wall (shadow side)
	for y in range(by + roof_h, by + roof_h + bh):
		for x in range(bx, bx + bw / 2):
			var color := wall_shadow
			var t := float(y - by - roof_h) / bh
			color = color.darkened(t * 0.15)
			img.set_pixel(x, y, color)

	# Roof (top face)
	for y in range(by, by + roof_h):
		for x in range(bx + 2, bx + bw - 2):
			img.set_pixel(x, y, roof_color)

	# Roof edge line
	for x in range(bx, bx + bw):
		if by + roof_h < h:
			img.set_pixel(x, by + roof_h, wall_dark)

	# Columns (vertical lighter strips across the front)
	var col_spacing := bw / 6
	for i in range(1, 6):
		var col_x := bx + i * col_spacing
		for y in range(by + roof_h + 4, by + roof_h + bh - 8):
			if col_x >= 0 and col_x < w:
				img.set_pixel(col_x, y, column_color)
				if col_x + 1 < w:
					img.set_pixel(col_x + 1, y, column_color)

	# Windows (small lit rectangles on wall faces)
	var win_rows := [by + roof_h + 12, by + roof_h + 28, by + roof_h + 44]
	var win_cols_right := []
	for i in range(3):
		win_cols_right.append(bx + bw / 2 + 12 + i * 20)
	var win_cols_left := []
	for i in range(3):
		win_cols_left.append(bx + 12 + i * 20)

	for wy in win_rows:
		for wx in win_cols_right + win_cols_left:
			# Each window is 6x4 pixels
			var is_lit := _hash2(wx, wy) % 3 != 0  # ~66% lit
			var wc: Color = window_lit if is_lit else window_dark
			for dy in range(4):
				for dx in range(6):
					var px: int = wx + dx
					var py: int = wy + dy
					if px >= 0 and px < w and py >= 0 and py < h:
						img.set_pixel(px, py, wc)

	# Main entrance door (center bottom)
	var door_x := bx + bw / 2 - 8
	var door_y := by + roof_h + bh - 16
	for dy in range(16):
		for dx in range(16):
			var px := door_x + dx
			var py := door_y + dy
			if px >= 0 and px < w and py >= 0 and py < h:
				img.set_pixel(px, py, door_color)
	# Door frame
	for dy in range(16):
		if door_x > 0 and door_y + dy < h:
			img.set_pixel(door_x, door_y + dy, column_color)
		if door_x + 15 < w and door_y + dy < h:
			img.set_pixel(door_x + 15, door_y + dy, column_color)

	# Steps below entrance
	for step in range(3):
		var sy := by + roof_h + bh + step * 2
		var sx := door_x - 2 - step * 2
		var sw := 20 + step * 4
		for dx in range(sw):
			for dy in range(2):
				var px := sx + dx
				var py := sy + dy
				if px >= 0 and px < w and py >= 0 and py < h:
					img.set_pixel(px, py, step_color.darkened(step * 0.08))

	return ImageTexture.create_from_image(img)


static func create_guard_booth() -> ImageTexture:
	# 1x1 tile, ~24px tall — dark metal box with slit window
	var w := 32
	var h := 40
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)

	var wall_color := Color("#3A3A3E")
	var roof_color := Color("#484850")
	var slit_color := Color("#C8A040")

	# Box body
	for y in range(8, 36):
		for x in range(4, 28):
			var color := wall_color
			if x < 16:
				color = color.darkened(0.12)
			img.set_pixel(x, y, color)

	# Roof
	for y in range(4, 8):
		for x in range(2, 30):
			img.set_pixel(x, y, roof_color)

	# Slit window
	for x in range(8, 24):
		for y in range(14, 17):
			img.set_pixel(x, y, slit_color)

	return ImageTexture.create_from_image(img)


static func create_apartment_block() -> ImageTexture:
	# 2x1 tiles, ~48px tall
	var w := 64
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)

	var wall_lit := Color("#404048")
	var wall_dark := Color("#32323A")
	var roof_color := Color("#484850")
	var window_lit := Color("#F0F0F0")
	var window_dark := Color("#1E1E22")

	# Walls
	for y in range(6, 56):
		for x in range(2, 62):
			var color: Color = wall_lit if x >= 32 else wall_dark
			var t := float(y - 6) / 50.0
			color = color.darkened(t * 0.1)
			img.set_pixel(x, y, color)

	# Roof
	for y in range(2, 6):
		for x in range(0, 64):
			img.set_pixel(x, y, roof_color)

	# Windows — grid pattern
	for row in range(4):
		for col in range(5):
			var wx := 6 + col * 11
			var wy := 10 + row * 11
			var is_lit := _hash2(wx + col, wy + row) % 4 != 0
			var wc: Color = window_lit if is_lit else window_dark
			for dy in range(4):
				for dx in range(5):
					var px: int = wx + dx
					var py: int = wy + dy
					if px < w and py < h:
						img.set_pixel(px, py, wc)

	return ImageTexture.create_from_image(img)


static func create_wall_segment() -> ImageTexture:
	# 1 tile wide, ~16px tall — concrete wall with optional chain-link on top
	var w := 32
	var h := 24
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)

	var wall_color := Color("#3A3A3E")
	var fence_color := Color("#585860")

	# Wall body
	for y in range(8, 22):
		for x in range(2, 30):
			var color := wall_color
			if x < 16:
				color = color.darkened(0.08)
			# Surface noise
			var h_val := _hash2(x, y)
			if h_val % 11 == 0:
				color = color.lightened(0.05)
			img.set_pixel(x, y, color)

	# Chain-link fence top (cross-hatch pattern)
	for y in range(4, 8):
		for x in range(2, 30):
			if (x + y) % 3 == 0:
				img.set_pixel(x, y, fence_color)

	# Fence posts
	for x in [2, 15, 29]:
		for y in range(2, 10):
			if x < w and y < h:
				img.set_pixel(x, y, fence_color)

	return ImageTexture.create_from_image(img)


static func _hash2(a: int, b: int) -> int:
	var v := (a * 73856093 + b * 19349663) & 0xFFFFFF
	return absi(v)
