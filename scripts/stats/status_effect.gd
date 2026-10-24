extends Resource
class_name StatusEffect

@export var effect_name: String = "Status"
@export var icon: Texture2D
@export_range(1, 1000) var duration_turns: int = 1
@export var flat_modifiers: Dictionary = {}
@export var stat_multipliers: Dictionary = {}
@export var custom_properties: Dictionary = {}
