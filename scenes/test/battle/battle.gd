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
var current_enemy_WN = 0
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
# The buttons of the three columns in ExertPanel, left to right: standard, mechanics, imageries.
var exertion_columns: Array = [[], [], []]
var exertion_column: int = 0
# The first visible row of each column, for the columns that scroll.
var exertion_scroll: Array = [0, 0, 0]
# The first row of the Mechanics and Imageries panels, copied once per exertion in the ally's resource file.
var exertion_row_templates: Dictionary = {}
const MT_RESTORED_BY_STANDARD_EXERTIONS := 15
# Every ally container in the scene, so the others can be hidden while the exertion panel is open.
const ALL_ALLY_CONTAINERS := ["AeContainer", "Elizyka", "Kietzt", "Wilseffn"]
# Each ally container's starting position and visibility, restored when the exertion panel closes.
var ally_container_layouts: Dictionary = {}
# Each menu button's original normal style and its highlighted copy.
var menu_button_styles: Dictionary = {}
const HIGHLIGHT_COLOR := Color(1, 1, 1, 0.25)
var condition: StatusEffect = null
var secondary_condition: StatusEffect = null
var condition_turns_remaining: int = 0
var secondary_condition_turns_remaining: int = 0
var bracing_pending: bool = false
var conflagrant_burn_applied_this_turn: bool = false
const TEXTBOX_AUTO_CLOSE_SECONDS := 2.0
var textbox_id: int = 0
const ENEMY_DAMAGE_OFFSET := Vector2(0, 0)
const UNALIVE_CONDITION_PATH := "res://scripts/res/conditions/unalive.tres"
# The HUD container for each ally, keyed by the id in the ally's resource file.
const ALLY_CONTAINERS := {0: "AeContainer", 1: "Elizyka"}
# Condition values that belong to one ally. They are copied into the variables above while that ally is active.
const ALLY_CONDITION_KEYS := ["condition", "secondary_condition", "condition_turns_remaining", "secondary_condition_turns_remaining", "bracing_pending", "conflagrant_burn_applied_this_turn"]
# One entry per ally in battle, holding its resource file, its HUD nodes and its own condition values.
var party: Array[Dictionary] = []
# The party entry and resource file of the ally the battle is currently resolving.
var active_ally: Dictionary = {}
var ally: Resource = null
var condition_icon: TextureRect
var condition_icon_2: TextureRect
# The enemy's condition, counted down at the end of each enemy turn like an ally's.
var enemy_condition: StatusEffect = null
var enemy_condition_turns_remaining: int = 0
# The enemy's ConditionIcon, placed over the top-right of the enemy sprite like the allies' icons over their portraits.
var enemy_condition_icon: TextureRect
const ENEMY_CONDITION_ICON_OFFSET := Vector2(-20, -20)
const CONFLAGRANT_CONDITION_PATH := "res://scripts/res/conditions/conflagrant.tres"
# Each ally's EB when the battle started, restored when the battle ends so ASH's boost doesn't carry over.
var starting_EB: Dictionary = {}
const ASH_EB := 0.75
const JEST_DAMAGE := 0
const JEST_LINE := "What do you call an alligator wearing a vest? An investigator!"
# The combat dialogue holds longer lines than the textbox, so it stays up longer before closing itself.
const DIALOGUE_AUTO_CLOSE_SECONDS := 4.0

# Initializes the battle scene, loads the enemy and ally resources, and decides who acts first based on ERL.
func _ready():
	enemy = _resolve_enemy_resource_for_id(State.active_enemy_id)
	if enemy == null:
		return

	$ExertPanel.position = Vector2(381, 687)
	$CombatDialogue.position = Vector2(381, 701)
	$EnemyContainer/Damage.modulate.a = 0.0

	_build_party()
	for container_name in ALL_ALLY_CONTAINERS:
		var container: Control = get_node_or_null(container_name)
		if container != null:
			ally_container_layouts[container] = {"position": container.position, "visible": container.visible}
	set_WN($EnemyContainer/ProgressBar, enemy.WN, enemy.WN)
	$EnemyContainer/Enemy.texture = enemy.texture

	current_enemy_WN = enemy.WN
	current_enemy_ERL = enemy.ERL

	enemy_condition_icon = $EnemyContainer/ConditionIcon
	# EnemyContainer is a VBoxContainer, which would stack the icon as a row under the Damage label.
	# A top-level control is skipped by the container, so the icon can be placed over the sprite instead.
	enemy_condition_icon.top_level = true
	enemy_condition_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_condition_icon.hide()

	$Textbox.hide()
	$CombatDialogue.hide()
	$NamePanel.show()
	$ControlPanel.show()
	$ExertPanel.hide()
	$DescriptionPanel.hide()
	# Clear every ally's condition HUD before the battle starts.
	# Clear every ally's condition HUD, except an ally who starts the battle with no WN, who is unalive.
	for member in party:
		_select_ally(member)
		if ally.current_WN <= 0:
			_apply_unalive()
		else:
			check_condition()
	var first_ally := _next_ally()
	if not first_ally.is_empty():
		_select_ally(first_ally)
		$NamePanel/PlayerName.text = ally.name
		_load_ally_menus()
	_refresh_menu_selection()

	display_text("%s appears" % enemy.name.to_upper())
	await textbox_closed
	if _living_allies().is_empty():
		await player_defeated()
		return

	# The ally who would act first races the enemy on ERL.
	var current_player_ERL = ally.ERL
	if current_player_ERL > current_enemy_ERL:
		_start_party_turn()
	elif current_player_ERL < current_enemy_ERL:
		enemy_turn()
	else:
		# Break equal-ERL ties with d30 rolls.
		while d30_player == d30_enemy:
			d30_player = randi_range(1, 30)
			d30_enemy = randi_range(1, 30)
			if d30_player > d30_enemy:
				_start_party_turn()
			elif d30_player < d30_enemy:
				enemy_turn()

