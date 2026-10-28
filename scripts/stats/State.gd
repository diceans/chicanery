extends Node

var current_WN = 60
var max_WN = 60
var VHM = 12
var ERL = 16
var EB = 0
var EM = 1
var pi_ACM = 1
var pi_DIM = 1
var actions = ["ASSAULT", "EXERT", "ARTICLE", "BRACE"]
var exertions = ["FORBEAR", "FORSAKE", "FORDOOM"]
var return_player_to_enemy = false
var active_enemy_id: StringName = &""
var defeated_enemy_ids: Dictionary = {}
