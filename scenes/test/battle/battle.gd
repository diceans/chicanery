extends Control
signal textbox_closed
@export var enemy: Resource = null;

# Maps the active enemy type ID to the correct enemy resource so each battle loads the matching art and stats even when several enemies share the same type.
func _resolve_enemy_resource_for_id(enemy_id: StringName) -> Resource:
	if enemy_id.is_empty():
		push_error("Cannot load enemy resource: active enemy ID is empty")
		return null

	var enemy_key := String(enemy_id).to_lower()
	if enemy_key == "enemy_anfugel" or enemy_key.contains("anfugel"):
		return load("res://scripts/res/enemies/anfugel.tres")
	if enemy_key == "enemy_lignolus" or enemy_key.contains("lignolus"):
		return load("res://scripts/res/enemies/lignolus.tres")

	push_error("No enemy resource found for ID: %s" % enemy_id)
	return null

# Tracks battle values, menu selection, and the active status effect.
var current_player_WN = 0
var current_enemy_WN = 0
var current_player_ERL = 0
var current_enemy_ERL = 0
var d30_player = 0
var d30_enemy = 0
var player_damage = 0
var enemy_DO = 0
var enemy_DI = 0
var player_exertion = ""
var enemy_exertion = ""
var previous_enemy_exertion = ""
var action_index = 0
var exertion_index = 0
var action_buttons: Array[Button] = []
var exertion_buttons: Array[Button] = []
var menu_button_font_colors: Dictionary = {}
var condition: StatusEffect = null
var secondary_condition: StatusEffect = null
var condition_turns_remaining: int = 0
var secondary_condition_turns_remaining: int = 0
var bracing_pending: bool = false
var conflagrant_burn_applied_this_turn: bool = false
@onready var condition_icon: TextureRect = $AeContainer/ConditionIcon

# Initializes the battle scene, loads the enemy resource, and decides who acts first based on ERL.
func _ready():
	enemy = _resolve_enemy_resource_for_id(State.active_enemy_id)
	if enemy == null:
		return

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
		
	
# Collects the visible menu buttons and stores their original colors so the current selection can be highlighted cleanly.
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

# Returns the set of buttons currently visible for the active menu panel.
func _get_active_menu_buttons() -> Array[Button]:
	if $ExertPanel.visible:
		return exertion_buttons
	if $ControlPanel.visible:
		return action_buttons
	return []

# Resets the menu highlight state and repositions the selector arrow over the active button.
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

# Updates an enemy progress bar and its numeric label to reflect the current and max WN values.
func set_WN(progress_bar, WN, max_WN):
	progress_bar.value = WN
	progress_bar.max_value = max_WN
	progress_bar.get_node("Label").text = "%d/%d" % [WN, max_WN]

# Refreshes the player's WN HUD to show the current health and maximum health values.
func set_player_WN(condition_label: Label, WN: int, max_WN: int) -> void:
	condition_label.text = "WN: %d/%d" % [WN, max_WN]
	
# Writes the active status names into the primary and secondary condition labels.
# The main status stays in the first slot, while a supplemental status such as bracing can
# sit in the second slot without overwriting the original status text.
func set_condition(condition_label: Label, condition: String, secondary_condition_name: String = "") -> void:
	if condition_label == null:
		return

	var data_container = condition_label.get_parent()
	if data_container == null:
		condition_label.text = "%s" % condition.strip_edges()
		return

	var primary_label: Label = condition_label
	var secondary_label: Label = data_container.get_node_or_null("Condition2")
	if secondary_label == null:
		secondary_label = data_container.get_node_or_null("Container2")
	if secondary_label == null:
		primary_label.text = "%s" % condition.strip_edges()
		return

	primary_label.text = "%s" % condition.strip_edges()
	secondary_label.text = "%s" % secondary_condition_name.strip_edges()

