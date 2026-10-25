extends Node2D
@export var ally: Resource = null

func _ready() -> void:
	var returning_from_battle: bool = State.return_player_to_anfugel
	State.return_player_to_anfugel = false

	var player := get_node_or_null("AePlaceholder") as Node2D
	var active_id: StringName = State.active_enemy_id
	var found_active_enemy := false
	if returning_from_battle and player == null:
		push_error("Outside scene is missing AePlaceholder")
		return

	for enemy: Node2D in get_tree().get_nodes_in_group("world_enemies"):
		var enemy_id: StringName = enemy.get("enemy_id")

		if State.defeated_enemy_ids.has(enemy_id):
			if returning_from_battle and enemy_id == active_id:
				player.global_position = enemy.global_position
				found_active_enemy = true
			enemy.queue_free()

	State.active_enemy_id = &""

	if returning_from_battle and not found_active_enemy:
		push_error("Could not find the enemy from the completed battle")
