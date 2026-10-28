class_name NodeState
extends Node

@warning_ignore("unused_signal")
signal transition 

# Runs per-frame logic for the state while it is active.
func _on_process(_delta : float) -> void:
	pass


# Runs physics-based updates for the state during the fixed-step physics loop.
func _on_physics_process(_delta : float) -> void:
	pass


# Evaluates whether the state should transition to another state.
func _on_next_transitions() -> void:
	pass


# Sets up the state when it becomes active.
func _on_enter() -> void:
	pass


# Cleans up the state when leaving it.
func _on_exit() -> void:
	pass
