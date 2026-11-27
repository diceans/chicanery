extends Area2D

# Returns the player to the outside map whenever they enter this transition area. The blink transition plays around the scene change.
func _on_body_entered(body: Node2D) -> void:
	if body.name == "AePlaceholder":
		TransitionAnimation.change_scene("res://scenes/test/act1/test_scene_player_house_outside.tscn")
