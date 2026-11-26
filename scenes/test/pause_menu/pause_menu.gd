extends Control
var inventory = {
	"Apple Of Paradise":0,
	"Hellshroom":1,
	"Hibiscus Flower":5,
	"Instant Noodles": 4,
	"Macefruit":5,
	"Mead":1,
	"Mystery Tupperware":8,
	"Pocket Sand":7,
	"Pomergrenade":10,
	"Pilk":78,
	"10 Hour Burst":66,
	"Bonk Atomic Punch":9,
	"Can Of Wellcheers":2,
	"Ironskin Potion":9
}
var item
var selected_pos =0
var shown_pos = 0
var current_menu = "options"
var selected_item
var selected_item_pos
var selected_slot_pos
var selected_type_pos
# Where the chosen function sits in the control panel's list, so backing out of the key list returns to it.
var selected_function_pos
var players = ["ae","elizyka","kletzt","wilseffin"]
var limit = 6
var options = []
@export var item_template: Node
@export var arrow: Node
var menu_button_font_colors
const HIGHLIGHT_COLOR = Color(1, 1, 1, 0.25)
# Which overview option opens each sub-menu, so backing out puts the cursor back on it.
const MENU_OPTION_INDEX = {"items": 0, "equip_slots": 1, "exertion_types": 2, "quit": 5, "settings": 6}
# The character panels that show a party member's stats, with the id from that ally's resource file.
const CHARACTER_PANEL_IDS = {"AePanel": 0, "ElizykaPanel": 1}
# Which resource properties each StatNumber label shows. Two properties are shown as "current/max".
# Add a label to StatNumber and an entry here to show another stat.
const STAT_PROPERTIES = {
	"Wholeness": ["current_WN", "max_WN"],
	"Mentality": ["current_MT", "max_MT"],
	"Vehemence": ["VHM"],
}
# The exertion types in the same order as the ExertionType buttons.
const EXERTION_TYPES = ["standard", "mechanics", "imageries"]
# How many exertion rows fit in ExertionList before it scrolls.
const EXERTION_ROWS_SHOWN = 12
# Every exertion the party has, by type, with its MT price as text. Standard exertions have no price.
var party_exertions = {}
# Every exertion description from the party's resource files.
var party_descriptors = {}
# The first row of ExertionList, copied once per exertion of the chosen type.
var exertion_template: Node
var exertion_shown_pos = 0

func _ready() -> void:
	$OverviewPanel.position = Vector2(0, -26)
	$QuitPanel.position = Vector2(0, 0)
	$EquippablePanelAe.position = Vector2(0, -27)
	$ArticlePanel.position = Vector2(0, 0)
	$CharactersPanel.position = Vector2(1126, 36)
	$ExertionPanel.position = Vector2(0, 0)
	$OptionsPanel.position = Vector2(0, 0)
	$ControlPanel.position = Vector2(39, 33)

	$ArticlePanel.hide()
	$QuitPanel.hide()
	$EquippablePanelAe.hide()
	$ExertionPanel.hide()
	$OptionsPanel.hide()
	$ControlPanel.hide()
	_disable_mouse(self)
	# Each character panel's first child is a ColorRect used as its highlight background.
	for panel in $CharactersPanel.get_children():
		panel.get_child(0).color = HIGHLIGHT_COLOR
		panel.get_child(0).hide()
	_items()
	_refresh_party()
	update_arrow()
	# The menu keeps running while it pauses the game, so it can still be navigated and closed.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

# Shows the menu from the overview and pauses the game, so AE and the NPCs stop while it is open.
func open_menu():
	current_menu = "options"
	selected_pos = 0
	shown_pos = 0
	# Battles change WN and MT, so read the party's resource files again every time the menu opens.
	_refresh_party()
	show()
	update_arrow()
	get_tree().paused = true

# Reads the party's resource files into the character panels' stats and the exertion panel.
func _refresh_party():
	_fill_party_stats()
	_collect_party_exertions()

