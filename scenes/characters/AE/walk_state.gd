extends NodeState

@export var player: AE
@export var animate_sprite_2d: AnimatedSprite2D
@export var speed: int = 400
@export var tile_size: int = 120

var target_position: Vector2
var is_stepping: bool = false

func _ready() -> void:
	player.bumped.connect(_cancel_step)

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
		player.reserved_tiles.clear()
		_try_start_step(GameInputEvents.movement_input())
	else:
		player.velocity = remaining.normalized() * speed
		player.move_and_slide()
		_check_npc_bump()

# Fallback only: tile reservations stop AE and NPCs from stepping into each other's path. If they
# somehow still collide mid-step, both go back to the tile they stepped from so neither keeps pushing
# into the other, and the NPC rests before walking again.
func _check_npc_bump() -> void:
	for i in player.get_slide_collision_count():
		var other: Object = player.get_slide_collision(i).get_collider()
		if other is Walking_NPC:
			_cancel_step()
			other.bumped.emit()
			return

# Stops the current step and puts AE back on the tile it started from, keeping AE on the movement grid.
func _cancel_step() -> void:
	if not is_stepping:
		return
	player.global_position = player.tile_position
	player.velocity = Vector2.ZERO
	is_stepping = false
	player.reserved_tiles.clear()
	animate_sprite_2d.stop()


# Faces the given direction and begins a step to the neighbouring tile unless a wall is in the way,
# or a walking NPC has reserved that tile for its own step (the tile it's leaving or the one it's entering).
# A blocked step leaves AE facing that way, and it tries again next frame while the key is held.
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
	var next_tile: Vector2 = player.global_position + offset
	if player.test_move(player.global_transform, offset) or GridReservations.is_reserved(player, next_tile, tile_size):
		animate_sprite_2d.stop()
		return
	player.tile_position = player.global_position
	target_position = next_tile
	player.reserved_tiles = [player.global_position, next_tile]
	is_stepping = true

# Returns to the idle state once the current step is finished and no movement input is present.
func _on_next_transitions() -> void:
	if not is_stepping and !GameInputEvents.is_movement_input():
		transition.emit("idle")


# Prepares the walking state when it is activated.
func _on_enter() -> void:
	is_stepping = false
	player.reserved_tiles.clear()


# Stops the walking animation when the state ends.
func _on_exit() -> void:
	is_stepping = false
	player.reserved_tiles.clear()
	animate_sprite_2d.stop()
