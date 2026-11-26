extends FixStep
## Saw boards to size. Slow dragging moves the saw with the finger and only
## grinds a little; a quick swipe triggers a full stroke that runs on its own
## (stroke_time) with its SFX, so cutting has a rhythm to match.

@export var saw_texture: Texture2D = preload("res://assets/sprites/saw.png")
## Point on saw_texture (pixels) that sits on the cut line: middle of the teeth.
@export var saw_tooth_point := Vector2(23, 36)
## How far the saw can slide either side of the cut line.
@export var slide_range := 110.0

@export_group("Cutting")
## Cut needed to get through one board.
@export var board_cut := 100.0
## Cut from one full stroke (end to end). A stroke started part-way across
## cuts the remaining fraction of this.
@export var cut_per_stroke := 12.5
## Scales every cut amount (lower = tougher board). For harder boards later.
@export var cut_multiplier := 1.0
## Cut per px of slow back-and-forth dragging (grinding).
@export var grind_per_px := 0.01

@export_group("Strokes")
## Time a stroke takes, so the stroke SFX plays properly.
@export var stroke_time := 0.3
## A stroke triggers when the finger travels this far one way...
@export var trigger_px := 40.0
## ...within this many seconds (i.e. a quick swipe).
@export var trigger_window := 0.12

var _boards_cut := 0
var _cut := 0.0
var _progress := 0.0 # _cut / board_cut, for visuals
var _slide := 0.0
var _dragging := false
var _last_x := 0.0
var _busy := true
var _moved_t := 1.0
var _t := 0.0
var _stroking := false
var _stroke_dir := 0
var _queued_dir := 0
## Recent finger samples (time, finger x, saw slide) for swipe detection.
var _samples: Array[Vector3] = []
## Saw slide where the detected swipe began.
var _swipe_from := 0.0

var _grind: LoopSfx

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

	_grind = LoopSfx.new()
	_grind.stream = Sfx.stream(&"saw_grind")
	_grind.idle_time = 0.1
	add_child(_grind)

	_new_board(false)


func _new_board(animate := true) -> void:
	_cut = 0.0
	_progress = 0.0
	_slide = 0.0
	_queued_dir = 0
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
		_samples.clear()
		if not _dragging:
			_grind.release()
	elif event is InputEventMouseMotion and _dragging:
		var x: float = event.position.x
		var dx := x - _last_x
		_last_x = x
		if _busy:
			# keep tracking the finger between boards so the drag carries on
			# without a jump; no swipe history across boards
			_samples.clear()
			return
		_samples.append(Vector3(_t, x, _slide))
		var swipe := _swipe_dir()
		if _stroking:
			# a quick swipe back during a stroke queues the next one
			if swipe != 0 and swipe != _stroke_dir:
				_queued_dir = swipe
			return
		if swipe != 0 and _room(swipe, _swipe_from) > 0.05:
			# credit the stroke from where the swipe began (the first few px of
			# a swipe already moved the saw as a slow drag)
			_start_stroke(swipe, _swipe_from)
			return
		_grind_move(dx)


## Slow drag: the saw follows the finger, grinds a little, plays the grind loop.
func _grind_move(dx: float) -> void:
	var before := _slide
	_slide = clampf(_slide + dx, -slide_range, slide_range)
	var moved := absf(_slide - before)
	if moved <= 0.0:
		return
	_moved_t = 0.0
	_grind.keep_alive(randf_range(0.97, 1.03))
	_add_cut(moved * grind_per_px * cut_multiplier)
	_update_visuals()
	if _cut >= board_cut:
		_cut_done()


## +1 / -1 if the finger just swiped trigger_px one way within trigger_window.
func _swipe_dir() -> int:
	while _samples.size() > 1 and _t - _samples[0].x > trigger_window:
		_samples.pop_front()
	if _samples.size() < 2:
		return 0
	var d := _samples[-1].y - _samples[0].y
	if absf(d) < trigger_px:
		return 0
	_swipe_from = _samples[0].z
	var last := _samples[-1]
	_samples.clear()
	_samples.append(last)
	return 1 if d > 0.0 else -1


## Fraction of the full stroke between `from` and the end the saw heads to.
func _room(dir: int, from: float) -> float:
	return clampf((dir * slide_range - from) * dir / (2.0 * slide_range), 0.0, 1.0)


## `credit_from`: slide position the cut is measured from (the swipe start).
func _start_stroke(dir: int, credit_from: float) -> void:
	_stroking = true
	_stroke_dir = dir
	_queued_dir = 0
	_grind.release()
	var cut := cut_per_stroke * cut_multiplier * _room(dir, credit_from)
	Sfx.play(&"saw_push" if dir > 0 else &"saw_pull", 1.0, 0.0)
	var from_slide := _slide
	var to_slide := dir * slide_range
	var from_cut := _cut
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		_slide = lerpf(from_slide, to_slide, k)
		_cut = minf(from_cut + cut * k, board_cut)
		_progress = _cut / board_cut
		_moved_t = 0.0
		_update_visuals(), 0.0, 1.0, stroke_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_stroking = false
	if _cut >= board_cut:
		_cut_done()
	elif _queued_dir != 0 and _room(_queued_dir, _slide) > 0.05:
		_start_stroke(_queued_dir, _slide)


func _add_cut(amount: float) -> void:
	_cut = minf(_cut + amount, board_cut)
	_progress = _cut / board_cut


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	_moved_t += delta
	if _dust:
		_dust.emitting = _moved_t < 0.12 and not _busy


func _cut_done() -> void:
	_busy = true
	_queued_dir = 0
	_grind.release()
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
