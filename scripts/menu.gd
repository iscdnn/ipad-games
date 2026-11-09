extends Control
## Title screen: rainbow gradient background and a big "Tap to Play" button.
## The first tap also satisfies the browser's "user gesture" rule for audio.


func _ready() -> void:
	_build_background()
	_build_ui()


func _build_background() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0])
	grad.colors = PackedColorArray([
		Color("ff4d4d"), # red
		Color("ff9f43"), # orange
		Color("ffe94d"), # yellow
		Color("5ee66b"), # green
		Color("4dc3ff"), # blue
		Color("6b6bff"), # indigo
		Color("c15bff"), # violet
	])

	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 256
	tex.height = 256

	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR # smooth, not pixelated
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_ui() -> void:
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 28)
	center.add_child(vbox)

	vbox.add_child(_make_label("Sheep Shearer", 104))
	vbox.add_child(_make_label("Tap the sheep to shear them.\nYou have 60 seconds!", 38))
	vbox.add_child(_make_label("Best: %d" % Save.high_score, 44))

	var button := Button.new()
	button.text = "Tap to Play"
	button.custom_minimum_size = Vector2(440, 130)
	button.add_theme_font_size_override("font_size", 58)
	button.pressed.connect(_on_play_pressed)
	vbox.add_child(button)

	# Gentle pulse so it's obvious what to do.
	button.pivot_offset = button.custom_minimum_size / 2.0
	var tw := create_tween().set_loops()
	tw.tween_property(button, "scale", Vector2(1.06, 1.06), 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(button, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)


func _make_label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color("2b2b3a"))
	l.add_theme_constant_override("outline_size", maxi(font_size / 8, 4))
	return l


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")
