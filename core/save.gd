extends Node
## Best scores per game, kept in user://save.cfg.

const PATH := "user://save.cfg"
var cfg := ConfigFile.new()

func _ready() -> void:
	cfg.load(PATH)  # ponytail: a missing file just means no bests yet

func best(id: String) -> float:
	return cfg.get_value("best", id, 0.0)

## Stores v if it beats the old best. lower_is_better for time-based games.
func submit(id: String, v: float, lower_is_better := false) -> float:
	var old := best(id)
	var better := old == 0.0 or (v < old if lower_is_better else v > old)
	if better:
		cfg.set_value("best", id, v)
		cfg.save(PATH)
	return old

func get_data(id: String, key: String, default = null):
	return cfg.get_value(id, key, default)

func set_data(id: String, key: String, value) -> void:
	cfg.set_value(id, key, value)
	cfg.save(PATH)
