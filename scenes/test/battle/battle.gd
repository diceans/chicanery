extends Control
signal textbox_closed
@export var enemy: Resource = null;
# Tracks battle values, menu selection, and the active status effect.
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
var previous_enemy_exertion = ""
var action_index = 0
var exertion_index = 0
var action_buttons: Array[Button] = []
var exertion_buttons: Array[Button] = []
var menu_button_font_colors: Dictionary = {}
var condition: StatusEffect = null
var condition_turns_remaining: int = 0
var bracing_pending: bool = false
@onready var condition_icon: TextureRect = $AeContainer/ConditionIcon

# Initializes the battle UI and selects which side acts first.
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
	check_condition()
	
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
		# Break equal-ERL ties with d30 rolls.
		while d30_player == d30_enemy:
			d30_player = randi_range(1, 30)
			d30_enemy = randi_range(1, 30)
			if d30_player > d30_enemy:
				$PlayerName.show()
				$ControlPanel.show()
				_refresh_menu_selection()
			elif d30_player < d30_enemy:
				enemy_turn()
		
	
# Collects menu buttons for keyboard navigation and stores their default colors.
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

# Returns the buttons in the currently visible action menu.
func _get_active_menu_buttons() -> Array[Button]:
	if $ExertPanel.visible:
		return exertion_buttons
	if $ControlPanel.visible:
		return action_buttons
	return []

# Resets menu highlighting and positions the selection arrow on the active item.
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

# Updates an enemy health bar and its numeric label.
func set_WN(progress_bar, WN, max_WN):
	progress_bar.value = WN
	progress_bar.max_value = max_WN
	progress_bar.get_node("Label").text = "%d/%d" % [WN, max_WN]

# Updates the player's WN label.
func set_player_WN(condition_label: Label, WN: int, max_WN: int) -> void:
	condition_label.text = "WN: %d/%d" % [WN, max_WN]
	
# Sets the text shown for the player's active condition.
func set_condition(condition_label: Label, condition: String) -> void:
	condition_label.text = "%s" % condition

# Replaces the active effect and preserves a pending brace if another effect overwrites it.
func _apply_condition(condition_path: String) -> void:
	if condition != null and condition.custom_properties.get("is_bracing", false):
		bracing_pending = true
	_set_condition_active(condition, false)
	condition = null
	if not condition_path.is_empty():
		condition = load(condition_path) as StatusEffect
		if condition == null:
			push_error("Failed to load status effect: %s" % condition_path)
			condition_turns_remaining = 0
			check_condition()
			return
	_set_condition_active(condition, true)
	condition_turns_remaining = condition.duration_turns if condition != null else 0
	check_condition()

# Updates activation flags defined by the status-effect resource.
func _set_condition_active(status_effect: StatusEffect, is_active: bool) -> void:
	if status_effect == null:
		return
	for property_name in ["is_bracing", "is_constricted"]:
		if status_effect.custom_properties.has(property_name):
			status_effect.custom_properties[property_name] = is_active

# Updates the condition label/icon and applies any condition-specific menu restrictions.
func check_condition() -> void:
	var condition_label: Label = $AeContainer/PlayerPanel/PlayerData/Condition
	if condition == null or condition_turns_remaining <= 0:
		_set_condition_active(condition, false)
		condition = null
		condition_turns_remaining = 0
		set_condition(condition_label, "")
		condition_icon.hide()
	else:
		set_condition(condition_label, condition.effect_name)
		var icon_image := condition.icon.get_image()
		if icon_image == null or icon_image.is_empty():
			push_error("Condition icon has no image data: %s" % condition.effect_name)
			condition_icon.hide()
		else:
			# Crop transparent padding to make the artwork visible at UI size.
			var icon_texture := AtlasTexture.new()
			icon_texture.atlas = condition.icon
			icon_texture.region = Rect2(icon_image.get_used_rect())
			condition_icon.texture = icon_texture
			_position_condition_icon()
			condition_icon.show()

	var is_constricted = condition != null and condition.custom_properties.get("is_constricted", false)
	if is_constricted:
		$ControlPanel.hide()
		$PlayerName.hide()
	else:
		$ControlPanel.show()
		$PlayerName.show()
		$ExertPanel.hide()
		$DescriptionPanel.hide()
	_refresh_menu_selection()

# Scales and aligns the condition icon to the upper-right of the player portrait.
func _position_condition_icon() -> void:
	var avatar_rect: TextureRect = $AeContainer/TextureRect
	condition_icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	condition_icon.size = Vector2(48, 48)
	condition_icon.scale = Vector2(0.3, 0.3)
	condition_icon.position = avatar_rect.position + Vector2(
		avatar_rect.size.x - condition_icon.size.x * condition_icon.scale.x,
		0
	)

# Decrements the duration if the same condition stayed active during this enemy turn.
func _advance_condition_turn(condition_at_turn_start: StatusEffect) -> void:
	if condition == null or condition != condition_at_turn_start:
		return
	condition_turns_remaining -= 1
	check_condition()
	
