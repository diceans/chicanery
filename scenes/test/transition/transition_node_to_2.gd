extends Area2D

# Loads the second-floor scene when the player steps into this transition volume.
func _on_body_entered(body: Node2D) -> void:
	if body.name == "AePlaceholder":
		get_tree().change_scene_to_file("res://scenes/test/act1/test_scene_player_house_second_floor.tscn")