# Returns the ally in State.party with the given id, or null if there isn't one.
func _party_member(id):
	for ally in State.party:
		if ally.id == id:
			return ally
	return null

# Writes each ally's stats from its resource file into the StatNumber labels of its character panel.
func _fill_party_stats():
	for panel_name in CHARACTER_PANEL_IDS:
		var ally = _party_member(CHARACTER_PANEL_IDS[panel_name])
		if ally == null:
			continue
		var stat_numbers = $CharactersPanel.get_node(panel_name + "/SidePanel/StatPanel/StatNumber")
		for label in stat_numbers.get_children():
			if not STAT_PROPERTIES.has(label.name):
				continue
			var values = []
			for property in STAT_PROPERTIES[label.name]:
				values.append(_format_stat(ally.get(property)))
			label.text = "/".join(values)

# Shows whole numbers without a decimal point, so 60.0 reads as 60.
func _format_stat(value):
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return "%.2f" % value

# Combines every ally's exertions and descriptions into one list per type, so the exertion panel shows
# everything the party can do. An exertion more than one ally knows is listed once, at the first ally's price.
# Each type button's Quantity label shows how many exertions that type has.
func _collect_party_exertions():
	party_exertions = {"standard": {}, "mechanics": {}, "imageries": {}}
	party_descriptors = {}
	for ally in State.party:
		for exertion in ally.standard_exertions:
			if not party_exertions["standard"].has(exertion):
				party_exertions["standard"][exertion] = ""
		for type in ["mechanics", "imageries"]:
			var prices: Dictionary = ally.get(type + "_exertions")
			for exertion in prices:
				if not party_exertions[type].has(exertion):
					party_exertions[type][exertion] = str(prices[exertion])
		for exertion in ally.exertions_descriptors:
			if not party_descriptors.has(exertion):
				party_descriptors[exertion] = ally.exertions_descriptors[exertion]
	var type_buttons = $ExertionPanel/ExertionType.get_children()
	for i in min(len(type_buttons), len(EXERTION_TYPES)):
		type_buttons[i].get_node("Quantity").text = str(party_exertions[EXERTION_TYPES[i]].size())

# Fills ExertionList with one row per exertion of the given type, showing its name and MT price.
func _build_exertion_list(type):
	var list = $ExertionPanel/ExertionList
	# Use the first row as the template and detach it so the loop below doesn't free it.
	if exertion_template == null:
		exertion_template = list.get_child(0)
		list.remove_child(exertion_template)
	for row in list.get_children():
		row.free()
	var exertions = party_exertions[type]
	for exertion in exertions:
		var row = exertion_template.duplicate()
		row.get_node("Name").text = exertion
		row.get_node("Quantity").text = exertions[exertion]
		list.add_child(row)
		_disable_mouse(row)
	exertion_shown_pos = 0

# Hides the menu, clears its highlights, and lets the game carry on.
func close_menu():
	# A sub-menu leaves the row it was opened from highlighted, so clear every menu, not just the current one.
	for menu in ["options", "items", "players", "equip_slots", "equippables", "exertion_types", "exertions", "quit", "settings", "controls", "keys"]:
		_clear_highlight(menu)
	current_menu = "options"
	selected_pos = 0
	hide()
	get_tree().paused = false

# Stops buttons from reacting to the mouse or taking focus, so the menu is keyboard-only like the battle menu.
func _disable_mouse(root):
	var buttons = root.find_children("*", "Button", true, false)
	if root is Button:
		buttons.append(root)
	for button in buttons:
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE

