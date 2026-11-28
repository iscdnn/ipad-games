class_name RubStepConfig
extends StepConfig
## Shared settings for rub-to-cover steps (sand, paint).

enum Surface {
	BOARDS, ## one surface per board (area's board_count), stacked on the frame
	PANEL, ## one big surface from panel_texture
}

@export var surface := Surface.BOARDS
## Art for the PANEL surface (ignored for BOARDS).
@export var panel_texture: Texture2D = preload("res://assets/sprites/panel.png")
## Brush radius in screen pixels.
@export var brush_radius := 34.0
## Fraction covered before the rest fills in by itself.
@export_range(0.5, 1.0) var complete_at := 0.9