# Pairs each ally resource in State.party with its HUD container and fills the HUD with that ally's stats.
func _build_party() -> void:
	for ally_resource in State.party:
		if not ALLY_CONTAINERS.has(ally_resource.id):
			continue
		var container: Control = get_node(ALLY_CONTAINERS[ally_resource.id])
		var data: Node = container.get_node("PlayerPanel/PlayerData")
		# AE's and Elizyka's containers name a few nodes differently, so check both names.
		var member := {
			"resource": ally_resource,
			"container": container,
			"portrait": _first_existing_node(container, ["Portrait", "TextureRect"]),
			"damage_label": _first_existing_node(container, ["Damage", "Damage2"]),
			"condition_icon": container.get_node("ConditionIcon"),
			"condition_icon_2": container.get_node("ConditionIcon2"),
			"wn_label": data.get_node("Wholeness/Stat"),
			"mt_label": data.get_node("Mentality/Stat"),
			"condition_label": _first_existing_node(data, ["Condition", "Panel/Condition"]),
			"condition": null,
			"secondary_condition": null,
			"condition_turns_remaining": 0,
			"secondary_condition_turns_remaining": 0,
			"bracing_pending": false,
			"conflagrant_burn_applied_this_turn": false,
		}
		ally_resource.turns = 0
		starting_EB[ally_resource] = ally_resource.EB
		if ally_resource.texture != null:
			member["portrait"].texture = ally_resource.texture
		member["damage_label"].visible = false
		member["damage_label"].modulate.a = 1.0
		_update_ally_stats(member)
		party.append(member)

# Returns the first of the given child paths that exists under the parent.
func _first_existing_node(parent: Node, paths: Array) -> Node:
	for path in paths:
		var node := parent.get_node_or_null(path)
		if node != null:
			return node
	push_error("%s has none of the nodes %s" % [parent.name, paths])
	return null

# Shows an ally's WN and MT from its resource file in its HUD.
func _update_ally_stats(member: Dictionary) -> void:
	var ally_resource: Resource = member["resource"]
	set_player_WN(member["wn_label"], int(ally_resource.current_WN), int(ally_resource.max_WN))
	set_player_WN(member["mt_label"], ally_resource.current_MT, ally_resource.max_MT)

# Swaps which ally the battle is working on: the current ally's condition values are saved to its
# party entry, then the given ally's values and HUD nodes are loaded into the shared battle variables.
func _select_ally(member: Dictionary) -> void:
	_store_active_ally()
	active_ally = member
	ally = member["resource"]
	condition_icon = member["condition_icon"]
	condition_icon_2 = member["condition_icon_2"]
	for key in ALLY_CONDITION_KEYS:
		set(key, member[key])

# Saves the shared condition variables back into the active ally's party entry.
func _store_active_ally() -> void:
	if active_ally.is_empty():
		return
	for key in ALLY_CONDITION_KEYS:
		active_ally[key] = get(key)

# Returns the allies who still have WN left.
func _living_allies() -> Array[Dictionary]:
	var living: Array[Dictionary] = []
	for member in party:
		if member["resource"].current_WN > 0:
			living.append(member)
	return living

# Returns the first standing ally whose turn count is 0, or an empty entry if nobody is standing.
func _next_ally() -> Dictionary:
	var living := _living_allies()
	for member in living:
		if member["resource"].turns == 0:
			return member
	if living.is_empty():
		return {}
	# Everyone standing has acted, so start a new round.
	for member in party:
		member["resource"].turns = 0
	return living[0]

# Hands the turn to the next ally who hasn't acted this round. A constricted ally loses the turn instead.
func _start_party_turn() -> void:
	var next_ally := _next_ally()
	if next_ally.is_empty():
		await player_defeated()
		return
	_select_ally(next_ally)
	check_condition()
	$NamePanel/PlayerName.text = ally.name
	if condition != null and condition.custom_properties.get("is_constricted", false):
		display_text("%s is constricted" % ally.name)
		await textbox_closed
		_end_ally_turn()
		return
	_load_ally_menus()
	action_index = 0
	$NamePanel.show()
	$ControlPanel.show()
	$ExertPanel.hide()
	$DescriptionPanel.hide()
	_refresh_menu_selection()

