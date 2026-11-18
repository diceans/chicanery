extends CharacterBody2D

@export var enemy_id: StringName = &""

# Adds the lignolus to the world-enemy group so it can be tracked and cleaned up like other foes.
func _ready() -> void:
	add_to_group("world_enemies")

# Starts a battle when the player touches this lignolus and stores both its shared type ID and unique world position for battle/resource lookup and enemy cleanup.
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "AePlaceholder":
		if enemy_id.is_empty():
			push_error("Enemy %s is missing its unique enemy_id" % name)
			return

		State.active_enemy_id = enemy_id
		State.active_enemy_position = global_position
		var scene_change_error = get_tree().change_scene_to_file("res://scenes/test/battle/battle.tscn")
		if scene_change_error != OK:
			State.active_enemy_id = &""
			State.active_enemy_position = Vector2.ZERO
			push_error("Failed to load the battle scene: %s" % scene_change_error)
