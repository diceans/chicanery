extends Area2D

# Returns the player to the outside map whenever they enter this transition area.
func _on_body_entered(body: Node2D) -> void:
	if body.name == "AePlaceholder":
		get_tree().change_scene_to_file("res://scenes/test/act1/test_scene_player_house_outside.tscn")
