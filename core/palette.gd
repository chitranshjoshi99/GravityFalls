class_name Palette
extends Resource
## Doc 01 §1.5. Zone colors are data; the global weirdness grade is not.

@export_group("Foliage & Terrain")
@export var pine_deep: Color = Color("1b3b2f")
@export var pine_mid: Color = Color("2e5d45")
@export var moss: Color = Color("6b8f4e")
@export var fern_light: Color = Color("9cb46a")
@export var bark_dark: Color = Color("3a2a1e")
@export var bark_mid: Color = Color("5c4033")
@export var soil: Color = Color("7a5c3e")
@export var stone_cold: Color = Color("6e7b78")

@export_group("Atmosphere")
@export var fog: Color = Color("b9c4bc")
@export var sky: Color = Color("8fc1de")
@export var light_warm: Color = Color("f2d98d")

@export_group("Interior")
@export var wall: Color = Color("6b4a2f")
@export var floor_tone: Color = Color("4a3220")
@export var accent: Color = Color("a6392e")

@export_group("Anomaly")
@export var anomaly_primary: Color = Color("2bd9ff")
@export var anomaly_secondary: Color = Color("ff3fa4")
@export var anomaly_glow: Color = Color("39ff88")

@export_group("Grade")
## Applied by ZoneManager in row 2.3; PaletteRegion must never own this grade.
@export_range(0.0, 1.0) var ambient_weirdness: float = 0.0
