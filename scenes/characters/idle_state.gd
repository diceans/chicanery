extends NodeState

@export var player: AE
@export var animate_sprite_2d: AnimatedSprite2D

var direction: Vector2

func _on_process(_delta : float) -> void:
	pass

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


func _on_next_transitions() -> void:
	GameInputEvents.movement_input()
	
	if GameInputEvents.movement_input():
		transition.emit("Walk")

	
func _on_enter() -> void:
	pass


func _on_exit() -> void:
	animate_sprite_2d.stop()
