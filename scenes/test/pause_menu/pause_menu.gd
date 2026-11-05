extends Control

func _ready() -> void:
	$OverviewPanel.position = Vector2(0, -26)
	$QuitPanel.position = Vector2(0, 0)
	$EquippablePanelAe.position = Vector2(0, 0)
	$ArticlePanel.position = Vector2(0, 0)
	$CharactersPanel.position = Vector2(1126, 36)
	$ExertionPanel.position = Vector2(0, 0)
	
	$ArticlePanel.hide()
	$QuitPanel.hide()
	$EquippablePanelAe.hide()
	$OverviewPanel.hide()
	$CharactersPanel.hide()
