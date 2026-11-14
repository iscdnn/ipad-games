class_name WorkArea
extends Node2D
## One part of a building that needs fixing (a wall, the floor, the roof...).
##
## Paint the FINISHED tiles into the child TileMapLayer "Fixed". Its painted
## cells are the area: any contiguous shape. The layer is hidden at runtime
## until every step in `steps` is done, then draws over the broken tiles.
## Keep it visible in the editor to see the finished building.

signal completed

@export var display_name := "Wall"
## Interaction scenes played in order inside the pop-up window.
@export var steps: Array[PackedScene] = []
## How many boards this area needs (saw / place / nail all use this).
@export_range(1, 4) var board_count := 3
@export_range(1, 3) var nails_per_board := 2
## Other WorkAreas that must be finished before this one lights up.
@export var requires: Array[NodePath] = []

@export_group("Highlight")
## Marching-ants outline, in art pixels. Each ant is followed by an equal gap.
@export var ant_length := 2.0
@export var ant_speed := 8.0
@export var ant_width := 1.0
@export var ant_colors: Array[Color] = [Color(1.0, 0.85, 0.1), Color(0.08, 0.08, 0.08)]

var done := false
var highlighted := false:
	set(v):
		highlighted = v
		queue_redraw()

var _t := 0.0
var _cells := {} # Vector2i -> true
var _loops: Array[PackedVector2Array] = [] # outline loops, clockwise, inset

@onready var fixed: TileMapLayer = $Fixed


func _ready() -> void:
	fixed.visible = false
	for c in fixed.get_used_cells():
		_cells[c] = true
	_build_outline()


func _process(delta: float) -> void:
	if highlighted:
		_t += delta
		queue_redraw()


func tile_size() -> Vector2:
	return Vector2(fixed.tile_set.tile_size)


## Bounding rect of the area in this node's local space.
func local_rect() -> Rect2:
	var r := fixed.get_used_rect()
	var ts := tile_size()
	return Rect2(fixed.position + Vector2(r.position) * ts, Vector2(r.size) * ts)


func global_rect() -> Rect2:
	return global_transform * local_rect()


## Distance (local units) from a local point to the nearest cell. 0 if inside.
func distance_to_local(p: Vector2) -> float:
	var ts := tile_size()
	var best := INF
	for c in _cells:
		var r := Rect2(fixed.position + Vector2(c) * ts, ts)
		var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
		var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
		best = minf(best, Vector2(dx, dy).length())
		if best <= 0.0:
			return 0.0
	return best


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


# --- marching ants ---------------------------------------------------------

## Traces the outer edges of the painted cells into clockwise loops
## (y points down, so "clockwise" = top edges run left-to-right).
func _build_outline() -> void:
	_loops.clear()
	var ts := tile_size()
	var next := {} # start corner (Vector2i) -> Array of end corners
	var dirs := [
		[Vector2i(0, -1), Vector2i(0, 0), Vector2i(1, 0)], # top
		[Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 1)], # right
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 1)], # bottom
		[Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, 0)], # left
	]
	for c in _cells:
		for d in dirs:
			if not _cells.has(c + d[0]):
				var a: Vector2i = c + d[1]
				var b: Vector2i = c + d[2]
				if not next.has(a):
					next[a] = []
				next[a].append(b)
	while not next.is_empty():
		var start: Vector2i = next.keys()[0]
		var corners: Array[Vector2i] = [start]
		var cur := start
		while true:
			var ends: Array = next.get(cur, [])
			if ends.is_empty():
				break
			var nxt: Vector2i = ends.pop_back()
			if ends.is_empty():
				next.erase(cur)
			if nxt == start:
				break
			corners.append(nxt)
			cur = nxt
		_loops.append(_inset_loop(_simplify(corners), ts))


static func _simplify(pts: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var n := pts.size()
	for i in n:
		var a := pts[(i - 1 + n) % n]
		var b := pts[i]
		var c := pts[(i + 1) % n]
		if (b - a).sign() != (c - b).sign():
			out.append(b)
	return out


## Corner points moved half a line-width inward so the line sits inside the cells.
func _inset_loop(pts: Array[Vector2i], ts: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	var half := ant_width / 2.0
	for i in n:
		var a := Vector2(pts[(i - 1 + n) % n])
		var b := Vector2(pts[i])
		var c := Vector2(pts[(i + 1) % n])
		var d1 := (b - a).normalized()
		var d2 := (c - b).normalized()
		# inside is to the right of travel: (-dy, dx) with y down
		var n1 := Vector2(-d1.y, d1.x)
		var n2 := Vector2(-d2.y, d2.x)
		out.append(fixed.position + b * ts + (n1 + n2) * half)
	return out


func _draw() -> void:
	if not highlighted:
		return
	var phase := _t * ant_speed
	for loop in _loops:
		var n := loop.size()
		var walked := 0.0
		for i in n:
			var a := loop[i]
			var b := loop[(i + 1) % n]
			var seg := a.distance_to(b)
			# dashes are numbered along the loop; shifting by phase marches them clockwise
			var s0 := walked - phase
			var idx := floori(s0 / ant_length)
			var u := 0.0
			while u < seg:
				var v := minf((idx + 1) * ant_length - s0, seg)
				if v > u:
					# even slots are ants, odd slots are gaps; ants alternate colours
					if posmod(idx, 2) == 0:
						var col: Color = ant_colors[posmod(floori(idx / 2.0), ant_colors.size())]
						draw_line(a.lerp(b, u / seg), a.lerp(b, v / seg), col, ant_width)
					u = v
				idx += 1
			walked += seg


func _puff() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 30
	p.lifetime = 0.8
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	var r := local_rect()
	p.position = r.get_center()
	p.emission_rect_extents = r.size / 2.0
	p.direction = Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 24.0
	p.gravity = Vector2(0, 16)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color(1, 0.95, 0.7, 0.9)
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
