extends FixStep
## Drag nails from the box onto the marked spots, then press and hold a nail
## to charge the hammer and let go to swing. Bigger charge = deeper nail.

@export var nail_texture: Texture2D = preload("res://assets/sprites/nail.png")
@export var hammer_texture: Texture2D = preload("res://assets/sprites/hammer.png")
@export var box_texture: Texture2D = preload("res://assets/sprites/nail_box.png")
## Rows of nail_texture that make the head (always visible).
@export var nail_head_px := 3
## Point on hammer_texture used as the swing pivot (end of the handle).
@export var hammer_pivot := Vector2(64, 12)
## Hammer-head centre, measured from the pivot, in texture pixels.
@export var hammer_head_offset := Vector2(-56, 0)
## Seconds of holding to reach full charge.
@export var charge_time := 0.7
## How far one hit drives the nail: from a quick tap to a full charge.
@export var min_drive := 0.34
@export var max_drive := 1.0
@export var snap_distance := 90.0

const RAISED := 1.15 # hammer rotation when fully charged
const REST := 0.35

var _slots: Array[Rect2] = []
var _spots: Array[Dictionary] = [] # {pos, placed, depth, sprite}
var _box: Sprite2D
var _hammer: Sprite2D
var _drag_nail: Sprite2D
var _charging := -1
var _charge := 0.0
var _swinging := false
var _charge_player: AudioStreamPlayer
var _t := 0.0
var _boards_root: Node2D


func begin() -> void:
	super.begin()
	title = "Hammer the nails!"
	_slots = slot_rects(Vector2(size.x * 0.62, size.y * 0.6))
	_boards_root = Node2D.new()
	add_child(_boards_root)
	for r in _slots:
		var b := make_board()
		b.position = r.get_center()
		_boards_root.add_child(b)
		var n := nails_per_board()
		for k in n:
			var fx := 0.12 + 0.76 * (float(k) / float(maxi(n - 1, 1))) if n > 1 else 0.5
			_spots.append({"pos": Vector2(r.position.x + r.size.x * fx, r.get_center().y), "placed": false, "depth": 0.0, "sprite": null})

	_box = Sprite2D.new()
	_box.texture = box_texture
	_box.scale = Vector2.ONE * art_scale
	_box.position = Vector2(size.x * 0.13, size.y * 0.55)
	add_child(_box)

	_hammer = Sprite2D.new()
	_hammer.texture = hammer_texture
	_hammer.centered = false
	_hammer.offset = -hammer_pivot
	_hammer.scale = Vector2.ONE * art_scale
	_hammer.visible = false
	add_child(_hammer)
	move_child(top, -1)


# --- nail sprites --------------------------------------------------------

func _make_nail() -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = nail_texture
	s.centered = false
	s.region_enabled = true
	s.scale = Vector2.ONE * art_scale
	_set_nail_depth(s, 0.0)
	return s


## Shows the head plus however much shaft is still sticking out.
## The sprite's origin is where the nail enters the wood.
func _set_nail_depth(s: Sprite2D, depth: float) -> void:
	var shaft := nail_texture.get_height() - nail_head_px
	var visible_h := nail_head_px + roundi(shaft * (1.0 - clampf(depth, 0.0, 1.0)))
	s.region_rect = Rect2(0, 0, nail_texture.get_width(), visible_h)
	s.offset = Vector2(-nail_texture.get_width() / 2.0, -visible_h + 1)


func _nail_top(spot: Dictionary) -> Vector2:
	var shaft := nail_texture.get_height() - nail_head_px
	var visible_h := nail_head_px + roundi(shaft * (1.0 - spot.depth))
	return spot.pos - Vector2(0, (visible_h - 1) * art_scale)


# --- input ---------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(event.position)
		else:
			_release(event.position)
	elif event is InputEventMouseMotion and _drag_nail:
		_drag_nail.position = event.position + Vector2(0, -30)


func _press(p: Vector2) -> void:
	if _swinging:
		return
	# hold a placed nail -> charge the hammer
	var i := _nail_under(p)
	if i >= 0:
		_start_charge(i)
		return
	# grab a nail from the box
	var box_rect := Rect2(_box.position - _box.texture.get_size() * art_scale / 2.0, _box.texture.get_size() * art_scale).grow(20.0)
	if box_rect.has_point(p) and _next_free_spot() >= 0:
		_drag_nail = _make_nail()
		_drag_nail.position = p + Vector2(0, -30)
		add_child(_drag_nail)
		move_child(top, -1)
		Sfx.play(&"pickup")


func _release(_p: Vector2) -> void:
	if _drag_nail:
		_drop_nail()
	elif _charging >= 0:
		_swing()


func _nail_under(p: Vector2) -> int:
	for i in _spots.size():
		var s: Dictionary = _spots[i]
		if not s.placed or s.depth >= 1.0:
			continue
		var top_y: float = _nail_top(s).y
		if absf(p.x - s.pos.x) < 70.0 and p.y > top_y - 70.0 and p.y < s.pos.y + 50.0:
			return i
	return -1


func _next_free_spot() -> int:
	for i in _spots.size():
		if not _spots[i].placed:
			return i
	return -1


