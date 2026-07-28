class_name SaveData
extends Resource
## The complete persisted playthrough state. No live player-node state belongs
## here: health, stamina, Journal state, and equipped runtime items stay owned
## by their respective player nodes.

var chapter: int = 1
var flags: Dictionary = {}
var inventory: Dictionary = {}
var journal_entries: Array[StringName] = []
var journal_overrides: Dictionary = {}
var secrets_found: Array[StringName] = []
var sigils_found: Array[StringName] = []
var ciphers_solved: Array[StringName] = []
var checkpoint: Dictionary = {
	&"id": &"", &"zone_id": &"", &"spawn_marker": &"", &"wake_line_id": &"",
	&"position": Vector2.ZERO,
	&"encounter": {},
}
var playtime: float = 0.0