# Applies or clears a status effect while preserving the player's main condition.
# Bracing is kept as a supplemental effect instead of replacing the active status, so
# states like CONFLAGRANT can coexist with the defensive bracing modifier.
func _apply_condition(condition_path: String) -> void:
	if condition_path == "res://scripts/res/conditions/bracing.tres":
		if condition != null and not condition.custom_properties.get("is_restricted", false):
			var bracing_effect := load(condition_path) as StatusEffect
			if bracing_effect == null:
				push_error("Failed to load the bracing status effect")
				return
			secondary_condition = bracing_effect
			secondary_condition_turns_remaining = bracing_effect.duration_turns
			_set_condition_active(secondary_condition, true)
			condition.custom_properties["is_bracing"] = true
			bracing_pending = true
			check_condition()
			return
		if condition == null:
			condition = load(condition_path) as StatusEffect
			if condition == null:
				push_error("Failed to load the bracing status effect")
				return
			condition_turns_remaining = condition.duration_turns
			_set_condition_active(condition, true)
			check_condition()
			return

	if condition != null and condition.custom_properties.get("is_bracing", false):
		bracing_pending = true

	if condition_path.is_empty():
		if condition != null and condition.custom_properties.get("is_conflagrant", false):
			check_condition()
			return
		_set_condition_active(condition, false)
		condition = null
		condition_turns_remaining = 0
		check_condition()
		return

	_set_condition_active(condition, false)
	condition = null
	condition = load(condition_path) as StatusEffect
	if condition == null:
		push_error("Failed to load status effect: %s" % condition_path)
		condition_turns_remaining = 0
		check_condition()
		return
	_set_condition_active(condition, true)
	if condition != null and condition.custom_properties.get("is_conflagrant", false):
		# The status timer and the burn-tick timer are separate concerns.
		# Keep the actual duration intact and only suppress the burn on the turn the
		# condition first lands so PROJECT's raw hit resolves without an immediate burn.
		condition_turns_remaining = condition.duration_turns
		conflagrant_burn_applied_this_turn = true
	else:
		condition_turns_remaining = condition.duration_turns if condition != null else 0
	check_condition()

# Toggles the custom status-effect flags used by the condition system, such as bracing and restriction states.
func _set_condition_active(status_effect: StatusEffect, is_active: bool) -> void:
	if status_effect == null:
		return
	for property_name in ["is_bracing", "is_constricted", "is_conflagrant"]:
		if status_effect.custom_properties.has(property_name):
			status_effect.custom_properties[property_name] = is_active
	status_effect.locked = is_active and status_effect.duration_turns > 0

# Refreshes the condition HUD and updates which controls are available to the player.
# If the active status is a restriction, the action menu is hidden so the player is forced to
# resolve the restriction; otherwise the normal battle UI remains usable.
func check_condition() -> void:
	var condition_label: Label = $AeContainer/PlayerPanel/PlayerData/Condition
	var primary_name: String = ""
	if condition != null and condition_turns_remaining > 0:
		primary_name = condition.effect_name
	var secondary_name: String = ""
	if secondary_condition != null and secondary_condition_turns_remaining > 0:
		secondary_name = secondary_condition.effect_name
	if condition == null or condition_turns_remaining <= 0:
		_set_condition_active(condition, false)
		condition = null
		condition_turns_remaining = 0
		set_condition(condition_label, primary_name, secondary_name)
		condition_icon.hide()
	else:
		condition.locked = true
		set_condition(condition_label, primary_name, secondary_name)
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

# Positions the condition icon over the player portrait so the active status is visible in the battle UI.
func _position_condition_icon() -> void:
	var avatar_rect: TextureRect = $AeContainer/TextureRect
	condition_icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	condition_icon.size = Vector2(48, 48)
	condition_icon.scale = Vector2(0.6, 0.6)
	condition_icon.position = avatar_rect.position + Vector2(
		avatar_rect.size.x - condition_icon.size.x * condition_icon.scale.x,
		0
	)

