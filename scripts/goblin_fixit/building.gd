class_name Building
extends Node2D
## A fixable building. Layout:
##   Building (this)
##     Structure (TileMapLayer)  run-down / bare-frame tiles
##     Areas (Node2D)
##       <WorkArea> ... each with a "Fixed" TileMapLayer child

signal all_done

@onready var structure: TileMapLayer = $Structure


func areas() -> Array[WorkArea]:
	var out: Array[WorkArea] = []
	for c in $Areas.get_children():
		if c is WorkArea:
			out.append(c)
	return out


func refresh_highlights() -> void:
	for a in areas():
		a.highlighted = a.is_available()


func clear_highlights() -> void:
	for a in areas():
		a.highlighted = false


## Topmost available area under a global point, or null.
func area_at(global_point: Vector2) -> WorkArea:
	var list := areas()
	list.reverse()
	for a in list:
		if a.is_available() and a.global_rect().has_point(global_point):
			return a
	return null


func is_complete() -> bool:
	for a in areas():
		if not a.done:
			return false
	return true


func reset() -> void:
	for a in areas():
		a.reset()
	refresh_highlights()


## Size in parent space (includes this node's scale).
func size_px() -> Vector2:
	var r := structure.get_used_rect()
	for a in areas():
		r = r.merge(a.fixed.get_used_rect())
	return Vector2(r.end) * Vector2(structure.tile_set.tile_size) * scale
