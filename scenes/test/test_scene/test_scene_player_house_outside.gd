extends Node2D

func _ready() -> void:
	if not State.return_player_to_anfugel:
		return
	State.return_player_to_anfugel = false

	var player = get_node_or_null("AePlaceholder") as Node2D
	if player == null:
		push_error("Outside scene is missing AePlaceholder")
		return

	var defeated_enemy_id: StringName = State.defeated_enemy_id
	State.active_enemy_id = &""
	State.defeated_enemy_id = &""
	if defeated_enemy_id.is_empty():
		push_error("No defeated enemy ID was set before returning outside")
		return

	for enemy in get_tree().get_nodes_in_group("world_enemies"):
		if enemy.get("enemy_id") == defeated_enemy_id:
			player.global_position = enemy.global_position
			enemy.queue_free()
			return

	push_error("Could not find defeated enemy with ID %s in the outside scene" % defeated_enemy_id)
