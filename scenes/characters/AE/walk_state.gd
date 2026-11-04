extends NodeState

@export var player: AE
@export var animate_sprite_2d: AnimatedSprite2D
@export var speed: int = 400
@export var tile_size: int = 120

var target_position: Vector2
var is_stepping: bool = false

# Runs any frame-based logic while the character is walking.
func _on_process(_delta : float) -> void:
	pass


# Moves the player one tile at a time: a step is committed to on key press and always finishes
# on the next tile, then chains into another step if a direction is still held.
func _on_physics_process(delta : float) -> void:
	var is_sprint: bool = GameInputEvents.check_sprint()
	speed = 700 if is_sprint else 400

	if not is_stepping:
		_try_start_step(GameInputEvents.movement_input())
	if not is_stepping:
		return

	var remaining: Vector2 = target_position - player.global_position
	var step_length: float = speed * delta
	if remaining.length() <= step_length:
		# Snap onto the tile and immediately continue if a direction is still held.
		player.global_position = target_position
		player.velocity = Vector2.ZERO
		is_stepping = false
		_try_start_step(GameInputEvents.movement_input())
	else:
		player.velocity = remaining.normalized() * speed
		player.move_and_slide()


# Faces the given direction and begins a step to the neighbouring tile unless a wall is in the way.
func _try_start_step(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	player.ae_direction = direction

	if direction == Vector2.UP:
		animate_sprite_2d.play("walk_back")
	elif direction == Vector2.DOWN:
		animate_sprite_2d.play("walk_front")
	elif direction == Vector2.LEFT:
		animate_sprite_2d.play("walk_left")
	elif direction == Vector2.RIGHT:
		animate_sprite_2d.play("walk_right")

	var offset: Vector2 = direction * tile_size
	if player.test_move(player.global_transform, offset):
		animate_sprite_2d.stop()
		return
	target_position = player.global_position + offset
	is_stepping = true

# Returns to the idle state once the current step is finished and no movement input is present.
func _on_next_transitions() -> void:
	if not is_stepping and !GameInputEvents.is_movement_input():
		transition.emit("idle")


# Prepares the walking state when it is activated.
func _on_enter() -> void:
	is_stepping = false


# Stops the walking animation when the state ends.
func _on_exit() -> void:
	is_stepping = false
	animate_sprite_2d.stop()
