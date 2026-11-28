extends FixStep
## Saw boards off magic timber. The goblin opens a portal and the timber slides
## out of it; each board is a random length off the timber's end. Slow
## dragging moves the saw with the finger and only grinds a little; a quick
## swipe triggers a full stroke that runs on its own (stroke_time) with its
## SFX, so cutting has a rhythm to match. Cut boards drop, bounce off the
## bottom of the screen and land by the goblin's feet.
##
## No pop-up panel: everything is laid out around the goblin (goblin_feet).

@export var saw_texture: Texture2D = preload("res://assets/sprites/saw.png")
@export var timber_texture: Texture2D = preload("res://assets/sprites/timber.png")
## Screen px per texture px for the saw, timber and portal.
@export var prop_scale := 1.0
## Blade on saw_texture (texture px) that touches the cut. A push stroke runs
## the contact from blade_tip_inset in from the right edge (tip) to
## blade_handle_px in from the left (by the handle); a pull goes back.
@export var blade_handle_px := 60.0
@export var blade_tip_inset := 10.0
## Teeth line height on saw_texture (texture px).
@export var saw_teeth_y := 44.0

@export_group("Layout")
## Gap between the goblin's right edge and the portal's left edge (screen px).
## The portal sits level with the goblin's middle.
@export var portal_gap := 10.0
## Portal half-width (portal texture px) used to place it beside the goblin.
@export var portal_half_width := 100.0
## Where the timber is hidden inside the portal, from its centre (screen px,
## at prop_scale 1): the timber shows from here rightwards.
@export var portal_clip := -95.0
## Cut line distance right of the portal centre (screen px).
@export var cut_offset := 210.0
## Board length range (timber texture px).
@export var board_length := Vector2i(230, 330)
## Seconds to slide the timber out for each board.
@export var extrude_time := 0.6
## Cut boards land here relative to the goblin's feet (screen px, board's
## left end); later boards stack on top.
@export var pile_offset := Vector2(30, 0)

## Saw slide either side of centre (screen px), from the blade range above.
var slide_range := 110.0

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

var _portal: Portal
var _timber: Sprite2D
var _board: Sprite2D
var _kerf: ColorRect
var _saw: Sprite2D
var _dust: CPUParticles2D
var _pile: Array[Sprite2D] = []

var _cut_x := 0.0
var _clip_x := 0.0
var _timber_top := 0.0
## Timber texture px still attached (shrinks as boards are cut off).
var _timber_len := 0.0
## Screen x of the timber's right end.
var _timber_end := 0.0
## Current board length (texture px); 0 while no board is marked.
var _board_len := 0.0


func _init() -> void:
	super._init()
	uses_panel = false


func begin() -> void:
	super.begin()
	title = "Saw the boards!"
	var ps := prop_scale
	var portal_pos := Vector2(goblin_rect.end.x + portal_gap + portal_half_width * ps,
			goblin_rect.get_center().y).round()
	_cut_x = portal_pos.x + cut_offset
	_clip_x = portal_pos.x + portal_clip * ps
	_timber_top = portal_pos.y - timber_texture.get_height() * ps / 2.0
	_timber_len = timber_texture.get_width()
	_timber_end = _clip_x

	# draw order: portal back, timber, saw, board, kerf, portal ring front, dust
	_portal = Portal.new()
	_portal.place(portal_pos)
	add_child(_portal)
	_timber = _wood_sprite()
	add_child(_timber)

	_saw = Sprite2D.new()
	_saw.texture = saw_texture
	_saw.centered = false
	# contact point at the middle of the blade; sliding moves it toward tip/handle
	var tip_x := saw_texture.get_width() - blade_tip_inset
	_saw.offset = -Vector2((blade_handle_px + tip_x) / 2.0, saw_teeth_y)
	slide_range = (tip_x - blade_handle_px) / 2.0 * ps
	_saw.scale = Vector2.ONE * ps
	_saw.modulate.a = 0.0
	add_child(_saw)

	_board = _wood_sprite()
	add_child(_board)

	_kerf = ColorRect.new()
	_kerf.color = Color(0.25, 0.15, 0.08)
	_kerf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_kerf)

	add_child(_portal.front)

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

	_grind = LoopSfx.new()
	_grind.stream = Sfx.stream(&"saw_grind")
	_grind.idle_time = 0.1
	add_child(_grind)

	move_child(top, -1)
	_update_visuals()
	_intro()


func _wood_sprite() -> Sprite2D:
	var w := Sprite2D.new()
	w.texture = timber_texture
	w.centered = false
	w.region_enabled = true
	w.scale = Vector2.ONE * prop_scale
	w.visible = false
	return w


func _intro() -> void:
	Sfx.play(&"whoosh", 0.7)
	await _portal.open(prop_scale)
	await _new_board()
	create_tween().tween_property(_saw, "modulate:a", 1.0, 0.25)


