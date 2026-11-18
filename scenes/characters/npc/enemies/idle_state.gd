extends Node
@onready var anfugel: CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D

@warning_ignore("unused_signal")
signal transition 

# Runs any per-frame logic while the NPC is idle.
func _on_process(_delta : float) -> void:
	pass


# Keeps the NPC idle state visually stable during physics updates.
func _on_physics_process(_delta : float) -> void:
	pass


# Checks whether the NPC should leave idle and transition to another state.
func _on_next_transitions() -> void:
	pass


# Starts the idle animation when the NPC enters this state.
func _on_enter() -> void:
	animated_sprite_2d.play("idle")


# Stops the idle animation when the NPC leaves this state.
func _on_exit() -> void:
	animated_sprite_2d.stop()
