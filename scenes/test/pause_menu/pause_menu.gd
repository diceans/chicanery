extends Control
var inventory = {
	"appl of paradise":0, 
	"hellshroom":1, 
	"hibiscus flower":5,
	"instant noodles": 4,
	"macefruit":5,
	"mead":1,
	"mystery tupperware":8,
	"pocket sand":7,
	"pomergrenade":10,
	"pilk":78,
	"10 hour burst":66,
	"bonk atomic punch":9,
	"can of wellcheers":2,
	"ironskin potion":9
}
var item
var selected_pos =0
var shown_pos = 0
var current_menu = "options"
var selected_item
var selected_item_pos
var players = ["ae","elizyka","kletzt","wilseffin"]
var limit = 6
var options
@export var item_template: Node
@export var arrow: Node
var menu_button_font_colors

func _ready() -> void:
	$ArticlePanel.hide()
	$QuitPanel.hide()
	_items()
	update_arrow()
func update_arrow():
	if current_menu=="quit":
		$QuitPanel.show()
	else:
		$QuitPanel.hide()
	if current_menu=="items" or current_menu=="players":
		$ArticlePanel.show()
		
	else:
		$ArticlePanel.hide()
	
	if selected_pos>limit:
		selected_pos=limit
	if current_menu == "options":
		options=$OverviewPanel/OptionsPanel/VBoxContainer
		for i in len(options.get_children()):
			if i == selected_pos:
				options.get_children()[i].modulate= Color("Yellow")
			else:
				options.get_children()[i].modulate= Color("White")
	if current_menu == "items":
		options=$ArticlePanel/List
		for i in len(options.get_children()):
			if i == selected_pos:
				options.get_children()[i].get_child(0).modulate= Color("Yellow")
			else:
				options.get_children()[i].get_child(0).modulate= Color("White")
	if current_menu == "players":
		options=$CharactersPanel
		for i in len(options.get_children()):
			if i == selected_pos:
				options.get_children()[i].get_child(0).show()
			else:
				options.get_children()[i].get_child(0).hide()
	if current_menu == "quit":
		if selected_pos==0:
			$QuitPanel/QuitChoice/Yes.modulate=Color("Yellow")
			$QuitPanel/QuitChoice/No.modulate=Color("White")
		else:
			$QuitPanel/QuitChoice/Yes.modulate=Color("White")
			$QuitPanel/QuitChoice/No.modulate=Color("Yellow")
	if selected_pos-shown_pos>10:
		shown_pos=selected_pos-10
	if selected_pos<shown_pos:
		shown_pos=selected_pos
	if current_menu=="items":
		move()
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
	if Input.is_action_just_pressed("interact"):
		if current_menu == "options":
			if selected_pos == 0:
				limit=len(inventory)-1
				$ArticlePanel.show()
				current_menu = "items"
				update_arrow()
			elif selected_pos == 3:
				save()
			elif selected_pos == 4:
				selected_pos=0
				limit = 1
				current_menu = "quit"
				update_arrow()
			elif selected_pos == "5":
				loadsave()
		elif current_menu == "items":
			selected_item=$ArticlePanel/List.get_children()[selected_pos].get_child(0).text
			selected_item_pos=selected_pos
			current_menu="players"
			selected_pos=0
			limit = 3
			update_arrow()
		elif current_menu == "players":
			if inventory[selected_item] > 0:
				use(selected_item,players[selected_pos])
			_items()
			back()
		elif current_menu == "quit":
			if selected_pos ==0:
				quit()
			else:
				back()
	if Input.is_action_just_pressed("ui_accept"):
		back()
func back():
	if current_menu=="quit" or current_menu=="items":
		current_menu="options"
		limit= 6
		selected_pos=0
	if current_menu=="players":
		current_menu="items"
		selected_pos= selected_item_pos
		limit = len(inventory)-1
		for i in len($CharactersPanel.get_children()):
			options.get_children()[i].get_child(0).hide()
	update_arrow()

func _items():
	for i in $ArticlePanel/List.get_children():
		i.free()
	for i in inventory.duplicate():
		if inventory[i]==0:
			inventory.erase(i)
			continue
		item=item_template.duplicate()
		item.show()
		item.get_child(0).text=i
		item.get_child(1).text=str(inventory[i])
		$ArticlePanel/List.add_child(item)
func move():
	for i in len($ArticlePanel/List.get_children()):
		if i < shown_pos:
			$ArticlePanel/List.get_children()[i].hide()
		elif i-shown_pos<11:
			$ArticlePanel/List.get_children()[i].position=Vector2(4,4+80*(i-shown_pos))
			$ArticlePanel/List.get_children()[i].show()
		else:
			$ArticlePanel/List.get_children()[i].hide()
func quit():
	get_tree().quit()
func use(item,player):
	print("used %s on %s" % [item, player])
	inventory[item]-=1
	
func save():
	pass
func loadsave():
	pass
