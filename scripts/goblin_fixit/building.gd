class_name Building
extends Node2D
## A fixable building. Layout:
##   Building (this)
##     Structure (TileMapLayer)  run-down / bare-frame tiles
##     Areas (Node2D)
##       <WorkArea> ... each with a "Fixed" TileMapLayer child

signal all_done

## Extra tap area around each work area, in art pixels (half a 16px tile).
@export var tap_padding := 8.0

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


## Available area for a tap at a global point, or null. Each area's tap region
## is its cells grown by `tap_padding` (art px); where padded regions overlap,
## the area whose cells are nearest the tap wins. Locked (not yet available)
## areas still compete, so padding never steals a tap from their tiles.
func area_at(global_point: Vector2) -> WorkArea:
	var best: WorkArea = null
	var best_d := INF
	for a in areas():
		if a.done:
			continue
		var d := a.distance_to_local(a.to_local(global_point))
		if d <= tap_padding and d < best_d:
			best_d = d
			best = a
	return best if best and best.is_available() else null


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
