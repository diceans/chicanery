extends NodeState

@export var character: Walking_NPC
@export var animated_sprite_2d: AnimatedSprite2D
@export var idle_state_time_interval: float = 5.0

@onready var idle_state_timer: Timer = Timer.new()

var idle_state_timeout: bool = false

func _ready() -> void:
	idle_state_timer.wait_time = idle_state_time_interval
	idle_state_timer.one_shot = true
	idle_state_timer.timeout.connect(on_idle_state_timeout)
	add_child(idle_state_timer)

func _on_process(_delta : float) -> void:
	pass


func _on_physics_process(_delta : float) -> void:
	pass


func _on_next_transitions() -> void:
	if idle_state_timeout:
		transition.emit("Walk")


# Keeps facing the direction of the last step while standing still.
func _on_enter() -> void:
	if character.facing == Vector2.UP:
		animated_sprite_2d.play("back")
	elif character.facing == Vector2.LEFT:
		animated_sprite_2d.play("left")
	elif character.facing == Vector2.RIGHT:
		animated_sprite_2d.play("right")
	else:
		animated_sprite_2d.play("front")

	idle_state_timeout = false
	idle_state_timer.start()

func _on_exit() -> void:
	animated_sprite_2d.stop()
	idle_state_timer.stop()

func on_idle_state_timeout() -> void:
	idle_state_timeout = true
