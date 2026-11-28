extends CanvasLayer

# The blink transition between scenes: the overworld transition nodes, entering a battle from an enemy,
# and leaving a battle. This scene is an autoload (TransitionAnimation in project.godot), so it isn't
# freed when the scene changes and can play the second half of the blink over the new scene.
# Callers use TransitionAnimation.change_scene(path) in place of get_tree().change_scene_to_file(path).

# Emitted once the eye has opened again over the new scene.
signal finished

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

# True from the start of the blink until the eye is open again. While it is set, other transition
# triggers are ignored and the pause menu stays shut.
var is_transitioning := false

func _ready() -> void:
	# Hide the sprite on startup so it doesn't block the screen.
	anim_sprite.visible = false

# Starts the blink transition to the target scene and returns straight away, like change_scene_to_file:
# OK if the transition has started, ERR_BUSY if one is already playing, or ERR_FILE_NOT_FOUND if the
# scene doesn't exist. Callers can undo anything they set up for the new scene when it isn't OK.
func change_scene(target_scene_path: String) -> Error:
	if is_transitioning:
		return ERR_BUSY
	if not ResourceLoader.exists(target_scene_path):
		push_error("Scene not found: %s" % target_scene_path)
		return ERR_FILE_NOT_FOUND
	is_transitioning = true
	_play_transition(target_scene_path)
	return OK

# Plays "blink", changes to the target scene once it has finished, then plays "blink" backwards over the new scene.
# The game is paused for the whole transition so nothing moves underneath it. This node keeps running
# because its process_mode is Always.
func _play_transition(target_scene_path: String) -> void:
	var tree := get_tree()
	tree.paused = true
	anim_sprite.visible = true

	anim_sprite.play("blink")
	await anim_sprite.animation_finished

	var scene_change_error := tree.change_scene_to_file(target_scene_path)
	if scene_change_error != OK:
		push_error("Failed to load %s: %s" % [target_scene_path, scene_change_error])
	else:
		# The new scene is added at the end of the frame, so wait until it is the current scene.
		await tree.process_frame
		while tree.current_scene == null:
			await tree.process_frame

	anim_sprite.play_backwards("blink")
	await anim_sprite.animation_finished

	anim_sprite.visible = false
	tree.paused = false
	is_transitioning = false
	finished.emit()