func _drop_nail() -> void:
	var n := _drag_nail
	_drag_nail = null
	var best := -1
	var best_d := snap_distance
	for i in _spots.size():
		if _spots[i].placed:
			continue
		var d := n.position.distance_to(_spots[i].pos)
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		_spots[best].placed = true
		_spots[best].sprite = n
		var tw := create_tween()
		tw.tween_property(n, "position", _spots[best].pos, 0.08)
		await tw.finished
		Sfx.play(&"place", 1.8, -6.0)
	else:
		Sfx.play(&"drop")
		var tw := create_tween()
		tw.tween_property(n, "modulate:a", 0.0, 0.2)
		tw.tween_callback(n.queue_free)


# --- hammer --------------------------------------------------------------

func _start_charge(i: int) -> void:
	_charging = i
	_charge = 0.0
	_hammer.visible = true
	_hammer.modulate.a = 1.0
	_place_hammer(i)
	_hammer.rotation = REST
	_charge_player = Sfx.play(&"charge", 1.0, -6.0, false)


func _place_hammer(i: int) -> void:
	var head := _nail_top(_spots[i])
	var head_half_h := hammer_texture.get_height() / 2.0
	_hammer.position = head - (hammer_head_offset + Vector2(0, head_half_h)) * art_scale


func _swing() -> void:
	var i := _charging
	_charging = -1
	_swinging = true
	if _charge_player:
		_charge_player.stop()
	var power := _charge
	var tw := create_tween()
	tw.tween_property(_hammer, "rotation", 0.0, 0.07).set_ease(Tween.EASE_IN)
	await tw.finished
	var s: Dictionary = _spots[i]
	s.depth = minf(s.depth + lerpf(min_drive, max_drive, power), 1.0)
	_set_nail_depth(s.sprite, s.depth)
	Sfx.play(&"hammer_hit", lerpf(1.15, 0.85, power))
	_shake(4.0 + power * 10.0)
	if s.depth >= 1.0:
		Sfx.play(&"nail_done")
		_sparkle(s.pos)
	var back := create_tween()
	back.tween_property(_hammer, "rotation", REST, 0.12)
	back.tween_property(_hammer, "modulate:a", 0.0, 0.15)
	await back.finished
	_hammer.visible = false
	_swinging = false
	if _all_done():
		finish(0.5)


func _all_done() -> bool:
	for s in _spots:
		if s.depth < 1.0:
			return false
	return true


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	if _charging >= 0:
		_charge = minf(_charge + delta / charge_time, 1.0)
		_hammer.rotation = lerpf(REST, RAISED, _charge) + (sin(_t * 40.0) * 0.03 if _charge >= 1.0 else 0.0)


func _shake(amount: float) -> void:
	var tw := create_tween()
	for k in 4:
		tw.tween_property(_boards_root, "position", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amount, 0.03)
	tw.tween_property(_boards_root, "position", Vector2.ZERO, 0.03)


func _sparkle(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 240.0
	p.gravity = Vector2.ZERO
	p.damping_min = 300.0
	p.damping_max = 400.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 7.0
	p.color = Color(1, 0.95, 0.4)
	p.position = at
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


# --- drawing -------------------------------------------------------------

func _draw_under() -> void:
	draw_frame(under, _slots)


func _draw_top() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	var any_placed := false
	for s in _spots:
		if not s.placed:
			# target ring for an empty spot
			top.draw_arc(s.pos, 18.0 + pulse * 4.0, 0, TAU, 24, Color(1, 1, 0.5, 0.9), 4.0)
			top.draw_circle(s.pos, 5.0, Color(0.2, 0.1, 0.05, 0.8))
		elif s.depth < 1.0:
			any_placed = true
	# charge ring around the nail being hammered
	if _charging >= 0:
		var c := _nail_top(_spots[_charging]) + Vector2(0, 30)
		top.draw_arc(c, 46.0, 0, TAU, 40, Color(0, 0, 0, 0.3), 10.0)
		var col := Color(1, 0.85, 0.2).lerp(Color(1, 0.3, 0.2), _charge)
		top.draw_arc(c, 46.0, -PI / 2.0, -PI / 2.0 + TAU * _charge, 40, col, 10.0)
	# hints
	if _drag_nail or _charging >= 0 or _swinging:
		return
	var free_i := _next_free_spot()
	if not any_placed and free_i >= 0:
		# drag from box to spot
		var from := _box.position + Vector2(0, -60)
		var to: Vector2 = _spots[free_i].pos
		var k := fmod(_t, 1.4) / 1.4
		draw_arrow(top, from, from.lerp(to - (to - from).normalized() * 30.0, k), Color(1, 1, 1, 0.8), 10.0)
	elif any_placed:
		# press-and-hold hint over the first standing nail
		for s in _spots:
			if s.placed and s.depth < 1.0:
				var c := _nail_top(s) + Vector2(0, 20)
				var ring := fmod(_t, 1.0)
				top.draw_arc(c, 20.0 + ring * 40.0, 0, TAU, 32, Color(1, 1, 1, 1.0 - ring), 5.0)
				break