# Handles textbox dismissal and keyboard navigation/selection in the menus.
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

# Displays a message and hides the action controls until the textbox is dismissed.
func display_text(text):
	$ControlPanel.hide()
	$PlayerName.hide()
	$Textbox.show()
	$Textbox/Message.text = text
	_refresh_menu_selection()
	
# Selects and resolves an enemy exertion, repeating enemy turns while constriction holds.
func enemy_turn():
	display_text("%s attacks" % enemy.name)
	await textbox_closed
	enemy_damage = 0
	# Use a turn-local list so a ROCK reroll does not modify the enemy resource.
	var available_exertions: Array = enemy.exertions.duplicate()
	if available_exertions.is_empty():
		push_error("%s has no available exertions" % enemy.name)
		return
	enemy_exertion = available_exertions.pick_random()
	if enemy_exertion == "ROCK" and previous_enemy_exertion == "ROCK":
		while available_exertions.has("ROCK"):
			available_exertions.erase("ROCK")
		if available_exertions.is_empty():
			push_error("%s has no alternative exertion after ROCK" % enemy.name)
			return
		enemy_exertion = available_exertions.pick_random()
	previous_enemy_exertion = enemy_exertion
	display_text("%s used %s" % [enemy.name, enemy_exertion])
	await textbox_closed
	var condition_at_turn_start = condition
	var was_bracing = bracing_pending or (
		condition != null and condition.custom_properties.get("is_bracing", false)
	)
	# ROCK applies constriction but is not an offensive, damaging exertion.
	if enemy_exertion == "ROCK":
		_apply_condition("res://scripts/res/conditions/constricted.tres")
	if enemy_exertion == "PINK":
		enemy_damage = int(enemy.VHM)
		_apply_condition("")
	# Carry brace through ROCK, but only reduce damage on an offensive exertion.
	if was_bracing and enemy_exertion != "ROCK":
		enemy.pi_tDIM = randf_range(0.46, 0.54)
		var bracing_effect := load("res://scripts/res/conditions/bracing.tres") as StatusEffect
		if bracing_effect == null:
			push_error("Failed to load the bracing status effect")
			return
		bracing_effect.stat_multipliers["pi_tDIM"] = enemy.pi_tDIM
		enemy_damage = int(enemy.VHM * enemy.pi_tDIM)
		bracing_pending = false
	current_player_WN = max(0, current_player_WN - enemy_damage)
	set_player_WN($AeContainer/PlayerPanel/PlayerData/WN, current_player_WN, State.max_WN)
	_advance_condition_turn(condition_at_turn_start)
	if current_player_WN <= 0:
		await player_defeated()
		return
	if condition != null and condition.custom_properties.get("is_constricted", false):
		await enemy_turn()

# Displays defeat text, restores player WN, and returns to the first-floor scene.
func player_defeated() -> void:
	display_text("u is slimed out")
	await textbox_closed

	State.current_WN = State.max_WN
	var scene_change_error = get_tree().change_scene_to_file("res://scenes/test/act1/test_scene_player_house_first_floor.tscn")
	if scene_change_error != OK:
		push_error("Failed to load the first-floor scene: %s" % scene_change_error)

# Resolves a player attack and records a victory if it defeats the enemy.
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
		# Mark the return destination before leaving the battle scene.
		State.return_player_to_anfugel = true
		State.current_WN = current_player_WN
		var scene_change_error = scene_tree.change_scene_to_file("res://scenes/test/act1/test_scene_player_house_outside.tscn")
		if scene_change_error != OK:
			State.return_player_to_anfugel = false
			push_error("Failed to load the outside scene: %s" % scene_change_error)
			return

		State.defeated_enemy_ids[State.active_enemy_id] = true
		return
	
	enemy_turn()


# Applies the bracing condition before the enemy's turn.
func _on_brace_pressed() -> void:
	display_text("U braced")
	await textbox_closed
	_apply_condition("res://scripts/res/conditions/bracing.tres")
	enemy_turn()


# Opens the exertion menu.
func _on_exert_pressed() -> void:
	$ControlPanel.hide()
	$ExertPanel.show()
	$DescriptionPanel.show()
	exertion_index = 0
	_refresh_menu_selection()

# Resolves FORBEAR and passes the turn to the enemy.
func _on_forbear_pressed() -> void:
	$ExertPanel.hide()
	$DescriptionPanel.hide()
	_refresh_menu_selection()
	display_text("U forbore")
	await textbox_closed
	enemy_turn()

# Resolves FORSAKE and passes the turn to the enemy.
func _on_forsake_pressed() -> void:
	$ExertPanel.hide()
	$DescriptionPanel.hide()
	_refresh_menu_selection()
	display_text("U forsook")
	await textbox_closed
	enemy_turn()

# Resolves the self-defeating FORDOOM exertion.
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