# Resolves the conflagrant burn tick once per active turn using the extra_dmg_factor value from the status effect.
func _apply_conflagrant_burn() -> void:
	if conflagrant_burn_applied_this_turn:
		return
	if condition == null or not condition.custom_properties.get("is_conflagrant", false):
		return
	if condition_turns_remaining <= 0:
		return
	var burn_factor: float = float(condition.stat_multipliers.get("extra_dmg_factor", 0.1))
	var burn_damage := int(State.max_WN * burn_factor)
	if burn_damage <= 0:
		return
	current_player_WN = max(0, current_player_WN - burn_damage)
	State.current_WN = current_player_WN
	set_player_WN($AeContainer/PlayerPanel/PlayerData/WN, current_player_WN, State.max_WN)
	conflagrant_burn_applied_this_turn = true

# Advances each active status by one turn after the enemy resolves its action.
# This keeps the primary condition timer and any supplemental bracing timer in sync with the
# battle flow so status effects expire at the correct point in the turn order.
func _advance_condition_turn(condition_at_turn_start: StatusEffect) -> void:
	if condition == null or condition != condition_at_turn_start:
		return
	condition_turns_remaining = max(0, condition_turns_remaining - 1)
	if secondary_condition != null and secondary_condition.custom_properties.get("is_bracing", false):
		secondary_condition_turns_remaining = max(0, secondary_condition_turns_remaining - 1)
		if secondary_condition_turns_remaining <= 0:
			_set_condition_active(secondary_condition, false)
			secondary_condition = null
			secondary_condition_turns_remaining = 0
	check_condition()
	
# Handles accept-key dismissal and keyboard navigation across the battle menu panels.
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

# Shows a battle text box and temporarily hides the action menu while the message is on screen.
func display_text(text):
	$ControlPanel.hide()
	$PlayerName.hide()
	$Textbox.show()
	$Textbox/Message.text = text
	_refresh_menu_selection()

# Removes any exertion currently locked by the enemy's status so it cannot be rolled again while the lock is active.
func _remove_locked_exertion_from_pool(available_exertions: Array) -> void:
	if enemy == null or not enemy.exertion_locked:
		return
	var locked_exertion := String(enemy.locked_exertion)
	if locked_exertion.is_empty():
		return
	while available_exertions.has(locked_exertion):
		available_exertions.erase(locked_exertion)

# Decrements the enemy lock countdown to keep the associated exertion unavailable for the correct number of turns.
func _advance_enemy_lock() -> void:
	if enemy == null or not enemy.exertion_locked:
		return
	enemy.exertion_lock_turns = max(0, enemy.exertion_lock_turns - 1)
	if enemy.exertion_lock_turns <= 0:
		enemy.exertion_locked = false
		enemy.locked_exertion = ""
		enemy.exertion_lock_turns = 0
	
# Chooses the enemy's exertion, resolves its damage or condition effects, and repeats until the threat ends.
func enemy_turn():
	conflagrant_burn_applied_this_turn = false
	display_text("%s attacks" % enemy.name)
	await textbox_closed
	enemy_DO = 0
	enemy_DI = 0
	var DV = randf_range(0.95, 1.05)
	if condition != null and condition.custom_properties.get("is_conflagrant", false):
		_apply_conflagrant_burn()
	# Use a turn-local list so lock and reroll logic does not modify the enemy resource.
	var available_exertions: Array = enemy.exertions.duplicate()
	_remove_locked_exertion_from_pool(available_exertions)
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
	elif enemy_exertion == "PINK" or enemy_exertion == "RIVE":
		enemy_DO = int(enemy.VHM * DV)
		_apply_condition("")
	elif enemy_exertion == "PROJECT":
		enemy.exertion_locked = true
		enemy.locked_exertion = "PROJECT"
		# The move remains unavailable for one extra turn beyond the active CONFLAGRANT
		# window so the raw PROJECT hit and the follow-on burn do not re-roll the same
		# exertion while the condition is still in effect.
		enemy.exertion_lock_turns = max(enemy.exertion_lock_turns, 3)
		enemy.pi_tDIM = 0.5
		enemy_DO = int(enemy.VHM * enemy.pi_tDIM * DV)
		_apply_condition("res://scripts/res/conditions/conflagrant.tres")
	# Bracing only applies to the immediate exertion hit. The burn from CONFLAGRANT is
	# a separate status effect and should not be reduced by bracing.
	enemy_DI = enemy_DO
	if was_bracing and enemy_exertion != "ROCK" and enemy_DO > 0:
		var bracing_effect := load("res://scripts/res/conditions/bracing.tres") as StatusEffect
		if bracing_effect == null:
			push_error("Failed to load the bracing status effect")
			return
		bracing_effect.flat_modifiers["pi_tDIM"] = randf_range(0.46, 0.54)
		enemy_DI = int(enemy_DO * bracing_effect.flat_modifiers["pi_tDIM"])
		bracing_pending = false
	if enemy_DI > 0:
		current_player_WN = max(0, current_player_WN - enemy_DI)
		State.current_WN = current_player_WN
	set_player_WN($AeContainer/PlayerPanel/PlayerData/WN, current_player_WN, State.max_WN)
	if not conflagrant_burn_applied_this_turn and condition != null and condition.custom_properties.get("is_conflagrant", false):
		_apply_conflagrant_burn()
	_advance_condition_turn(condition_at_turn_start)
	_advance_enemy_lock()
	if current_player_WN <= 0:
		await player_defeated()
		return
	if condition != null and condition.custom_properties.get("is_constricted", false):
		await enemy_turn()

