class_name RubSurface
extends Sprite2D
## A surface that changes look where it's rubbed (sanding, painting...).
##
## Keeps a coverage mask with one pixel per texture pixel (0 = untouched,
## 1 = done). The rub_surface shader blends the before and after looks by it.
## Call rub() with screen-space finger movement; read coverage() for progress.

const SHADER := preload("res://shaders/rub_surface.gdshader")
## Mask value that counts a pixel as done.
const DONE_AT := 0.8

var mat: ShaderMaterial
var _mask: Image
var _mask_tex: ImageTexture
var _dirty := false
var _opaque := PackedByteArray() # 1 where the texture is visible
var _opaque_count := 0
var _done_count := 0


## `region` crops the source (e.g. a cut board); empty = whole texture.
func setup(source: Texture2D, region := Rect2i()) -> void:
	var img := source.get_image()
	if img.is_compressed():
		img.decompress()
	if region.has_area():
		img = img.get_region(region)
	img.convert(Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(img)
	var w := img.get_width()
	var h := img.get_height()
	_mask = Image.create(w, h, false, Image.FORMAT_L8)
	_mask_tex = ImageTexture.create_from_image(_mask)
	_opaque.resize(w * h)
	_opaque_count = 0
	for y in h:
		for x in w:
			var o := img.get_pixel(x, y).a > 0.5
			_opaque[y * w + x] = 1 if o else 0
			_opaque_count += 1 if o else 0
	_done_count = 0
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"mask_tex", _mask_tex)
	mat.set_shader_parameter(&"fill", 0.0)
	material = mat


## Rubs a soft brush along a screen-space segment. `radius` is in screen px.
## `amount` is how much one full pass over a pixel adds (1 = covered in one go).
func rub(from: Vector2, to: Vector2, radius: float, amount: float) -> void:
	var a := _to_texel(from)
	var b := _to_texel(to)
	var r := radius / absf(global_scale.x) # texels
	var w := _mask.get_width()
	var h := _mask.get_height()
	var dist := a.distance_to(b)
	var spacing := maxf(r * 0.35, 0.5)
	var stamps := maxi(ceili(dist / spacing), 1)
	# each pixel under the path gets hit by ~2r/spacing stamps; scale so a
	# whole pass adds `amount`
	var per := amount * (dist / stamps) / (2.0 * r) if dist > 0.0 else amount * 0.05
	for i in stamps + 1:
		var c := a.lerp(b, float(i) / stamps)
		var x0 := maxi(floori(c.x - r), 0)
		var x1 := mini(ceili(c.x + r), w - 1)
		var y0 := maxi(floori(c.y - r), 0)
		var y1 := mini(ceili(c.y + r), h - 1)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / r
				if d > 1.0 or _opaque[y * w + x] == 0:
					continue
				var old := _mask.get_pixel(x, y).r
				if old >= 1.0:
					continue
				var v := minf(old + per * (1.0 - d * d * 0.6), 1.0)
				_mask.set_pixel(x, y, Color(v, v, v))
				if old < DONE_AT and v >= DONE_AT:
					_done_count += 1
				_dirty = true


## True if the screen point is on (or within `pad` px of) this surface.
func hits(p: Vector2, pad := 0.0) -> bool:
	var t := _to_texel(p)
	var s := texture.get_size()
	var pd := pad / absf(global_scale.x)
	return t.x >= -pd and t.y >= -pd and t.x <= s.x + pd and t.y <= s.y + pd


func coverage() -> float:
	return float(_done_count) / maxf(_opaque_count, 1.0)


func done_count() -> int:
	return _done_count


func opaque_count() -> int:
	return _opaque_count


## Fades the rest of the surface to done.
func fill_rest(time := 0.35) -> Tween:
	var tw := create_tween()
	tw.tween_property(mat, "shader_parameter/fill", 1.0, time)
	return tw


func _to_texel(screen: Vector2) -> Vector2:
	var local := get_global_transform_with_canvas().affine_inverse() * screen
	if centered:
		local += texture.get_size() / 2.0
	return local - offset


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_mask_tex.update(_mask)
