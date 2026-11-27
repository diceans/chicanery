class_name AE
extends CharacterBody2D

# Stores the last non-zero walking direction so the animation states know which sprite to display.
var ae_direction: Vector2
# The tile AE last stood on, recorded each time a step starts. AE touches an enemy partway through a
# step, so this is the last whole tile AE was on before the contact.
var tile_position: Vector2

# The tiles AE's current step is leaving and entering, empty while standing still. Walking NPCs won't
# start a step into these. See GridReservations.
var reserved_tiles: Array[Vector2] = []

func _ready() -> void:
	add_to_group(GridReservations.GROUP)

# Emitted when a walking NPC runs into AE mid-step, so AE's walk state stops the step too.
# With tile reservations this shouldn't happen any more; it is kept as a fallback so they can never lock up.
@warning_ignore("unused_signal")
signal bumped
