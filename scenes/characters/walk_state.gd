extends NodeState

@export var player: AE
@export var animate_sprite_2d: AnimatedSprite2D
@export var speed: int = 300

func _on_process(_delta : float) -> void:
	pass


func _on_physics_process(_delta : float) -> void:
	var direction: Vector2 = GameInputEvents.movement_input()
	
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
	
	player.velocity = direction * speed
	player.move_and_slide()

func _on_next_transitions() -> void:
	if !GameInputEvents.is_movement_input():
		transition.emit("idle")


func _on_enter() -> void:
	pass


func _on_exit() -> void:
	animate_sprite_2d.stop()