# Marks the active ally as having acted, resets every ally's turn count once all standing allies
# have acted, then passes the turn to the enemy.
func _end_ally_turn() -> void:
	ally.turns += 1
	if _living_allies().all(func(member): return member["resource"].turns > 0):
		for member in party:
			member["resource"].turns = 0
	enemy_turn()

# Returns one of the active ally's menu lists from its resource file. An ally whose resource doesn't
# list its own actions, standard exertions or descriptors yet uses AE's, so its menu is never empty.
func _ally_list(property: String) -> Variant:
	var value: Variant = ally.get(property)
	if value.is_empty():
		value = party[0]["resource"].get(property)
	return value

# Builds the action and exertion menus from the active ally's resource file.
func _load_ally_menus() -> void:
	action_buttons = _get_menu_buttons($ControlPanel, _ally_list("actions"))
	exertion_columns[0] = _get_menu_buttons($ExertPanel/Standard, _ally_list("standard_exertions"))
	exertion_columns[1] = _build_exertion_rows($ExertPanel/Mechanics, ally.mechanics_exertions)
	exertion_columns[2] = _build_exertion_rows($ExertPanel/Imageries, ally.imageries_exertions)
	exertion_buttons = exertion_columns[exertion_column]

# Fills a Mechanics or Imageries panel with one row per exertion in the dictionary, showing its name
# and MT cost. Pressing a row pays that cost.
func _build_exertion_rows(panel: Control, exertions: Dictionary) -> Array[Button]:
	if not exertion_row_templates.has(panel):
		var template: Button = panel.get_child(0)
		panel.remove_child(template)
		exertion_row_templates[panel] = template
	for row in panel.get_children():
		menu_button_styles.erase(row)
		row.free()
	var rows: Array[Button] = []
	for exertion_name in exertions:
		var cost: int = int(exertions[exertion_name])
		var row: Button = exertion_row_templates[panel].duplicate()
		row.get_node("Name").text = exertion_name
		row.get_node("Price").text = str(cost)
		row.set_meta("exertion_name", exertion_name)
		row.pressed.connect(_on_mt_exertion_pressed.bind(exertion_name, cost))
		panel.add_child(row)
		_register_menu_button(row)
		rows.append(row)
	return rows

# The row templates are kept out of the scene tree, so free them with the battle. Each ally's EB is
# put back too, since the resource files outlive the battle.
func _exit_tree() -> void:
	for template in exertion_row_templates.values():
		template.free()
	for ally_resource in starting_EB:
		ally_resource.EB = starting_EB[ally_resource]

# Shows only the rows of each scrolling column that fit in its panel, keeping the selected row in view.
func _scroll_exertion_rows() -> void:
	var panels := [$ExertPanel/Standard, $ExertPanel/Mechanics, $ExertPanel/Imageries]
	for column in [1, 2]:
		var rows: Array = exertion_columns[column]
		if rows.is_empty():
			continue
		var row_height: float = rows[0].size.y
		var visible_rows: int = max(1, int(panels[column].size.y / row_height))
		if column == exertion_column:
			if exertion_index < exertion_scroll[column]:
				exertion_scroll[column] = exertion_index
			elif exertion_index >= exertion_scroll[column] + visible_rows:
				exertion_scroll[column] = exertion_index - visible_rows + 1
		for i in rows.size():
			var shown: bool = i >= exertion_scroll[column] and i < exertion_scroll[column] + visible_rows
			rows[i].visible = shown
			if shown:
				rows[i].position.y = (i - exertion_scroll[column]) * row_height

# Moves the selection to the next column to the left or right that has exertions in it.
func _switch_exertion_column(step: int) -> void:
	for offset in range(1, exertion_columns.size()):
		var candidate: int = posmod(exertion_column + step * offset, exertion_columns.size())
		var candidate_rows: Array = exertion_columns[candidate]
		if candidate_rows.is_empty():
			continue
		# Stay on the same visible row when moving across, as far as the new column allows.
		var visible_row: int = exertion_index - exertion_scroll[exertion_column]
		exertion_index = clamp(exertion_scroll[candidate] + visible_row, 0, candidate_rows.size() - 1)
		exertion_column = candidate
		exertion_buttons = candidate_rows
		break
	_refresh_menu_selection()

# Makes a menu button keyboard-only and stores its original style and a highlighted copy.
func _register_menu_button(button: Button) -> void:
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.focus_mode = Control.FOCUS_NONE
	if menu_button_styles.has(button):
		return
	var normal_style: StyleBox = button.get_theme_stylebox("normal")
	# Copy the normal style so the highlight keeps the same content margins and the text doesn't shift.
	var highlight_style: StyleBox = normal_style.duplicate() if normal_style is StyleBoxFlat else StyleBoxFlat.new()
	highlight_style.bg_color = HIGHLIGHT_COLOR
	menu_button_styles[button] = {"normal": normal_style, "highlight": highlight_style}

