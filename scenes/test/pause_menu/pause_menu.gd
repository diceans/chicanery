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
var players = ["ae","elizyka","kletzt","wilseffin"]
var limit = 6
var options = []
@export var item_template: Node
@export var arrow: Node
var menu_button_font_colors
const HIGHLIGHT_COLOR = Color(1, 1, 1, 0.25)
# Which overview option opens each sub-menu, so backing out puts the cursor back on it.
const MENU_OPTION_INDEX = {"items": 0, "equip_slots": 1, "exertion_types": 2, "quit": 5}

func _ready() -> void:
	$OverviewPanel.position = Vector2(0, -26)
	$QuitPanel.position = Vector2(0, 0)
	$EquippablePanelAe.position = Vector2(0, -27)
	$ArticlePanel.position = Vector2(0, 0)
	$CharactersPanel.position = Vector2(1126, 36)
	$ExertionPanel.position = Vector2(0, 0)

	$ArticlePanel.hide()
	$QuitPanel.hide()
	$EquippablePanelAe.hide()
	$ExertionPanel.hide()
	_disable_mouse(self)
	# Each character panel's first child is a ColorRect used as its highlight background.
	for panel in $CharactersPanel.get_children():
		panel.get_child(0).color = HIGHLIGHT_COLOR
		panel.get_child(0).hide()
	_items()
	update_arrow()

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
	return []

# Shows or hides the 25% white background behind a button, or the highlight ColorRect of a character panel.
func _set_highlight(node, is_highlighted):
	if not node is Button:
		node.get_child(0).visible = is_highlighted
		return
	if not node.has_meta("normal_style"):
		var normal_style = node.get_theme_stylebox("normal")
		# Copy the normal style so the highlight keeps the same content margins and the text doesn't shift.
		var highlight_style = normal_style.duplicate() if normal_style is StyleBoxFlat else StyleBoxFlat.new()
		highlight_style.bg_color = HIGHLIGHT_COLOR
		node.set_meta("normal_style", normal_style)
		node.set_meta("highlight_style", highlight_style)
	node.add_theme_stylebox_override("normal", node.get_meta("highlight_style") if is_highlighted else node.get_meta("normal_style"))

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
	# The equippable and exertion lists sit where the character panel is, so hide it behind them.
	$CharactersPanel.visible = not ($EquippablePanelAe.visible or $ExertionPanel.visible)

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

func _open(menu):
	current_menu = menu
	selected_pos = 0
	update_arrow()

func _physics_process(delta: float) -> void:
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
	if Input.is_action_just_pressed("ui_accept"):
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
			selected_type_pos=selected_pos
			_open("exertions")
		elif current_menu == "exertions":
			choose_exertion($ExertionPanel/ExertionType.get_child(selected_type_pos).get_child(0).text, options[selected_pos].get_child(0).text)
			back()
		elif current_menu == "quit":
			if selected_pos ==0:
				quit()
			else:
				back()
	if Input.is_action_just_pressed("ui_text_backspace"):
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
	update_arrow()

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
	for i in len($ArticlePanel/ArticleList.get_children()):
		if i < shown_pos:
			$ArticlePanel/ArticleList.get_children()[i].hide()
		elif i-shown_pos<11:
			$ArticlePanel/ArticleList.get_children()[i].position=Vector2(4,4+80*(i-shown_pos))
			$ArticlePanel/ArticleList.get_children()[i].show()
		else:
			$ArticlePanel/ArticleList.get_children()[i].hide()
func quit():
	get_tree().quit()
# The detached template isn't in the scene tree, so free it manually to avoid a leak.
func _exit_tree() -> void:
	if item_template != null and item_template.get_parent() == null:
		item_template.queue_free()
func use(item,player):
	print("used %s on %s" % [item, player])
	inventory[item]-=1
func equip(slot,equippable):
	print("equipped %s in %s" % [equippable, slot])
func choose_exertion(exertion_type,exertion):
	print("chose %s from %s" % [exertion, exertion_type])

func save():
	pass
func loadsave():
	pass
