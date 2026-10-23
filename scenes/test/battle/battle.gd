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
var action_index = 0
var exertion_index = 0
var action_buttons: Array[Button] = []
var exertion_buttons: Array[Button] = []
var menu_button_font_colors: Dictionary = {}
var is_bracing = false
var player_constricted = false
var enemy_constricted = false

func _ready():
	action_buttons = _get_menu_buttons($ControlPanel/HBoxContainer, State.actions.size())
	exertion_buttons = _get_menu_buttons($ExertPanel/HBoxContainer, State.exertions.size())
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
	$ExertPanel.hide()
	$DescriptionPanel.hide()
	_refresh_menu_selection()
	
	display_text("%s appears" % enemy.name.to_upper())
	await textbox_closed
	if current_player_WN <= 0:
		await player_defeated()
		return

	if current_player_ERL > current_enemy_ERL:
		$PlayerName.show()
		$ControlPanel.show()
		_refresh_menu_selection()
	elif current_player_ERL < current_enemy_ERL:
		enemy_turn()
	else:
		while d30_player == d30_enemy:
			d30_player = randi_range(1, 30)
			d30_enemy = randi_range(1, 30)
			if d30_player > d30_enemy:
				$PlayerName.show()
				$ControlPanel.show()
				_refresh_menu_selection()
			elif d30_player < d30_enemy:
				enemy_turn()
		
	
func _get_menu_buttons(container: Node, item_count: int) -> Array[Button]:
	var buttons: Array[Button] = []
	for child in container.get_children():
		if child is Button and buttons.size() < item_count:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			menu_button_font_colors[child] = child.get_theme_color("font_color")
			buttons.append(child)
	if buttons.size() != item_count:
		push_error("Menu button count does not match its State list")
	return buttons

func _get_active_menu_buttons() -> Array[Button]:
	if $ExertPanel.visible:
		return exertion_buttons
	if $ControlPanel.visible:
		return action_buttons
	return []

func _refresh_menu_selection() -> void:
	for button in action_buttons + exertion_buttons:
		button.offset_transform_position = Vector2(16, 0)
		button.add_theme_color_override("font_color", menu_button_font_colors[button])

	$Arrow.hide()
	$Arrow.scale = Vector2.ONE
	if $Textbox.visible:
		return

	var buttons := _get_active_menu_buttons()
	if buttons.is_empty():
		return

	var selected_index = exertion_index if $ExertPanel.visible else action_index
	selected_index = posmod(selected_index, buttons.size())
	if $ExertPanel.visible:
		exertion_index = selected_index
	else:
		action_index = selected_index

	var selected_button = buttons[selected_index]
	selected_button.offset_transform_position = Vector2(2, 0)
	selected_button.add_theme_color_override("font_color", Color("#FFFF00"))
	if $ExertPanel.visible:
		$Arrow.scale = Vector2(0.8, 0.8)
	var button_rect = selected_button.get_global_rect()
	$Arrow.global_position = Vector2(button_rect.position.x + 450, button_rect.get_center().y)
	$Arrow.show()

func set_WN(progress_bar, WN, max_WN):
	progress_bar.value = WN
	progress_bar.max_value = max_WN
	progress_bar.get_node("Label").text = "%d/%d" % [WN, max_WN]

func set_player_WN(condition_label: Label, WN: int, max_WN: int) -> void:
	condition_label.text = "WN: %d/%d" % [WN, max_WN]
	
