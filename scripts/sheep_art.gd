class_name SheepArt
extends RefCounted
## Placeholder pixel art, drawn in code so the project needs no image files.
## To use real sprites later, return your own textures from frames() and
## wool_texture() and delete the drawing helpers.

const W := 32
const H := 24

static var _cache: Dictionary = {}
static var _wool_tex: ImageTexture


## Two walk-cycle textures for the given state: [frame0, frame1].
static func frames(sheared: bool) -> Array:
	if not _cache.has(sheared):
		var arr: Array = []
		for f in 2:
			arr.append(ImageTexture.create_from_image(_draw_sheep(sheared, f)))
		_cache[sheared] = arr
	return _cache[sheared]


static func wool_texture() -> ImageTexture:
	if _wool_tex == null:
		var img := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
		_ellipse(img, 4, 4, 3, 3, Color("f4f1ea"))
		_ellipse(img, 3, 3, 1, 1, Color.WHITE)
		_wool_tex = ImageTexture.create_from_image(img)
	return _wool_tex


static func _draw_sheep(sheared: bool, frame: int) -> Image:
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var bob := -1 if frame == 1 else 0

	var wool := Color("f4f1ea")
	var wool_shade := Color("d9d4c7")
	var skin := Color("f2b8a2")
	var skin_shade := Color("d99a86")
	var dark := Color("3b3b44")

	# Legs first (behind the body). The two diagonal pairs swap reach each frame.
	var reach_a := 6 if frame == 0 else 4
	var reach_b := 4 if frame == 0 else 6
	_rect(img, 9, 15 + bob, 2, reach_a, dark)
	_rect(img, 19, 15 + bob, 2, reach_a, dark)
	_rect(img, 13, 15 + bob, 2, reach_b, dark)
	_rect(img, 23, 15 + bob, 2, reach_b, dark)

	# Body
	if sheared:
		_ellipse(img, 15, 12 + bob, 9, 5, skin)
		_ellipse(img, 15, 14 + bob, 8, 3, skin_shade)
		_ellipse(img, 14, 8 + bob, 3, 2, wool) # a leftover tuft
	else:
		_ellipse(img, 15, 11 + bob, 12, 8, wool)
		_ellipse(img, 15, 15 + bob, 10, 3, wool_shade)
		_ellipse(img, 7, 7 + bob, 4, 3, wool)
		_ellipse(img, 15, 4 + bob, 5, 3, wool)
		_ellipse(img, 23, 7 + bob, 4, 3, wool)

	# Head (faces right; Sprite2D.flip_h handles the other direction)
	_ellipse(img, 27, 10 + bob, 4, 4, dark)
	_rect(img, 24, 6 + bob, 2, 2, dark) # ear
	_px(img, 28, 9 + bob, Color.WHITE) # eye
	if not sheared:
		_ellipse(img, 26, 6 + bob, 3, 2, wool) # fluffy fringe

	return img


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


static func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	for yy in range(cy - ry, cy + ry + 1):
		for xx in range(cx - rx, cx + rx + 1):
			var dx := float(xx - cx) / float(rx)
			var dy := float(yy - cy) / float(ry)
			if dx * dx + dy * dy <= 1.0:
				_px(img, xx, yy, c)