# Returns the selectable nodes of a menu in the order the arrow keys move through them.
func _menu_nodes(menu):
	match menu:
		"options": return $OverviewPanel/OptionsPanel.get_children()
		"items": return $ArticlePanel/ArticleList.get_children()
		"players": return $CharactersPanel.get_children()
		"equip_slots": return $EquippablePanelAe/EquipabblesEquip.get_children()
		"equippables": return $EquippablePanelAe/EquippableList.get_children()
		"exertion_types": return $ExertionPanel/ExertionType.get_children()
		"exertions": return $ExertionPanel/ExertionList.get_children()
		"quit": return [$QuitPanel/QuitChoice/Yes, $QuitPanel/QuitChoice/No]
		"settings": return $OptionsPanel/CenterPiece/Content.get_children()
		"controls": return _control_buttons()
		"keys": return $ControlPanel/FunctionAdjustingPanel/Keylist.get_children()
	return []

# The control panel's buttons in the order Up/Down moves through them: the top buttons row by row, then the functions.
func _control_buttons():
	var buttons = [
		$ControlPanel/OptionsPanel/Done,
		$ControlPanel/OptionsPanel/RestoreDefaults,
		$ControlPanel/OptionsPanel/Remove,
		$ControlPanel/OptionsPanel/Calibrate,
		$ControlPanel/OptionsPanel/AssignController,
	]
	buttons.append_array($ControlPanel/FunctionAdjustingPanel/FunctionList.get_children())
	return buttons

# Highlights the selected entry of a menu:
# - a character panel shows its grey ColorRect,
# - an exertion row gets the same grey (25% white) background, so its purple price keeps its colour,
# - every other button turns its text yellow. Article rows show their name and count in child labels,
#   so those labels turn yellow too.
func _set_highlight(node, is_highlighted):
	if not node is Button:
		node.get_child(0).visible = is_highlighted
		return
	if node.get_parent() == $ExertionPanel/ExertionList:
		_set_grey_highlight(node, is_highlighted)
		return
	var text_nodes = [node]
	for child in node.get_children():
		if child is Label:
			text_nodes.append(child)
	for text_node in text_nodes:
		if is_highlighted:
			text_node.add_theme_color_override("font_color", Color("Yellow"))
		else:
			text_node.remove_theme_color_override("font_color")

# Swaps a button's normal style for a copy with the grey highlight background, or puts the original back.
func _set_grey_highlight(button, is_highlighted):
	if not button.has_meta("normal_style"):
		var normal_style = button.get_theme_stylebox("normal")
		# Copy the normal style so the highlight keeps the same content margins and the text doesn't shift.
		var highlight_style = normal_style.duplicate() if normal_style is StyleBoxFlat else StyleBoxFlat.new()
		highlight_style.bg_color = HIGHLIGHT_COLOR
		button.set_meta("normal_style", normal_style)
		button.set_meta("highlight_style", highlight_style)
	button.add_theme_stylebox_override("normal", button.get_meta("highlight_style") if is_highlighted else button.get_meta("normal_style"))

func _clear_highlight(menu):
	for node in _menu_nodes(menu):
		_set_highlight(node, false)

func update_arrow():
	# Only the panel for the current menu is shown; the overview stays behind the quit dialog and comes back once every other panel is closed.
	$OverviewPanel.visible = current_menu in ["options", "quit"]
	$ArticlePanel.visible = current_menu in ["items", "players"]
	$EquippablePanelAe.visible = current_menu in ["equip_slots", "equippables"]
	$ExertionPanel.visible = current_menu in ["exertion_types", "exertions"]
	$QuitPanel.visible = current_menu == "quit"
	$OptionsPanel.visible = current_menu == "settings"
	$ControlPanel.visible = current_menu in ["controls", "keys"]
	# The equippable and exertion lists sit where the character panel is, and the options and control panels stand alone, so hide it behind them.
	$CharactersPanel.visible = not ($EquippablePanelAe.visible or $ExertionPanel.visible or $OptionsPanel.visible or $ControlPanel.visible)

	options = _menu_nodes(current_menu)
	limit = len(options)-1
	selected_pos = clamp(selected_pos, 0, max(limit, 0))
	for i in len(options):
		_set_highlight(options[i], i == selected_pos)

	if current_menu=="items":
		if selected_pos-shown_pos>10:
			shown_pos=selected_pos-10
		if selected_pos<shown_pos:
			shown_pos=selected_pos
		move()

	if current_menu=="exertion_types":
		$ExertionPanel/ExertionDescription.text = ""
	elif current_menu=="exertions":
		# Scroll so the highlighted row stays in view, like the article list.
		if selected_pos-exertion_shown_pos>EXERTION_ROWS_SHOWN-1:
			exertion_shown_pos=selected_pos-(EXERTION_ROWS_SHOWN-1)
		if selected_pos<exertion_shown_pos:
			exertion_shown_pos=selected_pos
		_scroll_list($ExertionPanel/ExertionList, exertion_shown_pos, EXERTION_ROWS_SHOWN)
		var exertion = options[selected_pos].get_node("Name").text if not options.is_empty() else ""
		$ExertionPanel/ExertionDescription.text = party_descriptors.get(exertion, "")

