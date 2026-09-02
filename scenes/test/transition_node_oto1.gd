extends Area2D


func _on_body_entered(body: Node2D) -> void:
	if body.name == "AePlaceholder":
		get_tree().change_scene_to_file("res://scenes/test/test_scene_player_house_first_floor.tscn")
