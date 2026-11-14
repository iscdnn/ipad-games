class_name WorkArea
extends Node2D
## One part of a building that needs fixing (a wall, the floor, the roof...).
##
## Paint the FINISHED tiles into the child TileMapLayer "Fixed". Its painted
## cells define the highlighted, tappable region. It stays hidden until every
## step in `steps` is done, then fades in over the run-down tiles below.

signal completed

@export var display_name := "Wall"
## Interaction scenes played in order inside the pop-up window.
@export var steps: Array[PackedScene] = []
## How many boards this area needs (saw / place / nail all use this).
@export_range(1, 4) var board_count := 3
@export_range(1, 3) var nails_per_board := 2
## Other WorkAreas that must be finished before this one lights up.
@export var requires: Array[NodePath] = []

const HIGHLIGHT := Color(1.0, 0.9, 0.2)

var done := false
var highlighted := false:
	set(v):
		highlighted = v
		queue_redraw()

var _t := 0.0

@onready var fixed: TileMapLayer = $Fixed


func _ready() -> void:
	fixed.visible = false


func _process(delta: float) -> void:
	if highlighted:
		_t += delta
		queue_redraw()


## Area rect in this node's local space (tile pixels).
func local_rect() -> Rect2:
	var r := fixed.get_used_rect()
	var ts := Vector2(fixed.tile_set.tile_size)
	return Rect2(fixed.position + Vector2(r.position) * ts, Vector2(r.size) * ts)


func global_rect() -> Rect2:
	return global_transform * local_rect()


func is_available() -> bool:
	if done:
		return false
	for path in requires:
		var other := get_node_or_null(path) as WorkArea
		if other and not other.done:
			return false
	return true


func complete() -> void:
	done = true
	highlighted = false
	fixed.visible = true
	fixed.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(fixed, "modulate:a", 1.0, 0.45)
	_puff()
	completed.emit()


func reset() -> void:
	done = false
	fixed.visible = false
	highlighted = false


func _draw() -> void:
	if not highlighted:
		return
	var r := local_rect()
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	draw_rect(r, Color(HIGHLIGHT, 0.12 + 0.18 * pulse))
	draw_rect(r.grow(1.0 + pulse), Color(HIGHLIGHT, 0.9), false, 2.0)
	# "tap me" ripple in the middle
	var c := r.get_center()
	var ring := fmod(_t, 1.2) / 1.2
	draw_arc(c, 4.0 + ring * 12.0, 0, TAU, 24, Color(1, 1, 1, 1.0 - ring), 1.5)
	draw_circle(c, 3.0, Color(1, 1, 1, 0.9))


func _puff() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 40
	p.lifetime = 0.8
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	var r := local_rect()
	p.position = r.get_center()
	p.emission_rect_extents = r.size / 2.0
	p.direction = Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 60.0
	p.gravity = Vector2(0, 40)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(1, 0.95, 0.7, 0.9)
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