func _open(menu):
	current_menu = menu
	selected_pos = 0
	update_arrow()

# C opens the menu. It opens from _unhandled_input, so a scene can keep it shut by handling C in its
# own _input first, as the outside scene does while Elizyka's dialogue is open.
func _unhandled_input(event: InputEvent) -> void:
	if not visible and event.is_action_pressed("open_pause_menu") and not event.is_echo():
		get_viewport().set_input_as_handled()
		open_menu()

func _physics_process(delta: float) -> void:
	# Nothing reacts while the menu is hidden.
	if not visible:
		return
	# X or Esc goes back one panel, like in battle. On the overview, the first panel, it closes the menu.
	if Input.is_action_just_pressed("menu_back") or Input.is_action_just_pressed("ui_cancel"):
		if current_menu == "options":
			close_menu()
		else:
			back()
		return
	if current_menu=="quit":
		if Input.is_action_just_pressed("walk_right"):
			if selected_pos<limit:
				selected_pos+=1
				update_arrow()
		if Input.is_action_just_pressed("walk_left"):
			if selected_pos>0:
				selected_pos-=1
				update_arrow()
	else:
		if Input.is_action_just_pressed("walk_down"):
			if selected_pos<limit:
				selected_pos+=1
			update_arrow()
		if Input.is_action_just_pressed("walk_up"):
			if selected_pos>0:
				selected_pos-=1
			update_arrow()
	# Enter, or Z (interact), confirms and moves on to the next panel, like in battle.
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact"):
		if current_menu == "options":
			if selected_pos == 0:
				if $ArticlePanel/ArticleList.get_child_count() > 0:
					_open("items")
			elif selected_pos == 1:
				_open("equip_slots")
			elif selected_pos == 2:
				_open("exertion_types")
			elif selected_pos == 3:
				save()
			elif selected_pos == 4:
				loadsave()
			elif selected_pos == 5:
				_open("quit")
			elif selected_pos == 6:
				_open("settings")
		elif current_menu == "items":
			if not options.is_empty():
				selected_item=options[selected_pos].get_child(0).text
				selected_item_pos=selected_pos
				_open("players")
		elif current_menu == "players":
			if inventory[selected_item] > 0:
				use(selected_item,players[selected_pos])
			_items()
			back()
		elif current_menu == "equip_slots":
			selected_slot_pos=selected_pos
			_open("equippables")
		elif current_menu == "equippables":
			equip($EquippablePanelAe/EquipabblesEquip.get_child(selected_slot_pos).name, options[selected_pos].get_child(0).text)
			back()
		elif current_menu == "exertion_types":
			# A type with no exertions has nothing to open.
			var type = EXERTION_TYPES[selected_pos]
			if not party_exertions[type].is_empty():
				selected_type_pos=selected_pos
				_build_exertion_list(type)
				_open("exertions")
		elif current_menu == "exertions":
			choose_exertion($ExertionPanel/ExertionType.get_child(selected_type_pos).get_child(0).text, options[selected_pos].get_child(0).text)
			back()
		elif current_menu == "quit":
			if selected_pos ==0:
				quit()
			else:
				back()
		elif current_menu == "settings":
			if options[selected_pos] == $OptionsPanel/CenterPiece/Content/Controller:
				_open("controls")
		elif current_menu == "controls":
			var button = options[selected_pos]
			# Done does the same as X or Esc: it goes back one panel.
			if button == $ControlPanel/OptionsPanel/Done:
				back()
			elif button.get_parent() == $ControlPanel/FunctionAdjustingPanel/FunctionList:
				selected_function_pos = selected_pos
				_open_keys(button)
		elif current_menu == "keys":
			var function_button = _chosen_function_button()
			rebind(function_button.text, options[selected_pos].text)
			back()
