extends CharacterBody2D

@export var enemy_id: StringName = &""

# Adds the enemy to the world-enemy group so outside-scene cleanup can target all active foes.
func _ready() -> void:
	add_to_group("world_enemies")

# Starts a battle when the player touches this enemy and stores the enemy ID for resource lookup.
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "AePlaceholder":
		if enemy_id.is_empty():
			push_error("Enemy %s is missing its unique enemy_id" % name)
			return

		State.active_enemy_id = enemy_id
		var scene_change_error = get_tree().change_scene_to_file("res://scenes/test/battle/battle.tscn")
		if scene_change_error != OK:
			State.active_enemy_id = &""
			push_error("Failed to load the battle scene: %s" % scene_change_error)
