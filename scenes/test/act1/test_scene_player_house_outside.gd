extends Node2D
@export var ally: Resource = null

var player_near_elizyka: bool = false

# Initializes the outside scene, restores the player to the defeated enemy's location if needed, and removes cleared enemies.
func _ready() -> void:
	$AePlaceholder/Dialogue.hide()
	var ally_spawnpoint: Variant = spawnpoint(ally)
	if not (ally_spawnpoint is Vector2):
		return
	$Elizyka.position = ally_spawnpoint
	var returning_from_battle: bool = State.return_player_to_enemy
	State.return_player_to_enemy = false

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

# Chooses a random spawn point from the ally resource so Elizyka appears in a valid starting position.
func spawnpoint(ally_resource: Resource) -> Variant:
	if ally_resource == null:
		push_error("Cannot choose a spawnpoint: no ally resource is assigned")
		return null

	var spawnpoints: Variant = ally_resource.get("spawnpoints")
	if not spawnpoints is Array or spawnpoints.is_empty():
		push_error("Cannot choose a spawnpoint: ally resource has no spawnpoints")
		return null

	var spawn: Variant = spawnpoints.pick_random()
	if not spawn is Vector2:
		push_error("Cannot choose a spawnpoint: ally spawnpoints must contain Vector2 values")
		return null
	return spawn


# Shows the dialogue box with the provided text so narrative or interaction prompts appear in the world scene.
func display_text(text):
	$AePlaceholder/Dialogue.show()
	$AePlaceholder/Dialogue/Message.text = text


# Tracks whether the player is close enough to Elizyka to interact with her.
func _on_elizyka_body_entered(body: Node2D) -> void:
	if body.name == "AePlaceholder":
		player_near_elizyka = true


# Clears the interaction state when the player moves away from Elizyka.
func _on_elizyka_body_exited(body: Node2D) -> void:
	if body.name == "AePlaceholder":
		player_near_elizyka = false
		$AePlaceholder/Dialogue.hide()


# Handles world interaction input while the player is near Elizyka.
func _unhandled_input(event: InputEvent) -> void:
	if player_near_elizyka and event.is_action_pressed("interact") and not event.is_echo():
		display_text("Smoke weed everyday")
		get_viewport().set_input_as_handled()
		
# Dismisses dialogue boxes with the accept key after interaction prompts are shown.
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	if $AePlaceholder/Dialogue.visible:
		if event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			$AePlaceholder/Dialogue.hide()
		return
