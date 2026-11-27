extends NodeState

@export var character: Walking_NPC
@export var animated_sprite_2d: AnimatedSprite2D
@export var navigation_agent_2d: NavigationAgent2D
@export var min_speed: float = 100.0
@export var max_speed: float = 200.0
@export var tile_size: int = 120

var speed: float
var grid_origin: Vector2
var walk_target: Vector2
var step_target: Vector2
# The tile the current step started from, where the NPC goes back to if it bumps into AE.
var step_origin: Vector2
var is_stepping: bool = false

# Remembers where the NPC was placed so every tile it walks to lines up with that starting spot.
func _ready() -> void:
	grid_origin = character.global_position
	character.bumped.connect(_on_bumped)

# Picks a random point inside the navigation region, snapped to the tile grid, as the next place to walk to.
func set_movement_target() -> void:
	var random_point: Vector2 = NavigationServer2D.map_get_random_point(navigation_agent_2d.get_navigation_map(), navigation_agent_2d.navigation_layers, false)
	walk_target = grid_origin + ((random_point - grid_origin) / tile_size).round() * tile_size
	speed = randf_range(min_speed, max_speed)

func _on_process(_delta : float) -> void:
	pass


# Walks toward the target one tile at a time, the same way AE moves. A walk cycle ends when the
# target is reached or when the next tile is blocked, in which case the NPC stops where it is.
func _on_physics_process(delta : float) -> void:
	# After a bump the walk is over; wait for _on_next_transitions to switch to Idle instead of stepping again.
	if not is_stepping and character.current_walk_cycles >= character.walk_cycles:
		return
	if not is_stepping:
		var remaining_to_target: Vector2 = walk_target - character.global_position
		if remaining_to_target.length() < 1.0 or not _try_start_step(_next_direction(remaining_to_target)):
			character.current_walk_cycles += 1
			set_movement_target()
			return

	var remaining: Vector2 = step_target - character.global_position
	var step_length: float = speed * delta
	if remaining.length() <= step_length:
		character.global_position = step_target
		character.velocity = Vector2.ZERO
		is_stepping = false
		character.reserved_tiles.clear()
	else:
		character.velocity = remaining.normalized() * speed
		character.move_and_slide()
		_check_player_bump()

# Fallback only: tile reservations should stop the NPC stepping into AE's path. If they somehow still
# collide mid-step, both go back to where their steps began, as in AE's walk state.
func _check_player_bump() -> void:
	for i in character.get_slide_collision_count():
		var other: Object = character.get_slide_collision(i).get_collider()
		if other is AE:
			_on_bumped()
			other.bumped.emit()
			return

# Stops the current step, puts the NPC back on the tile it started from, and ends its walk so it
# rests in Idle before picking a new target, instead of stepping straight back into AE.
func _on_bumped() -> void:
	if not is_stepping:
		return
	character.global_position = step_origin
	character.velocity = Vector2.ZERO
	is_stepping = false
	character.reserved_tiles.clear()
	character.current_walk_cycles = character.walk_cycles

# Chooses the next grid direction toward the target, moving along the longer axis first.
func _next_direction(remaining: Vector2) -> Vector2:
	if abs(remaining.x) >= abs(remaining.y):
		return Vector2.RIGHT if remaining.x > 0 else Vector2.LEFT
	return Vector2.DOWN if remaining.y > 0 else Vector2.UP

# Faces the given direction and starts a step to the neighbouring tile. Returns false if an obstacle is
# in the way, or if AE (or another walking NPC) has reserved that tile for its current step, so the NPC
# stops before walking into AE's next tile. A blocked step ends the walk cycle, as a wall does.
func _try_start_step(direction: Vector2) -> bool:
	character.facing = direction
	animated_sprite_2d.play(_animation_for(direction))
	var offset: Vector2 = direction * tile_size
	var next_tile: Vector2 = character.global_position + offset
	if character.test_move(character.global_transform, offset) or GridReservations.is_reserved(character, next_tile, tile_size):
		return false
	step_origin = character.global_position
	step_target = next_tile
	character.reserved_tiles = [step_origin, step_target]
	is_stepping = true
	return true

# Maps a direction to Nickel's matching animation.
func _animation_for(direction: Vector2) -> String:
	if direction == Vector2.UP:
		return "back"
	if direction == Vector2.LEFT:
		return "left"
	if direction == Vector2.RIGHT:
		return "right"
	return "front"

# Returns to idle once enough walk cycles are done, but only between steps so the NPC always rests on a tile.
func _on_next_transitions() -> void:
	if not is_stepping and character.current_walk_cycles >= character.walk_cycles:
		character.velocity = Vector2.ZERO
		transition.emit("Idle")

func _on_enter() -> void:
	character.current_walk_cycles = 0
	character.walk_cycles = randi_range(character.min_walk_cycle, character.max_walk_cycle)
	is_stepping = false
	character.reserved_tiles.clear()
	set_movement_target()


func _on_exit() -> void:
	is_stepping = false
	character.reserved_tiles.clear()
	animated_sprite_2d.stop()
