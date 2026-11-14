extends FixStep
## Drag the cut boards from the pile into the outlined spots on the frame.

## How close (px) a dropped board must be to a slot to snap in.
@export var snap_distance := 150.0

var _slots: Array[Rect2] = []
var _filled: Array[bool] = []
var _boards: Array[Sprite2D] = []
var _homes: Array[Vector2] = []
var _home_rot: Array[float] = []
var _placed: Array[bool] = []
var _held := -1
var _grab_offset := Vector2.ZERO
var _t := 0.0
var _placed_count := 0


func begin() -> void:
	super.begin()
	title = "Put the boards on!"
	_slots = slot_rects(Vector2(size.x * 0.66, size.y * 0.5))
	var n := _slots.size()
	_filled.resize(n)
	_filled.fill(false)
	var bs := board_size()
	for i in n:
		var b := make_board()
		var home := Vector2(size.x * 0.2, size.y * 0.5 + (i - (n - 1) / 2.0) * (bs.y + 26.0))
		var rot := randf_range(-0.08, 0.08)
		b.position = home
		b.rotation = rot
		add_child(b)
		_boards.append(b)
		_homes.append(home)
		_home_rot.append(rot)
		_placed.append(false)


func _board_hit(i: int, p: Vector2) -> bool:
	var bs := board_size() * _boards[i].scale / art_scale
	return Rect2(_boards[i].position - bs / 2.0, bs).grow(16.0).has_point(p)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			for i in range(_boards.size() - 1, -1, -1):
				if not _placed[i] and _board_hit(i, event.position):
					_pick(i, event.position)
					break
		elif _held >= 0:
			_drop(event.position)
	elif event is InputEventMouseMotion and _held >= 0:
		_boards[_held].position = event.position + _grab_offset


func _pick(i: int, p: Vector2) -> void:
	_held = i
	var b := _boards[i]
	_grab_offset = b.position - p
	move_child(b, -1)
	move_child(top, -1)
	Sfx.play(&"pickup")
	var tw := create_tween().set_parallel()
	tw.tween_property(b, "scale", Vector2.ONE * art_scale * 1.06, 0.1)
	tw.tween_property(b, "rotation", 0.0, 0.1)


func _drop(p: Vector2) -> void:
	var i := _held
	_held = -1
	var b := _boards[i]
	var best := -1
	var best_d := snap_distance
	for s in _slots.size():
		if _filled[s]:
			continue
		var d := b.position.distance_to(_slots[s].get_center())
		if d < best_d:
			best_d = d
			best = s
	var tw := create_tween().set_parallel()
	tw.tween_property(b, "scale", Vector2.ONE * art_scale, 0.12)
	if best >= 0:
		_filled[best] = true
		_placed[i] = true
		_placed_count += 1
		tw.tween_property(b, "position", _slots[best].get_center(), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "rotation", 0.0, 0.12)
		await tw.finished
		Sfx.play(&"place")
		if _placed_count >= _boards.size():
			finish(0.5)
	else:
		Sfx.play(&"drop")
		tw.tween_property(b, "position", _homes[i], 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "rotation", _home_rot[i], 0.3)


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta


func _draw_under() -> void:
	draw_frame(under, _slots)
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	for s in _slots.size():
		if _filled[s]:
			continue
		var r := _slots[s]
		under.draw_rect(r, Color(1, 1, 1, 0.15 + 0.2 * pulse))
		# dashed outline
		var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
		for k in 4:
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[k + 1]
			var seg_len := a.distance_to(b)
			var dist := 0.0
			while dist < seg_len:
				under.draw_line(a.lerp(b, dist / seg_len), a.lerp(b, minf(dist + 14.0, seg_len) / seg_len), Color(1, 1, 0.6, 0.9), 4.0)
				dist += 24.0


func _draw_top() -> void:
	# hint: arrow from first loose board to first empty slot, until one is placed
	if _placed_count > 0 or _held >= 0 or _t < 1.0:
		return
	var from := _homes[0] + Vector2(board_size().x / 2.0 + 10.0, 0)
	var to := _slots[0].get_center() - Vector2(board_size().x / 2.0 + 10.0, 0)
	var k := fmod(_t, 1.4) / 1.4
	draw_arrow(top, from, from.lerp(to, k), Color(1, 1, 1, 0.8 * (1.0 - k * 0.5)), 10.0)