# Collects the menu buttons whose text is in the given list and stores their original styles so the current selection can be highlighted cleanly.
func _get_menu_buttons(container: Node, names: Array) -> Array[Button]:
	var buttons: Array[Button] = []
	for child in container.get_children():
		if not child is Button:
			continue
		_register_menu_button(child)
		if names.has(child.text.strip_edges().to_upper()):
			buttons.append(child)
	if buttons.size() != names.size():
		push_error("Menu buttons do not match %s's list: %s" % [ally.name, names])
	return buttons

# Returns the set of buttons currently visible for the active menu panel.
func _get_active_menu_buttons() -> Array[Button]:
	if $ExertPanel.visible:
		return exertion_buttons
	if $ControlPanel.visible:
		return action_buttons
	return []

# Clears every menu highlight, then gives the selected button of the open menu a 25% white background, like the pause menu.
func _refresh_menu_selection() -> void:
	for button in menu_button_styles:
		button.add_theme_stylebox_override("normal", menu_button_styles[button]["normal"])

	if _is_message_open():
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
	selected_button.add_theme_stylebox_override("normal", menu_button_styles[selected_button]["highlight"])
	if $ExertPanel.visible:
		_scroll_exertion_rows()
		_update_exertion_description(selected_index)

# Shows the descriptor of the highlighted exertion in the description panel.
func _update_exertion_description(selected_index: int) -> void:
	var button: Button = exertion_buttons[selected_index]
	var exertion_name: String = button.get_meta("exertion_name", button.text.strip_edges().to_upper())
	$DescriptionPanel/Label.text = _ally_list("exertions_descriptors").get(exertion_name, "")

# Updates an enemy progress bar and its numeric label to reflect the current and max WN values.
func set_WN(progress_bar, WN, max_WN):
	progress_bar.value = WN
	progress_bar.max_value = max_WN
	progress_bar.get_node("Label").text = "%d/%d" % [WN, max_WN]

# Refreshes an ally's WN HUD to show the current health and maximum health values.
func set_player_WN(condition_label: Label, WN: int, max_WN: int) -> void:
	condition_label.text = "%d/%d" % [WN, max_WN]

# Applies the damage taken by the active ally and briefly shows a floating label showing the amount lost.
# If another condition is active, a temporary duplicate float is also spawned so the number
# remains visible while the original fades, which keeps the raw hit readable alongside burn ticks.
func _apply_player_damage(amount: int) -> void:
	if amount <= 0:
		return
	ally.current_WN = max(0, ally.current_WN - amount)
	_update_ally_stats(active_ally)
	if ally.current_WN <= 0:
		_apply_unalive()
	var damage_label: Label = active_ally["damage_label"]
	var has_active_status := (condition != null and condition_turns_remaining > 0) or (secondary_condition != null and secondary_condition_turns_remaining > 0)
	if has_active_status and damage_label.visible and damage_label.modulate.a > 0.1:
		var duplicate_label := damage_label.duplicate()
		duplicate_label.name = "DamageDuplicate"
		var portrait_rect: TextureRect = active_ally["portrait"]
		duplicate_label.position = portrait_rect.position + Vector2(
			portrait_rect.size.x * 0.5 - duplicate_label.size.x * 0.5 - 132,
			portrait_rect.size.y * 0.5 - duplicate_label.size.y * 0.5 - 160
		)
		duplicate_label.visible = true
		duplicate_label.modulate.a = 1.0
		duplicate_label.text = "-%d" % amount
		active_ally["container"].add_child(duplicate_label)
		var duplicate_tween := create_tween()
		duplicate_tween.tween_property(duplicate_label, "position", duplicate_label.position + Vector2(0, -24), 1.0)
		duplicate_tween.parallel().tween_property(duplicate_label, "modulate:a", 0.0, 1.0)
		duplicate_tween.finished.connect(func() -> void:
			duplicate_label.queue_free()
		)
		return
	damage_label.text = "-%d" % amount
	damage_label.visible = true
	damage_label.modulate.a = 1.0
	var start_position := damage_label.position
	var tween := create_tween()
	tween.tween_property(damage_label, "position", start_position + Vector2(0, -24), 1.0)
	tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 1.0)
	tween.finished.connect(func() -> void:
		damage_label.visible = false
		damage_label.position = start_position
		damage_label.modulate.a = 1.0
	)

# Shows a floating label over the enemy with the damage it just took.
# The enemy's Damage label sits inside a VBoxContainer, so it stays transparent in place to keep the
# layout steady, and a copy is floated from the battle root where the container cannot reposition it.
func _show_enemy_damage(amount: int) -> void:
	if amount <= 0:
		return
	var damage_label: Label = $EnemyContainer/Damage
	var floating_label := damage_label.duplicate() as Label
	floating_label.name = "EnemyDamageFloat"
	floating_label.text = "-%d" % amount
	floating_label.modulate.a = 1.0
	add_child(floating_label)
	floating_label.size = damage_label.size
	# Start the number centred over the enemy sprite rather than at the label's slot below it.
	var enemy_rect: Rect2 = $EnemyContainer/Enemy.get_global_rect()
	floating_label.global_position = enemy_rect.get_center() - floating_label.size * 0.5 + ENEMY_DAMAGE_OFFSET
	var tween := create_tween()
	tween.tween_property(floating_label, "position", floating_label.position + Vector2(0, -24), 1.0)
	tween.parallel().tween_property(floating_label, "modulate:a", 0.0, 1.0)
	tween.finished.connect(func() -> void:
		floating_label.queue_free()
	)

