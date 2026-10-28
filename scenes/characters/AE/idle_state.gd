extends NodeState

@export var player: AE
@export var animate_sprite_2d: AnimatedSprite2D

var direction: Vector2

# Runs any frame-based logic while the player is standing still.
func _on_process(_delta : float) -> void:
	pass

# Updates the idle facing animation based on the last movement direction.
func _on_physics_process(_delta : float) -> void:
	if player.ae_direction == Vector2.UP:
		animate_sprite_2d.play("idle_back")
	elif player.ae_direction == Vector2.DOWN:
		animate_sprite_2d.play("idle_front")
	elif player.ae_direction == Vector2.LEFT:
		animate_sprite_2d.play("idle_left")
	elif player.ae_direction == Vector2.RIGHT:
		animate_sprite_2d.play("idle_right")
	else:
		animate_sprite_2d.play("idle_front")


# Transitions from idle to the walking state whenever movement input is detected.
func _on_next_transitions() -> void:
	GameInputEvents.movement_input()
	
	if GameInputEvents.movement_input():
		transition.emit("Walk")

	
# Initializes the idle state when it becomes active.
func _on_enter() -> void:
	pass


# Stops the idle animation when leaving the state.
func _on_exit() -> void:
	animate_sprite_2d.stop()
