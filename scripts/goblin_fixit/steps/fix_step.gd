class_name FixStep
extends Control
## Base for one interaction inside the pop-up window.
## The window sets `area` and `size`, calls begin(), then waits for `completed`.
##
## Children are drawn in this order: under-overlay, sprites, top-overlay,
## so outlines can sit beneath boards and hints can sit above everything.

signal completed

@export var title := "Fix it!"
@export var board_texture: Texture2D = preload("res://assets/sprites/board.png")
## Pixel width of board_texture that remains after the cut (the rest is offcut).
@export var board_keep_px := 120
## Screen pixels per art pixel; the window sets this from the minigame zoom.
@export var art_scale := 2.0

var area: WorkArea
var under: Node2D
var top: Node2D
var _finished := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


## Call super.begin() first when overriding.
func begin() -> void:
	under = Node2D.new()
	add_child(under)
	under.draw.connect(_draw_under)
	top = Node2D.new()
	top.z_index = 10
	add_child(top)
	top.draw.connect(_draw_top)


func _process(_delta: float) -> void:
	if under:
		under.queue_redraw()
		top.queue_redraw()


func _draw_under() -> void:
	pass


func _draw_top() -> void:
	pass


func finish(delay := 0.5) -> void:
	if _finished:
		return
	_finished = true
	await get_tree().create_timer(delay).timeout
	completed.emit()


func board_count() -> int:
	return area.board_count if area else 3


func nails_per_board() -> int:
	return area.nails_per_board if area else 2


## Size of a cut board on screen.
func board_size() -> Vector2:
	return Vector2(board_keep_px, board_texture.get_height()) * art_scale


## Slots for boards stacked vertically, centred on `center`.
func slot_rects(center: Vector2) -> Array[Rect2]:
	var n := board_count()
	var bs := board_size()
	var gap := 10.0
	var total_h := n * bs.y + (n - 1) * gap
	var out: Array[Rect2] = []
	for i in n:
		var y := center.y - total_h / 2.0 + i * (bs.y + gap)
		out.append(Rect2(Vector2(center.x - bs.x / 2.0, y), bs))
	return out


## The wooden frame the boards get fixed onto.
func draw_frame(on: CanvasItem, slots: Array[Rect2]) -> void:
	if slots.is_empty():
		return
	var r := slots[0]
	for s in slots:
		r = r.merge(s)
	r = r.grow(18.0)
	var wood := Color(0.8, 0.62, 0.38)
	var dark := Color(0.5, 0.36, 0.2)
	for x in [r.position.x, r.get_center().x - 9.0, r.end.x - 18.0]:
		var post := Rect2(x, r.position.y - 12.0, 18.0, r.size.y + 24.0)
		on.draw_rect(post, wood)
		on.draw_rect(post, dark, false, 2.0)


## A Sprite2D showing the cut board (or the whole uncut board).
func make_board(uncut := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = board_texture
	s.region_enabled = true
	var w := board_texture.get_width() if uncut else board_keep_px
	s.region_rect = Rect2(0, 0, w, board_texture.get_height())
	s.scale = Vector2.ONE * art_scale
	return s


## Draws a simple arrow, used for hints.
static func draw_arrow(on: CanvasItem, from: Vector2, to: Vector2, color: Color, width := 8.0, both := false) -> void:
	on.draw_line(from, to, color, width, true)
	var dir := (to - from).normalized()
	var side := dir.orthogonal()
	var head := 24.0
	on.draw_colored_polygon(PackedVector2Array([to + dir * 6.0, to - dir * head + side * head * 0.7, to - dir * head - side * head * 0.7]), color)
	if both:
		on.draw_colored_polygon(PackedVector2Array([from - dir * 6.0, from + dir * head + side * head * 0.7, from + dir * head - side * head * 0.7]), color)


static func pointer_pos(event: InputEvent) -> Vector2:
	return (event as InputEventMouse).position
