extends Control
signal textbox_closed
@export var enemy: Resource = null;
var current_player_WN = 0
var current_enemy_WN = 0
var current_player_ERL = 0
var current_enemy_ERL = 0
var d30_player = 0
var d30_enemy = 0
var player_damage = 0
var enemy_damage = 0
var player_exertion = ""
var enemy_exertion = ""
var is_bracing = false
var player_constricted = false
var enemy_constricted = false

func _ready():
	set_WN($EnemyContainer/ProgressBar, enemy.WN, enemy.WN)
	set_player_WN($AeContainer/PlayerPanel/PlayerData/WN, State.current_WN, State.max_WN)
	$EnemyContainer/Enemy.texture = enemy.texture

	current_player_WN = State.current_WN
	current_enemy_WN = enemy.WN
	current_player_ERL = State.ERL
	current_enemy_ERL = enemy.ERL
	
	$Textbox.hide()
	$PlayerName.show()
	$ControlPanel.show()
	
	display_text("%s appears" % enemy.name.to_upper())
	await textbox_closed
	if current_player_WN <= 0:
		await player_defeated()
		return

	if current_player_ERL > current_enemy_ERL:
		$PlayerName.show()
		$ControlPanel.show()
	elif current_player_ERL < current_enemy_ERL:
		enemy_turn()
	else:
		while d30_player == d30_enemy:
			d30_player = randi_range(1, 30)
			d30_enemy = randi_range(1, 30)
			if d30_player > d30_enemy:
				$PlayerName.show()
				$ControlPanel.show()
			elif d30_player < d30_enemy:
				enemy_turn()
		
	
func set_WN(progress_bar, WN, max_WN):
	progress_bar.value = WN
	progress_bar.max_value = max_WN
	progress_bar.get_node("Label").text = "%d/%d" % [WN, max_WN]

func set_player_WN(condition_label: Label, WN: int, max_WN: int) -> void:
	condition_label.text = "WN: %d/%d" % [WN, max_WN]
	
func set_condition(condition_label: Label, condition: String) -> void:
	condition_label.text = "%s" % condition
	
func _input(event):
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and $Textbox.visible:
		$Textbox.hide()
		textbox_closed.emit()

func display_text(text):
	$ControlPanel.hide()
	$PlayerName.hide()
	$Textbox.show()
	$Textbox/Message.text = text
	
func enemy_turn():
	display_text("%s attacks" % enemy.name)
	await textbox_closed
	enemy_exertion = enemy.exertions.pick_random()
	if enemy_exertion == "ROCK":
		display_text("%s used ROCK" % [enemy.name])
		await textbox_closed
		var available_exertions = enemy.exertions.filter(func(exertion): return exertion != "ROCK")
		if available_exertions.is_empty():
			push_error("Enemy %s has no non-ROCK exertions to select" % enemy.name)
			$PlayerName.show()
			$ControlPanel.show()
			return
		enemy_exertion = available_exertions.pick_random()
		player_constricted = true
		constricted()
	if enemy_exertion == "PINK":
		if is_bracing:
			is_bracing = false
			enemy.pi_tDIM = randf_range(0.46, 0.54)
			enemy_damage = int(enemy.VHM * enemy.pi_tDIM)
		else:
			enemy_damage = int(enemy.VHM)
		current_player_WN = max(0, current_player_WN - enemy_damage)
		set_player_WN($AeContainer/PlayerPanel/PlayerData/WN, current_player_WN, State.max_WN)
		display_text("%s used PINK" % [enemy.name])
		await textbox_closed
		if current_player_WN <= 0:
			await player_defeated()
			return
		player_constricted = false
		constricted()

func player_defeated() -> void:
	display_text("u is slimed out")
	await textbox_closed

	State.current_WN = State.max_WN
	var scene_change_error = get_tree().change_scene_to_file("res://scenes/test/test_scene/test_scene_player_house_first_floor.tscn")
	if scene_change_error != OK:
		push_error("Failed to load the first-floor scene: %s" % scene_change_error)

func constricted():
	var condition_label: Label = $AeContainer/PlayerPanel/PlayerData/Condition
	if player_constricted:
		set_condition(condition_label, "CONSTRICTED")
		$ControlPanel.hide()
		$PlayerName.hide()
	else:
		set_condition(condition_label, "")
		$ControlPanel.show()
		$PlayerName.hide()
		

func _on_assault_pressed() -> void:
	display_text("U swung")
	await textbox_closed
	
	var DV = randf_range(0.95, 1.05)
	player_damage = roundi((State.VHM + State.EB) * State.EM * State.pi_ACM * DV)
	current_enemy_WN = max(0, current_enemy_WN - player_damage)
	set_WN($EnemyContainer/ProgressBar, current_enemy_WN, enemy.WN)
	
	$AnimationPlayer.play("enemy_damaged")
	await $AnimationPlayer.animation_finished
	
	display_text("U dealt %d damage" % player_damage)
	await textbox_closed
	
	if current_enemy_WN == 0:
		display_text("%s is slimed out" % enemy.name)
		await textbox_closed
		
		$AnimationPlayer.play("enemy_dead")
		await $AnimationPlayer.animation_finished
		
		if State.active_enemy_id.is_empty():
			push_error("Cannot record victory: active enemy ID is empty")
			return

		var scene_tree: SceneTree = get_tree()
		await scene_tree.create_timer(0.25).timeout
		State.return_player_to_anfugel = true
		State.current_WN = current_player_WN
		var scene_change_error = scene_tree.change_scene_to_file("res://scenes/test/test_scene/test_scene_player_house_outside.tscn")
		if scene_change_error != OK:
			State.return_player_to_anfugel = false
			push_error("Failed to load the outside scene: %s" % scene_change_error)
			return

		State.defeated_enemy_ids[State.active_enemy_id] = true
		return
	
	enemy_turn()


func _on_brace_pressed() -> void:
	display_text("U braced successfully")
	await textbox_closed
	is_bracing = true
	var condition_label: Label = $AeContainer/PlayerPanel/PlayerData/Condition
	set_condition(condition_label, "BRACING")
	enemy_turn()
