extends Node
## Slot-0 autosave ownership. JSON normalization happens only in deserialize().

const SAVE_VERSION := 1
const SLOT_0 := "user://slot0.sav"

var data: SaveData = SaveData.new()
var _dirty: bool = false


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		save_slot()


func new_game() -> void:
	data = SaveData.new()
	_dirty = false


func mark_dirty() -> void:
	_dirty = true


func has_save() -> bool:
	return FileAccess.file_exists(SLOT_0)


func save_slot(path: String = SLOT_0, simulate_interruption: bool = false) -> bool:
	return write_atomic(path, data, simulate_interruption)


func load_slot(path: String = SLOT_0) -> bool:
	var loaded := load_from_path(path)
	if loaded == null:
		return false
	data = loaded
	return true


## The simulation hook exists only for the headless atomicity gate: it stops
## after the temp file has been closed, exactly where an interrupted process
## would stop, without ever touching the existing slot.
static func write_atomic(path: String, value: SaveData,
		simulate_interruption: bool = false) -> bool:
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open save temp file: %s" % temp_path)
		return false
	file.store_string(serialize(value))
	file.flush()
	file.close()
	if simulate_interruption:
		return false
	if DirAccess.rename_absolute(temp_path, path) != OK:
		push_error("Could not atomically replace save slot: %s" % path)
		return false
	return true


static func load_from_path(path: String) -> SaveData:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var loaded := deserialize(file.get_as_text())
	file.close()
	return loaded


static func serialize(value: SaveData) -> String:
	return JSON.stringify({
		"version": SAVE_VERSION,
		"chapter": value.chapter,
		"flags": _to_json_value(value.flags),
		"inventory": _to_json_value(value.inventory),
		"journal_entries": _to_json_value(value.journal_entries),
		"journal_overrides": _to_json_value(value.journal_overrides),
		"secrets_found": _to_json_value(value.secrets_found),
		"sigils_found": _to_json_value(value.sigils_found),
		"ciphers_solved": _to_json_value(value.ciphers_solved),
		"checkpoint": _to_json_value(value.checkpoint),
		"playtime": value.playtime,
	})


## The only boundary that rebuilds JSON's String keys as StringName and the
## checkpoint's [x, y] fallback as Vector2. Missing fields retain SaveData's
## defaults; newer save versions are refused rather than partially loaded.
static func deserialize(text: String) -> SaveData:
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		push_error("Save file is not valid JSON")
		return null
	var raw: Dictionary = json.data
	var version := int(raw.get("version", -1))
	if version > SAVE_VERSION:
		return null
	if version < 1:
		push_error("Save file has no supported version")
		return null

	var restored := SaveData.new()
	restored.chapter = int(raw.get("chapter", restored.chapter))
	restored.flags = _restore_dictionary(raw.get("flags", {}))
	restored.inventory = _restore_dictionary(raw.get("inventory", {}))
	restored.journal_entries = _restore_string_name_array(raw.get("journal_entries", []))
	restored.journal_overrides = _restore_dictionary(raw.get("journal_overrides", {}))
	restored.secrets_found = _restore_string_name_array(raw.get("secrets_found", []))
	restored.sigils_found = _restore_string_name_array(raw.get("sigils_found", []))
	restored.ciphers_solved = _restore_string_name_array(raw.get("ciphers_solved", []))
	restored.checkpoint = _restore_checkpoint(raw.get("checkpoint", {}), restored.checkpoint)
	restored.playtime = float(raw.get("playtime", restored.playtime))
	return restored


static func _to_json_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return {"__gf_type": "int", "value": value}
	if value is StringName:
		return {"__gf_type": "StringName", "value": String(value)}
	if value is Vector2:
		return [value.x, value.y]
	if value is Dictionary:
		var out: Dictionary = {}
		for key in value:
			out[String(key)] = _to_json_value(value[key])
		return out
	if value is Array:
		var out: Array = []
		for item in value:
			out.append(_to_json_value(item))
		return out
	return value


static func _restore_dictionary(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not value is Dictionary:
		return out
	for key in value:
		var normalized_key: StringName = str(key)
		out[normalized_key] = _restore_value(value[key])
	return out


static func _restore_value(value: Variant) -> Variant:
	if value is Dictionary:
		var marker := String(value.get("__gf_type", ""))
		if marker == "int":
			return int(value.get("value", 0))
		if marker == "StringName":
			var normalized_name: StringName = str(value.get("value", ""))
			return normalized_name
		return _restore_dictionary(value)
	if value is Array:
		var out: Array = []
		for item in value:
			out.append(_restore_value(item))
		return out
	return value


static func _restore_string_name_array(value: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if value is Array:
		for item in value:
			var restored_item: Variant = _restore_value(item)
			if restored_item is StringName:
				out.append(restored_item)
			else:
				var normalized_item: StringName = str(restored_item)
				out.append(normalized_item)
	return out


static func _restore_checkpoint(value: Variant, defaults: Dictionary) -> Dictionary:
	var checkpoint: Dictionary = defaults.duplicate(true)
	var raw := _restore_dictionary(value)
	for key in raw:
		checkpoint[key] = raw[key]
	var position: Variant = checkpoint.get(&"position", Vector2.ZERO)
	if position is Array and position.size() == 2:
		checkpoint[&"position"] = Vector2(float(position[0]), float(position[1]))
	elif not position is Vector2:
		checkpoint[&"position"] = Vector2.ZERO
	return checkpoint
