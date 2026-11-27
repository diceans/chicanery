extends Area2D

# Loads the first-floor scene when the player enters this transition trigger. The blink transition plays around the scene change.
func _on_body_entered(body: Node2D) -> void:
	if body.name == "AePlaceholder":
		TransitionAnimation.change_scene("res://scenes/test/act1/test_scene_player_house_first_floor.tscn")
