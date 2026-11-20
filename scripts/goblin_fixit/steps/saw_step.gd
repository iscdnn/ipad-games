extends FixStep
## Saw boards to size: drag back and forth anywhere to move the saw.

@export var saw_texture: Texture2D = preload("res://assets/sprites/saw.png")
## Point on saw_texture (pixels) that sits on the cut line: middle of the teeth.
@export var saw_tooth_point := Vector2(23, 36)
## Total finger travel (px) needed to cut through one board.
@export var cut_distance := 1300.0
## How far the saw can slide either side of the cut line.
@export var slide_range := 110.0
## Drag speed (px/s) mapped to saw sound pitch: slow -> pitch_range.x, fast -> .y.
@export var pitch_speed := Vector2(200.0, 1500.0)
@export var pitch_range := Vector2(0.85, 1.25)
## Finger must travel this far backwards before the sound switches direction
## (ignores tiny jitter).
@export var reverse_px := 4.0

var _boards_cut := 0
var _progress := 0.0
var _slide := 0.0
var _dragging := false
var _last_x := 0.0
var _dir := 0
var _busy := true
var _moved_t := 1.0
var _t := 0.0
var _rev := 0.0
var _frame_moved := 0.0
var _speed := 0.0

var _push_sfx: LoopSfx
var _pull_sfx: LoopSfx

var _keep: Sprite2D
var _offcut: Sprite2D
var _kerf: ColorRect
var _saw: Sprite2D
var _dust: CPUParticles2D
var _pile: Array[Sprite2D] = []

var _board_center: Vector2
var _cut_x := 0.0
var _board_top := 0.0


func begin() -> void:
	super.begin()
	title = "Saw the boards!"
	var full_w := board_texture.get_width() * art_scale
	var h := board_texture.get_height() * art_scale
	_board_center = pr(0.5, 0.62)
	var left := _board_center.x - full_w / 2.0
	_cut_x = left + board_keep_px * art_scale
	_board_top = _board_center.y - h / 2.0

	_keep = make_board()
	add_child(_keep)
	_offcut = Sprite2D.new()
	_offcut.texture = board_texture
	_offcut.region_enabled = true
	_offcut.region_rect = Rect2(board_keep_px, 0, board_texture.get_width() - board_keep_px, board_texture.get_height())
	_offcut.scale = Vector2.ONE * art_scale
	add_child(_offcut)

	_kerf = ColorRect.new()
	_kerf.color = Color(0.25, 0.15, 0.08)
	_kerf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_kerf)

	_dust = CPUParticles2D.new()
	_dust.amount = 30
	_dust.lifetime = 0.6
	_dust.emitting = false
	_dust.direction = Vector2(0, 1)
	_dust.spread = 50.0
	_dust.initial_velocity_min = 60.0
	_dust.initial_velocity_max = 160.0
	_dust.gravity = Vector2(0, 500)
	_dust.scale_amount_min = 3.0
	_dust.scale_amount_max = 6.0
	_dust.color = Color(0.95, 0.85, 0.6)
	add_child(_dust)

	_saw = Sprite2D.new()
	_saw.texture = saw_texture
	_saw.centered = false
	_saw.offset = -saw_tooth_point
	_saw.scale = Vector2.ONE * art_scale
	add_child(_saw)

	_push_sfx = _make_loop(&"saw_push")
	_pull_sfx = _make_loop(&"saw_pull")

	_new_board(false)


func _make_loop(sound_name: StringName) -> LoopSfx:
	var p := LoopSfx.new()
	p.stream = Sfx.stream(sound_name)
	add_child(p)
	return p


func _release_sfx() -> void:
	_push_sfx.release()
	_pull_sfx.release()
	_dir = 0


func _new_board(animate := true) -> void:
	_progress = 0.0
	_slide = 0.0
	var left := _board_center.x - board_texture.get_width() * art_scale / 2.0
	var keep_pos := Vector2(left + board_keep_px * art_scale / 2.0, _board_center.y)
	var off_w := (board_texture.get_width() - board_keep_px) * art_scale
	var off_pos := Vector2(_cut_x + off_w / 2.0, _board_center.y)
	_offcut.rotation = 0.0
	_offcut.modulate.a = 1.0
	_keep.modulate.a = 1.0
	_keep.scale = Vector2.ONE * art_scale
	_update_visuals()
	if animate:
		var shift := Vector2(-panel_rect.size.x, 0)
		_keep.position = keep_pos + shift
		_offcut.position = off_pos + shift
		_saw.modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(_keep, "position", keep_pos, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_offcut, "position", off_pos, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_saw, "modulate:a", 1.0, 0.3).set_delay(0.3)
		await tw.finished
	else:
		_keep.position = keep_pos
		_offcut.position = off_pos
	_busy = false