# Takes WN off the enemy, updates its bar and floats the damage number over it.
func _apply_enemy_damage(amount: int) -> void:
	if amount <= 0:
		return
	current_enemy_WN = max(0, current_enemy_WN - amount)
	set_WN($EnemyContainer/ProgressBar, current_enemy_WN, enemy.WN)
	_show_enemy_damage(amount)

# Puts a status effect on the enemy for its full duration, replacing any condition it already has.
# The resource is copied because load() hands every caller the same instance, and the allies' condition
# code switches flags such as is_conflagrant on and off; a shared copy would let an ally's CONFLAGRANT
# expiring switch off the enemy's.
func _apply_enemy_condition(condition_path: String) -> void:
	var status_effect := load(condition_path) as StatusEffect
	if status_effect == null:
		push_error("Failed to load status effect: %s" % condition_path)
		return
	_set_condition_active(enemy_condition, false)
	enemy_condition = status_effect.duplicate(true)
	enemy_condition_turns_remaining = enemy_condition.duration_turns
	_set_condition_active(enemy_condition, true)
	_check_enemy_condition()

# Shows the enemy's condition icon over its sprite, or clears the condition once it has run out.
func _check_enemy_condition() -> void:
	if enemy_condition == null or enemy_condition_turns_remaining <= 0:
		_set_condition_active(enemy_condition, false)
		enemy_condition = null
		enemy_condition_turns_remaining = 0
		enemy_condition_icon.hide()
		return
	_condition_icon_for_status(enemy_condition_icon, enemy_condition)
	var enemy_rect: Rect2 = $EnemyContainer/Enemy.get_global_rect()
	enemy_condition_icon.global_position = enemy_rect.position + Vector2(enemy_rect.size.x - 48 * 0.6, 0) + ENEMY_CONDITION_ICON_OFFSET

# Burns the enemy for a share of its max WN while it is conflagrant, using the same extra_dmg_factor as the allies' burn.
func _apply_enemy_conflagrant_burn() -> void:
	if enemy_condition == null or not enemy_condition.custom_properties.get("is_conflagrant", false):
		return
	var burn_factor: float = float(enemy_condition.stat_multipliers.get("extra_dmg_factor", 0.1))
	_apply_enemy_damage(int(enemy.WN * burn_factor))

# Counts the enemy's condition down by one turn at the end of the enemy's turn.
func _advance_enemy_condition_turn() -> void:
	if enemy_condition == null:
		return
	enemy_condition_turns_remaining = max(0, enemy_condition_turns_remaining - 1)
	_check_enemy_condition()

# Writes the name of the first condition the active ally received into its condition label.
# Later supplemental statuses such as bracing only show as icons, so the name never changes underneath.
func set_condition(condition_label: Label, condition_name: String) -> void:
	if condition_label == null:
		return
	condition_label.text = condition_name.strip_edges()

# Applies or clears a status effect on the active ally while preserving its main condition.
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

# Marks the active ally as unalive once its WN reaches 0. Every other condition is cleared, and
# unalive never counts down because fallen allies are skipped when conditions tick each enemy turn.
func _apply_unalive() -> void:
	var unalive := load(UNALIVE_CONDITION_PATH) as StatusEffect
	if unalive == null:
		push_error("Failed to load the unalive status effect")
		return
	_set_condition_active(condition, false)
	_set_condition_active(secondary_condition, false)
	secondary_condition = null
	secondary_condition_turns_remaining = 0
	bracing_pending = false
	condition = unalive
	condition_turns_remaining = unalive.duration_turns
	_set_condition_active(condition, true)
	check_condition()

# Toggles the custom status-effect flags used by the condition system, such as bracing and restriction states.
func _set_condition_active(status_effect: StatusEffect, is_active: bool) -> void:
	if status_effect == null:
		return
	for property_name in ["is_bracing", "is_constricted", "is_conflagrant"]:
		if status_effect.custom_properties.has(property_name):
			status_effect.custom_properties[property_name] = is_active
	status_effect.locked = is_active and status_effect.duration_turns > 0

