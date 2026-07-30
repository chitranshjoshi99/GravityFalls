extends Node
## Person-level accessibility preferences. These never enter a game save.

const SETTINGS_PATH := "user://settings.cfg"
const TEXT_SCALES: Array[float] = [1.0, 1.25, 1.5]

var text_effects_enabled: bool = true:
	set(value):
		text_effects_enabled = value
		_changed()

var text_scale: float = 1.0:
	set(value):
		text_scale = _nearest_text_scale(value)
		_changed()

var reduce_flashing: bool = false:
	set(value):
		reduce_flashing = value
		_apply_runtime_effects()
		_changed()

var _path: String = SETTINGS_PATH
var _loading: bool = false


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	load_from(SETTINGS_PATH)


func load_from(path: String) -> void:
	_path = path
	var config := ConfigFile.new()
	if config.load(path) != OK:
		_apply_runtime_effects()
		return
	_loading = true
	text_effects_enabled = bool(config.get_value("accessibility", "text_effects_enabled", true))
	text_scale = float(config.get_value("accessibility", "text_scale", 1.0))
	reduce_flashing = bool(config.get_value("accessibility", "reduce_flashing", false))
	_loading = false
	_apply_runtime_effects()


func save_settings() -> bool:
	return save_to(_path)


func save_to(path: String) -> bool:
	_path = path
	var config := ConfigFile.new()
	config.set_value("accessibility", "text_effects_enabled", text_effects_enabled)
	config.set_value("accessibility", "text_scale", text_scale)
	config.set_value("accessibility", "reduce_flashing", reduce_flashing)
	return config.save(path) == OK


## Called by Weirdness.bind() indirectly through the autoload at runtime, and
## directly by tests with a local Weirdness instance.
func apply_to_weirdness(weirdness: Node) -> void:
	if weirdness.has_method("set_reduce_flashing"):
		weirdness.set_reduce_flashing(reduce_flashing)


func _apply_runtime_effects() -> void:
	if not is_inside_tree():
		return
	var weirdness := get_node_or_null("/root/Weirdness")
	if weirdness:
		apply_to_weirdness(weirdness)


func _changed() -> void:
	if not _loading:
		save_settings()


func _nearest_text_scale(value: float) -> float:
	var nearest := TEXT_SCALES[0]
	for candidate in TEXT_SCALES:
		if absf(candidate - value) < absf(nearest - value):
			nearest = candidate
	return nearest