func _update_visuals() -> void:
	var depth := _progress * board_texture.get_height() * art_scale
	_kerf.position = Vector2(_cut_x - 3.0, _board_top)
	_kerf.size = Vector2(6.0, depth)
	_saw.position = Vector2(_cut_x + _slide, _board_top + depth)
	_saw.rotation = -0.12
	_dust.position = Vector2(_cut_x, _board_top + depth + 6.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_last_x = event.position.x
		if not _dragging:
			_release_sfx()
	elif event is InputEventMouseMotion and _dragging and not _busy:
		var dx: float = event.position.x - _last_x
		_last_x = event.position.x
		var before := _slide
		_slide = clampf(_slide + dx, -slide_range, slide_range)
		var moved := absf(_slide - before)
		if moved <= 0.0:
			return
		var d := signi(int(signf(_slide - before)))
		_frame_moved += moved
		_saw_sound(d, moved)
		_moved_t = 0.0
		_progress = minf(_progress + moved / cut_distance, 1.0)
		_update_visuals()
		if _progress >= 1.0:
			_cut_done()


## Push and pull each have a looping player. Changing direction fades the
## other one out and starts this one from its attack; pausing lets LoopSfx
## fade it out on its own.
func _saw_sound(d: int, moved: float) -> void:
	if d != _dir and _dir != 0:
		_rev += moved
		if _rev < reverse_px:
			_current_sfx().keep_alive(_pitch())
			return
	_rev = 0.0
	var pitch := _pitch()
	if d != _dir:
		_dir = d
		_other_sfx().release()
		_current_sfx().start(pitch)
	else:
		_current_sfx().keep_alive(pitch)


func _current_sfx() -> LoopSfx:
	return _push_sfx if _dir > 0 else _pull_sfx


func _other_sfx() -> LoopSfx:
	return _pull_sfx if _dir > 0 else _push_sfx


func _pitch() -> float:
	var w := clampf(inverse_lerp(pitch_speed.x, pitch_speed.y, _speed), 0.0, 1.0)
	return lerpf(pitch_range.x, pitch_range.y, w)


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	_moved_t += delta
	if delta > 0.0:
		_speed = lerpf(_speed, _frame_moved / delta, 1.0 - exp(-10.0 * delta))
	_frame_moved = 0.0
	if _dust:
		_dust.emitting = _moved_t < 0.12 and not _busy


func _cut_done() -> void:
	_busy = true
	_dragging = false
	_release_sfx()
	Sfx.play(&"cut_done")
	var tw := create_tween().set_parallel()
	tw.tween_property(_offcut, "position", _offcut.position + Vector2(80, 360), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_offcut, "rotation", 1.2, 0.7)
	tw.tween_property(_offcut, "modulate:a", 0.0, 0.7)
	tw.tween_property(_saw, "modulate:a", 0.0, 0.25)
	# cut board flies to the pile in the top corner
	var pile_board := make_board()
	pile_board.position = _keep.position
	add_child(pile_board)
	_keep.modulate.a = 0.0
	var pile_pos := Vector2(panel_rect.end.x - 120.0, panel_rect.position.y + 30.0 + _pile.size() * 40.0)
	_pile.append(pile_board)
	tw.tween_property(pile_board, "position", pile_pos, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pile_board, "scale", Vector2.ONE * art_scale * 0.6, 0.5)
	await tw.finished
	Sfx.play(&"place", 1.3, -4.0)
	_boards_cut += 1
	if _boards_cut >= board_count():
		finish(0.4)
	else:
		_new_board()


func _draw_under() -> void:
	# sawhorses under the board
	var wood := Color(0.55, 0.38, 0.22)
	var y := _board_center.y + board_texture.get_height() * art_scale / 2.0
	for x in [_board_center.x - 170.0, _board_center.x + 150.0]:
		under.draw_rect(Rect2(x - 40.0, y, 80.0, 14.0), wood)
		under.draw_line(Vector2(x - 30.0, y + 14.0), Vector2(x - 50.0, y + 120.0), wood, 10.0)
		under.draw_line(Vector2(x + 30.0, y + 14.0), Vector2(x + 50.0, y + 120.0), wood, 10.0)


func _draw_top() -> void:
	if _busy:
		return
	# dashed cut line
	var h := board_texture.get_height() * art_scale
	var y := _board_top + _progress * h
	while y < _board_top + h:
		top.draw_line(Vector2(_cut_x, y), Vector2(_cut_x, minf(y + 8.0, _board_top + h)), Color(0.15, 0.1, 0.4), 3.0)
		y += 14.0
	# back-and-forth hint until the first board is started
	if _boards_cut == 0 and _progress < 0.08:
		var bob := sin(_t * 5.0) * 30.0
		var c := Vector2(_cut_x + bob, _board_top - 150.0)
		draw_arrow(top, c - Vector2(90, 0), c + Vector2(90, 0), Color(1, 1, 1, 0.85), 10.0, true)