# Refreshes the active ally's condition name and icons. Whether that ally can act while
# constricted is decided when its turn starts, in _start_party_turn.
func check_condition() -> void:
	var condition_label: Label = active_ally["condition_label"]
	var primary_name: String = ""
	if condition != null and condition_turns_remaining > 0:
		primary_name = condition.effect_name
	if condition == null or condition_turns_remaining <= 0:
		_set_condition_active(condition, false)
		condition = null
		condition_turns_remaining = 0
		set_condition(condition_label, primary_name)
		condition_icon.hide()
		condition_icon_2.hide()
	else:
		condition.locked = true
		set_condition(condition_label, primary_name)
		_condition_icon_for_status(condition_icon, condition)
		if secondary_condition != null and secondary_condition_turns_remaining > 0:
			_condition_icon_for_status(condition_icon_2, secondary_condition)
		else:
			condition_icon_2.hide()
		_position_condition_icon()
	_refresh_menu_selection()

# Attaches a status effect sprite to the given icon slot and keeps the slot usable for a
# secondary effect without duplicating the same icon in both positions.
func _condition_icon_for_status(icon_slot: TextureRect, status_effect: StatusEffect) -> void:
	if icon_slot == null or status_effect == null:
		if icon_slot != null:
			icon_slot.hide()
		return
	if status_effect.icon == null:
		icon_slot.hide()
		return
	var icon_image := status_effect.icon.get_image()
	if icon_image == null or icon_image.is_empty():
		push_error("Condition icon has no image data: %s" % status_effect.effect_name)
		icon_slot.hide()
		return
	var icon_texture := AtlasTexture.new()
	icon_texture.atlas = status_effect.icon
	icon_texture.region = Rect2(icon_image.get_used_rect())
	icon_slot.texture = icon_texture
	icon_slot.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	icon_slot.size = Vector2(48, 48)
	icon_slot.scale = Vector2(0.6, 0.6)
	icon_slot.show()

# Positions the condition icons over the active ally's portrait so its statuses are visible in the battle UI.
func _position_condition_icon() -> void:
	var avatar_rect: TextureRect = active_ally["portrait"]
	var base_position := avatar_rect.position + Vector2(
		avatar_rect.size.x - 48 * 0.6,
		0
	)
	condition_icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	condition_icon.size = Vector2(48, 48)
	condition_icon.scale = Vector2(0.6, 0.6)
	condition_icon.position = base_position + Vector2(-20, -20)
	if condition_icon_2 != null:
		condition_icon_2.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		condition_icon_2.size = Vector2(48, 48)
		condition_icon_2.scale = Vector2(0.6, 0.6)
		condition_icon_2.position = base_position + Vector2(-20, 32)

# Resolves the conflagrant burn tick once per active turn using the extra_dmg_factor value from the status effect.
func _apply_conflagrant_burn() -> void:
	if conflagrant_burn_applied_this_turn:
		return
	if condition == null or not condition.custom_properties.get("is_conflagrant", false):
		return
	if condition_turns_remaining <= 0:
		return
	var burn_factor: float = float(condition.stat_multipliers.get("extra_dmg_factor", 0.1))
	var burn_damage := int(ally.max_WN * burn_factor)
	if burn_damage <= 0:
		return
	_apply_player_damage(burn_damage)
	conflagrant_burn_applied_this_turn = true

# Advances each of the active ally's statuses by one turn after the enemy resolves its action.
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

	if _is_message_open():
		if event.is_action_pressed("ui_accept"):
			var viewport := get_viewport()
			if viewport == null:
				return
			viewport.set_input_as_handled()
			_close_textbox(textbox_id, false)
		return

	var buttons := _get_active_menu_buttons()
	if buttons.is_empty():
		return

	var is_exertion_menu = $ExertPanel.visible
	# Backspace leaves the exertion panel and goes back to the action menu, like the pause menu.
	if is_exertion_menu and event.is_action_pressed("ui_text_backspace"):
		_hide_exert_panel()
		$NamePanel.show()
		$ControlPanel.show()
		_refresh_menu_selection()
		get_viewport().set_input_as_handled()
		return
	if is_exertion_menu and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		_switch_exertion_column(-1 if event.is_action_pressed("ui_left") else 1)
		get_viewport().set_input_as_handled()
		return
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
# The text box closes when the player presses enter or after TEXTBOX_AUTO_CLOSE_SECONDS, whichever comes first.
func display_text(text):
	$ControlPanel.hide()
	$NamePanel.hide()
	$CombatDialogue.hide()
	$Textbox.show()
	$Textbox/Message.text = text
	_refresh_menu_selection()
	_start_message_timer(TEXTBOX_AUTO_CLOSE_SECONDS)

# Shows a line spoken by an ally in the combat dialogue, with the speaker's name above it.
# It closes like the text box, from the enter key or after DIALOGUE_AUTO_CLOSE_SECONDS, and also emits textbox_closed.
func display_dialogue(speaker: String, text: String) -> void:
	$ControlPanel.hide()
	$NamePanel.hide()
	$Textbox.hide()
	$CombatDialogue/Name/PlayerName.text = speaker
	$CombatDialogue/Message.text = text
	# Like the exertion panel, only the speaking ally's container stays on screen, in AE's spot.
	_focus_active_ally_container()
	$CombatDialogue.show()
	_refresh_menu_selection()
	_start_message_timer(DIALOGUE_AUTO_CLOSE_SECONDS)