# Resets the player after a loss, shows the defeat text, and sends the player back to the first-floor scene.
func player_defeated() -> void:
	display_text("u is slimed out")
	await textbox_closed

	State.current_WN = State.max_WN
	var scene_change_error = get_tree().change_scene_to_file("res://scenes/test/act1/test_scene_player_house_first_floor.tscn")
	if scene_change_error != OK:
		push_error("Failed to load the first-floor scene: %s" % scene_change_error)

# Resolves the player's assault action, applies damage, and transitions back to the outside scene when the enemy is slain.
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
		display_text("%s is slimed out" % enemy.name.to_upper())
		await textbox_closed
		
		$AnimationPlayer.play("enemy_dead")
		await $AnimationPlayer.animation_finished
		
		if State.active_enemy_id.is_empty():
			push_error("Cannot record victory: active enemy ID is empty")
			return

		var scene_tree: SceneTree = get_tree()
		await scene_tree.create_timer(0.25).timeout
		# Mark the return destination before leaving the battle scene.
		State.return_player_to_enemy = true
		State.current_WN = current_player_WN
		State.defeated_enemy_positions[State.active_enemy_position] = true
		var scene_change_error = scene_tree.change_scene_to_file("res://scenes/test/act1/test_scene_player_house_outside.tscn")
		if scene_change_error != OK:
			State.return_player_to_enemy = false
			State.defeated_enemy_positions.erase(State.active_enemy_position)
			push_error("Failed to load the outside scene: %s" % scene_change_error)
			return

		return
	
	enemy_turn()


# Uses the brace action to apply the bracing condition and pass the turn to the enemy.
func _on_brace_pressed() -> void:
	display_text("U braced")
	await textbox_closed
	_apply_condition("res://scripts/res/conditions/bracing.tres")
	enemy_turn()


# Opens the exertion menu so the player can choose a strategic action instead of a basic attack.
func _on_exert_pressed() -> void:
	$ControlPanel.hide()
	$ExertPanel.show()
	$DescriptionPanel.show()
	exertion_index = 0
	_refresh_menu_selection()

# Resolves the FORBEAR exertion and passes the turn to the enemy without attacking.
func _on_forbear_pressed() -> void:
	$ExertPanel.hide()
	$DescriptionPanel.hide()
	_refresh_menu_selection()
	display_text("U forbore")
	await textbox_closed
	enemy_turn()

# Resolves the FORSAKE exertion and intentionally gives the enemy the next turn.
func _on_forsake_pressed() -> void:
	$ExertPanel.hide()
	$DescriptionPanel.hide()
	_refresh_menu_selection()
	display_text("U forsook")
	await textbox_closed
	enemy_turn()

# Resolves the FORDOOM exertion, instantly dropping the player's WN and checking whether the battle is lost.
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
