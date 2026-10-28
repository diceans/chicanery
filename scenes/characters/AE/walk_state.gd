extends NodeState

@export var player: AE
@export var animate_sprite_2d: AnimatedSprite2D
@export var speed: int = 300

# Runs any frame-based logic while the character is walking.
func _on_process(_delta : float) -> void:
	pass


# Applies movement, animation, and sprint logic during the physics tick.
func _on_physics_process(_delta : float) -> void:
	var direction: Vector2 = GameInputEvents.movement_input()
	var is_sprint: bool = GameInputEvents.check_sprint()
	
	if direction == Vector2.UP:
		animate_sprite_2d.play("walk_back")
	elif direction == Vector2.DOWN:
		animate_sprite_2d.play("walk_front")
	elif direction == Vector2.LEFT:
		animate_sprite_2d.play("walk_left")
	elif direction == Vector2.RIGHT:
		animate_sprite_2d.play("walk_right")
	
	if direction != Vector2.ZERO:
		player.ae_direction = direction
	
	if is_sprint:
		speed = 600
	else:
		speed = 300
	
	player.velocity = direction * speed
	player.move_and_slide()

# Returns to the idle state when no movement input is present.
func _on_next_transitions() -> void:
	if !GameInputEvents.is_movement_input():
		transition.emit("idle")


# Prepares the walking state when it is activated.
func _on_enter() -> void:
	pass


# Stops the walking animation when the state ends.
func _on_exit() -> void:
	animate_sprite_2d.stop()
