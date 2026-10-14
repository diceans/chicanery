extends Node
@onready var anfugel: CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D

@warning_ignore("unused_signal")
signal transition 

func _on_process(_delta : float) -> void:
	pass


func _on_physics_process(_delta : float) -> void:
	pass


func _on_next_transitions() -> void:
	pass


func _on_enter() -> void:
	animated_sprite_2d.play("idle")


func _on_exit() -> void:
	animated_sprite_2d.stop()
