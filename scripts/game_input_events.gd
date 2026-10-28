class_name GameInputEvents

static var direction: Vector2
static var is_sprint: bool
static var is_interact: bool

# Reads the current movement key input and converts it into a directional vector for the player.
static func movement_input() -> Vector2:
	
	if Input.is_action_pressed("walk_up"):
		direction = Vector2.UP
	elif Input.is_action_pressed("walk_down"):
		direction = Vector2.DOWN
	elif Input.is_action_pressed("walk_left"):
		direction = Vector2.LEFT
	elif Input.is_action_pressed("walk_right"):
		direction = Vector2.RIGHT
	else:
		direction = Vector2.ZERO

	return direction

# Checks whether sprint input is currently held down and returns the resulting boolean.
static func check_sprint():
	if Input.is_action_pressed("sprint"):
		is_sprint = true
	else:
		is_sprint = false
	return is_sprint

# Checks whether interact input is currently being pressed.
static func check_interact():
	if Input.is_action_pressed("interact"):
		is_interact = true
	else:
		is_interact = false
	return is_interact

# Returns whether the current movement vector represents a non-zero movement input.
static func is_movement_input() -> bool:
	if direction == Vector2.ZERO:
		return false
	else:
		return true
