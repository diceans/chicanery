extends CharacterBody2D

@export var enemy_id: StringName = &""

# Adds the enemy to the world-enemy group so outside-scene cleanup can target all active foes.
func _ready() -> void:
	add_to_group("world_enemies")

# Starts a battle when the player touches this enemy and stores both its shared type ID and unique world position for battle/resource lookup and enemy cleanup.
func _on_area_2d_body_entered(body: Node2D) -> void:
	# A blink is already playing (into this battle or elsewhere), so this contact is ignored.
	if TransitionAnimation.is_transitioning:
		return
	if body.name == "AePlaceholder":
		if enemy_id.is_empty():
			push_error("Enemy %s is missing its unique enemy_id" % name)
			return

		State.active_enemy_id = enemy_id
		State.active_enemy_position = global_position
		# Remember where AE stepped from and which way it was moving, in case the party disengages.
		if body is AE:
			State.player_tile_position = body.tile_position
			State.player_direction = body.ae_direction
		# The blink plays, then the battle loads behind it.
		var scene_change_error = TransitionAnimation.change_scene("res://scenes/test/battle/battle.tscn")
		if scene_change_error != OK:
			State.active_enemy_id = &""
			State.active_enemy_position = Vector2.ZERO
			push_error("Failed to load the battle scene: %s" % scene_change_error)