## Slides the timber out of the portal by a random board length; that end
## piece becomes the board to saw off.
func _new_board() -> void:
	_busy = true
	_cut = 0.0
	_progress = 0.0
	_slide = 0.0
	_queued_dir = 0
	_board_len = 0.0
	var length := float(randi_range(board_length.x, board_length.y))
	length = clampf(length, 1.0, maxf(_timber_len - 1.0, 1.0))
	Sfx.play(&"whoosh", 1.3, -6.0)
	var tw := create_tween()
	tw.tween_method(func(x: float) -> void:
		_timber_end = x
		_update_visuals(), _timber_end, _cut_x + length * prop_scale, extrude_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	_board_len = length
	_update_visuals()
	_busy = false


func _update_visuals() -> void:
	var ps := prop_scale
	var h := timber_texture.get_height()
	# timber still attached: from inside the portal to the cut (or its end)
	var main_end := _cut_x if _board_len > 0.0 else _timber_end
	var main_len := _timber_len - _board_len
	var tex_w := minf(main_len, (main_end - _clip_x) / ps)
	_timber.visible = tex_w > 0.0
	if _timber.visible:
		_timber.region_rect = Rect2(main_len - tex_w, 0, tex_w, h)
		_timber.position = Vector2(main_end - tex_w * ps, _timber_top)
	# the board being sawn off: the timber's last _board_len px, seamless
	_board.visible = _board_len > 0.0
	if _board.visible:
		_board.region_rect = Rect2(_timber_len - _board_len, 0, _board_len, h)
		_board.position = Vector2(_cut_x, _timber_top)
	var depth := _progress * h * ps
	_kerf.visible = _board_len > 0.0
	_kerf.position = Vector2(_cut_x - 3.0, _timber_top)
	_kerf.size = Vector2(6.0, depth)
	_saw.position = Vector2(_cut_x + _slide, _timber_top + depth)
	_dust.position = Vector2(_cut_x, _timber_top + depth + 6.0)


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
	# hand the board piece to a new sprite that falls; timber keeps the rest
	var piece := _wood_sprite()
	piece.visible = true
	piece.region_rect = _board.region_rect
	piece.centered = true
	var size := piece.region_rect.size * prop_scale
	piece.position = _board.position + size / 2.0
	add_child(piece)
	move_child(piece, _portal.front.get_index())
	_timber_len -= _board_len
	_board_len = 0.0
	_timber_end = _cut_x
	_progress = 0.0
	_update_visuals()
	_boards_cut += 1
	var last := _boards_cut >= board_count()
	if last:
		create_tween().tween_property(_saw, "modulate:a", 0.0, 0.25)
	await _drop_board(piece, size)
	if last:
		await _outro()
		finish(0.2)
	else:
		_new_board()


## Drop with the right end leading, bounce off the screen bottom, spin over to
## land by the goblin's feet.
func _drop_board(piece: Sprite2D, size: Vector2) -> void:
	var bottom := get_viewport_rect().size.y - size.y * 0.3
	var tw := create_tween().set_parallel()
	tw.tween_property(piece, "position", Vector2(piece.position.x + 40.0, bottom), 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(piece, "rotation", 0.55, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	Sfx.play(&"place", 0.8)
	var from := piece.position
	var land := goblin_feet + pile_offset + Vector2(size.x / 2.0, -size.y / 2.0 - _pile.size() * size.y * 0.9)
	var hop := 260.0
	var spin := TAU
	var tw2 := create_tween()
	tw2.tween_method(func(k: float) -> void:
		piece.position = from.lerp(land, k) - Vector2(0, sin(PI * k) * hop)
		piece.rotation = lerpf(0.55, spin, k), 0.0, 1.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw2.finished
	piece.rotation = 0.0
	_pile.append(piece)
	Sfx.play(&"place", 1.2, -2.0)


## Leftover timber slides back into the portal, then the portal closes.
func _outro() -> void:
	var tw := create_tween()
	tw.tween_method(func(x: float) -> void:
		_timber_end = x
		_update_visuals(), _timber_end, _clip_x, extrude_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	Sfx.play(&"whoosh", 0.6)
	await _portal.close()


func _draw_top() -> void:
	if _busy or _board_len <= 0.0:
		return
	# dashed cut line
	var h := timber_texture.get_height() * prop_scale
	var y := _timber_top + _progress * h
	while y < _timber_top + h:
		top.draw_line(Vector2(_cut_x, y), Vector2(_cut_x, minf(y + 8.0, _timber_top + h)), Color(0.15, 0.1, 0.4), 3.0)
		y += 14.0
	# back-and-forth hint until the first board is started
	if _boards_cut == 0 and _progress < 0.08:
		var bob := sin(_t * 5.0) * 30.0
		var c := Vector2(_cut_x + bob, _timber_top - 110.0)
		draw_arrow(top, c - Vector2(90, 0), c + Vector2(90, 0), Color(1, 1, 1, 0.85), 10.0, true)