# Starts the auto-close timer for the message that was just shown.
func _start_message_timer(seconds: float) -> void:
	textbox_id += 1
	get_tree().create_timer(seconds).timeout.connect(_close_textbox.bind(textbox_id, true))

# Whether the text box or the combat dialogue is on screen.
func _is_message_open() -> bool:
	return $Textbox.visible or $CombatDialogue.visible

# Closes the text box or combat dialogue once, either from the enter key or from the auto-close timer.
# The ID check stops an old timer from closing a newer message that is already on screen.
func _close_textbox(id: int, timed_out: bool) -> void:
	if not _is_message_open() or (timed_out and id != textbox_id):
		return
	if $CombatDialogue.visible:
		$CombatDialogue.hide()
		_restore_ally_containers()
	$Textbox.hide()
	_refresh_menu_selection()
	textbox_closed.emit()

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

# Picks a random standing ally to target, resolves the enemy's exertion on it, ticks every ally's
# conditions, then hands the turn back to the party.
func enemy_turn():
	_store_active_ally()
	for member in party:
		member["conflagrant_burn_applied_this_turn"] = false
	var living := _living_allies()
	if living.is_empty():
		await player_defeated()
		return
	# A conflagrant enemy burns at the start of its turn, and may burn out before it can act.
	if enemy_condition != null and enemy_condition.custom_properties.get("is_conflagrant", false):
		_apply_enemy_conflagrant_burn()
		$AnimationPlayer.play("enemy_damaged")
		await $AnimationPlayer.animation_finished
		if current_enemy_WN == 0:
			await _enemy_defeated()
			return
	# Allies are ordered by id, so with AE (id 0) and Elizyka (id 1) both standing this rolls 0 or 1 to pick the target.
	var target: Dictionary = living[randi_range(0, living.size() - 1)]
	_select_ally(target)
	display_text("%s attacks %s" % [enemy.name, ally.name])
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
	# Record every ally's condition now, so a condition applied during this turn doesn't tick down straight away.
	_store_active_ally()
	var conditions_at_turn_start: Array = party.map(func(member): return member["condition"])
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
		_apply_player_damage(enemy_DI)
	if not conflagrant_burn_applied_this_turn and condition != null and condition.custom_properties.get("is_conflagrant", false):
		_apply_conflagrant_burn()
	# Allies who weren't targeted still take their own burn tick, and every standing ally's conditions count down.
	for i in party.size():
		var member: Dictionary = party[i]
		if member["resource"].current_WN <= 0:
			continue
		_select_ally(member)
		if not is_same(member, target):
			_apply_conflagrant_burn()
		_advance_condition_turn(conditions_at_turn_start[i])
	_advance_enemy_condition_turn()
	_advance_enemy_lock()
	if _living_allies().is_empty():
		await player_defeated()
		return
	_start_party_turn()

# Restores every ally after a loss, shows the defeat text, and sends the player back to the first-floor scene.
func player_defeated() -> void:
	display_text("You are defeated")
	await textbox_closed

	for member in party:
		member["resource"].current_WN = member["resource"].max_WN
		member["resource"].turns = 0
	var scene_change_error = get_tree().change_scene_to_file("res://scenes/test/act1/test_scene_player_house_first_floor.tscn")
	if scene_change_error != OK:
		push_error("Failed to load the first-floor scene: %s" % scene_change_error)

# Resolves the active ally's assault action, applies damage, and transitions back to the outside scene when the enemy is slain.
func _on_assault_pressed() -> void:
	display_text("%s swung" % ally.name)
	await textbox_closed

	var DV = randf_range(0.95, 1.05)
	player_damage = roundi((ally.VHM + ally.EB) * ally.EM * ally.pi_ACM * DV)
	_apply_enemy_damage(player_damage)

	$AnimationPlayer.play("enemy_damaged")
	await $AnimationPlayer.animation_finished

	display_text("%s dealt %d damage" % [ally.name, player_damage])
	await textbox_closed

	if current_enemy_WN == 0:
		await _enemy_defeated()
		return

	_end_ally_turn()

# Plays the enemy's defeat, records it so it stays gone, and returns to the outside scene.
func _enemy_defeated() -> void:
	enemy_condition_icon.hide()
	display_text("%s is defeated" % enemy.name.to_upper())
	await textbox_closed

	$AnimationPlayer.play("enemy_dead")
	await $AnimationPlayer.animation_finished

	if State.active_enemy_id.is_empty():
		push_error("Cannot record victory: active enemy ID is empty")
		return

	var scene_tree: SceneTree = get_tree()
	await scene_tree.create_timer(0.25).timeout
	# Mark the return destination before leaving the battle scene. Each ally's WN is
	# already kept in its resource file, which State.party holds onto between battles.
	State.return_player_to_enemy = true
	State.defeated_enemy_positions[State.active_enemy_position] = true
	var scene_change_error = scene_tree.change_scene_to_file("res://scenes/test/act1/test_scene_player_house_outside.tscn")
	if scene_change_error != OK:
		State.return_player_to_enemy = false
		State.defeated_enemy_positions.erase(State.active_enemy_position)
		push_error("Failed to load the outside scene: %s" % scene_change_error)