func set_condition(condition_label: Label, condition: String) -> void:
	condition_label.text = "%s" % condition
	
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	if $Textbox.visible:
		if event.is_action_pressed("ui_accept"):
			var viewport := get_viewport()
			if viewport == null:
				return
			viewport.set_input_as_handled()
			$Textbox.hide()
			_refresh_menu_selection()
			textbox_closed.emit()
		return

	var buttons := _get_active_menu_buttons()
	if buttons.is_empty():
		return

	var is_exertion_menu = $ExertPanel.visible
	var selected_index = exertion_index if is_exertion_menu else action_index
	if event.is_action_pressed("ui_up"):
		selected_index = posmod(selected_index - 1, buttons.size())
	elif event.is_action_pressed("ui_down"):
		selected_index = posmod(selected_index + 1, buttons.size())
	elif event.is_action_pressed("ui_accept"):
		var viewport := get_viewport()
		if viewport == null:
			return
		viewport.set_input_as_handled()
		buttons[selected_index].emit_signal("pressed")
		return
	else:
		return

	if is_exertion_menu:
		exertion_index = selected_index
	else:
		action_index = selected_index
	_refresh_menu_selection()
	get_viewport().set_input_as_handled()

func display_text(text):
	$ControlPanel.hide()
	$PlayerName.hide()
	$Textbox.show()
	$Textbox/Message.text = text
	_refresh_menu_selection()
	
func enemy_turn():
	display_text("%s attacks" % enemy.name)
	await textbox_closed
	enemy_exertion = enemy.exertions.pick_random()
	if enemy_exertion == "ROCK":
		display_text("%s used ROCK" % [enemy.name])
		await textbox_closed
		var available_exertions = enemy.exertions.filter(func(exertion): return exertion != "ROCK")
		enemy_exertion = available_exertions.pick_random()
		player_constricted = true
		constricted()
	if enemy_exertion == "PINK":
		enemy_damage = int(enemy.VHM)
		display_text("%s used PINK" % [enemy.name])
		await textbox_closed
		player_constricted = false
		constricted()
	if is_bracing:
		is_bracing = false
		enemy.pi_tDIM = randf_range(0.46, 0.54)
		enemy_damage = int(enemy.VHM * enemy.pi_tDIM)
	current_player_WN = max(0, current_player_WN - enemy_damage)
	set_player_WN($AeContainer/PlayerPanel/PlayerData/WN, current_player_WN, State.max_WN)
	if current_player_WN <= 0:
		await player_defeated()
		return

func player_defeated() -> void:
	display_text("u is slimed out")
	await textbox_closed

	State.current_WN = State.max_WN
	var scene_change_error = get_tree().change_scene_to_file("res://scenes/test/scene/test_scene_player_house_first_floor.tscn")
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
		$PlayerName.show()
		$ExertPanel.hide()
	_refresh_menu_selection()
		
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
		var scene_change_error = scene_tree.change_scene_to_file("res://scenes/test/scene/test_scene_player_house_outside.tscn")
		if scene_change_error != OK:
			State.return_player_to_anfugel = false
			push_error("Failed to load the outside scene: %s" % scene_change_error)
			return

		State.defeated_enemy_ids[State.active_enemy_id] = true
		return
	
	enemy_turn()


func _on_brace_pressed() -> void:
	display_text("U braced")
	await textbox_closed
	is_bracing = true
	var condition_label: Label = $AeContainer/PlayerPanel/PlayerData/Condition
	set_condition(condition_label, "BRACING")
	enemy_turn()


func _on_exert_pressed() -> void:
	$ControlPanel.hide()
	$ExertPanel.show()
	$DescriptionPanel.show()
	exertion_index = 0
	_refresh_menu_selection()

func _on_forbear_pressed() -> void:
	$ExertPanel.hide()
	$DescriptionPanel.hide()
	_refresh_menu_selection()
	display_text("U forbore")
	await textbox_closed
	enemy_turn()

func _on_forsake_pressed() -> void:
	$ExertPanel.hide()
	$DescriptionPanel.hide()
	_refresh_menu_selection()
	display_text("U forsook")
	await textbox_closed
	enemy_turn()

func _on_foredoom_pressed() -> void:
	$ExertPanel.hide()
	$DescriptionPanel.hide()
	_refresh_menu_selection()
	display_text("U fordoomed")
	await textbox_closed
	current_player_WN = 0
	set_player_WN($AeContainer/PlayerPanel/PlayerData/WN, current_player_WN, State.max_WN)
	if current_player_WN <= 0:
		await player_defeated()
		return
