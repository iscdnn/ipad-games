extends Node
## Autoload "Save": persists the high score between sessions.
## On the web export, user:// is backed by the browser's IndexedDB, so this
## survives reloads as long as the player doesn't clear site data.

const SAVE_PATH := "user://save.cfg"

var high_score: int = 0


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = int(cfg.get_value("scores", "high", 0))


## Records a finished round. Returns true if it beat the previous best.
func submit_score(score: int) -> bool:
	if score <= high_score:
		return false
	high_score = score
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "high", high_score)
	cfg.save(SAVE_PATH)
	return true
