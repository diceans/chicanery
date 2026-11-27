class_name Walking_NPC
extends CharacterBody2D

@export var min_walk_cycle: int = 2
@export var max_walk_cycle: int = 6

var walk_cycles: int
var current_walk_cycles: int
# Last direction the NPC moved in, so the idle state keeps facing the same way.
var facing: Vector2 = Vector2.DOWN

# The tiles the NPC's current step is leaving and entering, empty while standing still. AE and other
# walking NPCs won't start a step into these. See GridReservations.
var reserved_tiles: Array[Vector2] = []

func _ready() -> void:
	add_to_group(GridReservations.GROUP)

# Emitted when AE runs into this NPC mid-step, so the NPC's walk state stops the step too.
# With tile reservations this shouldn't happen any more; it is kept as a fallback so they can never lock up.
@warning_ignore("unused_signal")
signal bumped