# Uses the brace action to apply the bracing condition and end the active ally's turn.
func _on_brace_pressed() -> void:
	display_text("%s braced" % ally.name)
	await textbox_closed
	_apply_condition("res://scripts/res/conditions/bracing.tres")
	_end_ally_turn()


# Opens the exertion menu so the player can choose a strategic action instead of a basic attack.
func _on_exert_pressed() -> void:
	_show_exert_panel()

# Opens the exertion panel with the active ally's container moved to AE's spot and every other ally's container hidden.
func _show_exert_panel() -> void:
	$ControlPanel.hide()
	_focus_active_ally_container()
	exertion_column = 0
	exertion_index = 0
	exertion_scroll = [0, 0, 0]
	exertion_buttons = exertion_columns[0]
	$ExertPanel.show()
	$DescriptionPanel.show()
	_refresh_menu_selection()

# Closes the exertion panel and puts every ally container back where it started.
func _hide_exert_panel() -> void:
	$ExertPanel.hide()
	$DescriptionPanel.hide()
	_restore_ally_containers()
	_refresh_menu_selection()

# Moves the active ally's container to AE's spot and hides every other ally's container.
func _focus_active_ally_container() -> void:
	var active_container: Control = active_ally["container"]
	for container in ally_container_layouts:
		container.visible = container == active_container
	active_container.position = ally_container_layouts[$AeContainer]["position"]

# Puts every ally container back where it started, with its starting visibility.
func _restore_ally_containers() -> void:
	for container in ally_container_layouts:
		container.position = ally_container_layouts[container]["position"]
		container.visible = ally_container_layouts[container]["visible"]

# Gives back the MT that FORBEAR and FORSAKE restore, up to the active ally's max MT.
func _restore_standard_exertion_MT() -> void:
	ally.current_MT = min(ally.max_MT, ally.current_MT + MT_RESTORED_BY_STANDARD_EXERTIONS)
	_update_ally_stats(active_ally)

# Pays a mechanics or imageries exertion's MT cost, resolves its effect, and ends the turn.
# Exertions without an effect yet only pay their cost.
# If the active ally can't afford it, nothing happens and the panel stays open so another exertion can be picked.
func _on_mt_exertion_pressed(exertion_name: String, cost: int) -> void:
	if ally.current_MT < cost:
		$DescriptionPanel/Label.text = "Not enough MT for %s" % exertion_name
		return
	ally.current_MT -= cost
	_update_ally_stats(active_ally)
	_hide_exert_panel()
	display_text("%s exerted %s" % [ally.name, exertion_name])
	await textbox_closed
	match exertion_name:
		"JEST":
			await _exert_jest()
		"ASH":
			await _exert_ash()
	if current_enemy_WN == 0:
		await _enemy_defeated()
		return
	_end_ally_turn()

# JEST: the active ally tells a joke in the combat dialogue, then deals JEST_DAMAGE (0 for now).
func _exert_jest() -> void:
	display_dialogue(ally.name, JEST_LINE)
	await textbox_closed
	_apply_enemy_damage(JEST_DAMAGE)
	display_text("%s dealt %d damage" % [ally.name, JEST_DAMAGE])
	await textbox_closed

# ASH: sets the enemy CONFLAGRANT, and raises the active ally's EB to ASH_EB for the rest of the battle.
func _exert_ash() -> void:
	_apply_enemy_condition(CONFLAGRANT_CONDITION_PATH)
	display_text("%s is %s" % [enemy.name, enemy_condition.effect_name.to_lower()])
	await textbox_closed
	ally.EB = max(ally.EB, ASH_EB)
	display_text("%s's EB rose to %.2f" % [ally.name, ally.EB])
	await textbox_closed

# Resolves the FORBEAR exertion, restoring some MT, and ends the active ally's turn without attacking.
func _on_forbear_pressed() -> void:
	_hide_exert_panel()
	_restore_standard_exertion_MT()
	display_text("%s forbore" % ally.name)
	await textbox_closed
	_end_ally_turn()

# Resolves the FORSAKE exertion, restoring some MT, and intentionally gives up the active ally's turn.
func _on_forsake_pressed() -> void:
	_hide_exert_panel()
	_restore_standard_exertion_MT()
	display_text("%s forsook" % ally.name)
	await textbox_closed
	_end_ally_turn()

# Resolves the FOREDOOM exertion, instantly dropping the active ally's WN and checking whether the battle is lost.
func _on_foredoom_pressed() -> void:
	_hide_exert_panel()
	display_text("%s foredoomed" % ally.name)
	await textbox_closed
	var foredoom_damage: int = int(ally.current_WN)
	if foredoom_damage > 0:
		_apply_player_damage(foredoom_damage)
	if _living_allies().is_empty():
		await player_defeated()
		return
	_end_ally_turn()
