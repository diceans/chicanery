extends Node

# The allies in the party, in id order. Holding the resource files here keeps each ally's current WN
# between battles, since a resource nothing references is unloaded and would reload at full WN.
var party: Array[Resource] = [
	preload("res://scripts/res/allies/ae.tres"),
	preload("res://scripts/res/allies/elizyka.tres"),
]
var return_player_to_enemy = false
var active_enemy_id: StringName = &""
var active_enemy_position: Vector2 = Vector2.ZERO
var defeated_enemy_positions: Dictionary = {}
