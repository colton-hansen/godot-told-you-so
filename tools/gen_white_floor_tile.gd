extends SceneTree
## Rewrite kitchen white vinyl 16² — keep grout/noise, push the fill toward white.


func _init() -> void:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	for y in 16:
		for x in 16:
			if x == 0 or y == 0:
				var d := int(_h01(x, y, 3) * 10.0)
				img.set_pixel(x, y, _rgb(198 + d, 198 + d, 196 + d))
				continue
			var n := _h01(x, y, 11)
			var v := int((n - 0.5) * 8.0)
			var r := 248 + v
			var g := 248 + v * 3 / 4
			var b := 246 + v / 2
			if _h01(x, y, 28) > 0.92:
				r -= 8
				g -= 8
				b -= 6
			if _h01(x, y, 41) < 0.06:
				r += 6
				g += 6
				b += 5
			if x == 1 or y == 1:
				r += 4
				g += 4
				b += 3
			img.set_pixel(x, y, _rgb(r, g, b))
	_blob(img, 4, 10, 3, -8, -8, -6)
	_blob(img, 11, 5, 2, -6, -6, -4)
	var path := "res://assets/textures/kitchen_procedural/floor_check_white_16.png"
	img.save_png(path)
	print("wrote ", path)
	quit()


func _rgb(r: int, g: int, b: int) -> Color:
	return Color8(clampi(r, 0, 255), clampi(g, 0, 255), clampi(b, 0, 255))


func _h01(x: int, y: int, salt: int) -> float:
	var n := x * 374761393 + y * 668265263 + salt * 1274126177
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0x7fffffff) / 2147483647.0


func _blob(img: Image, cx: int, cy: int, rad: int, dr: int, dg: int, db: int) -> void:
	for y in range(cy - rad, cy + rad + 1):
		for x in range(cx - rad, cx + rad + 1):
			if x < 1 or y < 1 or x > 15 or y > 15:
				continue
			if Vector2(x - cx, y - cy).length() > float(rad) + 0.2:
				continue
			var c := img.get_pixel(x, y)
			img.set_pixel(
				x,
				y,
				_rgb(int(c.r * 255.0) + dr, int(c.g * 255.0) + dg, int(c.b * 255.0) + db)
			)