func back():
	_clear_highlight(current_menu)
	if current_menu in MENU_OPTION_INDEX:
		selected_pos = MENU_OPTION_INDEX[current_menu]
		current_menu = "options"
	elif current_menu=="players":
		current_menu="items"
		selected_pos= selected_item_pos
	elif current_menu=="equippables":
		current_menu="equip_slots"
		selected_pos=selected_slot_pos
	elif current_menu=="exertions":
		current_menu="exertion_types"
		selected_pos=selected_type_pos
	elif current_menu=="controls":
		current_menu="settings"
		selected_pos=$OptionsPanel/CenterPiece/Content/Controller.get_index()
	elif current_menu=="keys":
		current_menu="controls"
		selected_pos=selected_function_pos
	update_arrow()

# Moves from a function to the key list, starting on the key in the same row. The function and key
# lists have the same number of buttons, so the key is the one with the same index as the function.
func _open_keys(function_button):
	current_menu = "keys"
	selected_pos = 0
	var keys = _menu_nodes("keys")
	for i in len(keys):
		if keys[i].get_index() == function_button.get_index():
			selected_pos = i
			break
	update_arrow()

# The function button the key list was opened from.
func _chosen_function_button():
	return _control_buttons()[selected_function_pos]

func _items():
	# Use the first list entry as the template if none is assigned, and detach it so the loop below doesn't free it.
	if item_template == null:
		item_template = $ArticlePanel/ArticleList.get_child(0)
	if item_template.get_parent() == $ArticlePanel/ArticleList:
		$ArticlePanel/ArticleList.remove_child(item_template)
	for i in $ArticlePanel/ArticleList.get_children():
		i.free()
	for i in inventory.duplicate():
		if inventory[i]==0:
			inventory.erase(i)
			continue
		item=item_template.duplicate()
		item.show()
		item.get_child(0).text=i
		item.get_child(1).text=str(inventory[i])
		$ArticlePanel/ArticleList.add_child(item)
		_disable_mouse(item)
func move():
	_scroll_list($ArticlePanel/ArticleList, shown_pos, 11)

# Shows rows_shown rows of a list starting at first_shown, stacked 80px apart, and hides the rest.
func _scroll_list(list, first_shown, rows_shown):
	var rows = list.get_children()
	for i in len(rows):
		if i < first_shown:
			rows[i].hide()
		elif i-first_shown<rows_shown:
			rows[i].position=Vector2(4,4+80*(i-first_shown))
			rows[i].show()
		else:
			rows[i].hide()
func quit():
	get_tree().quit()
# The detached templates aren't in the scene tree, so free them manually to avoid a leak.
func _exit_tree() -> void:
	for template in [item_template, exertion_template]:
		if template != null and template.get_parent() == null:
			template.queue_free()
func use(item,player):
	print("used %s on %s" % [item, player])
	inventory[item]-=1
func equip(slot,equippable):
	print("equipped %s in %s" % [equippable, slot])
func choose_exertion(exertion_type,exertion):
	print("chose %s from %s" % [exertion, exertion_type])
func rebind(function_name, key_name):
	print("chose %s for %s" % [key_name, function_name])

func save():
	pass
func loadsave():
	pass
