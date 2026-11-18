class_name Walking_NPC
extends CharacterBody2D

@export var min_walk_cycle: int = 2
@export var max_walk_cycle: int = 6

var walk_cycles: int
var current_walk_cycles: int
# Last direction the NPC moved in, so the idle state keeps facing the same way.
var facing: Vector2 = Vector2.DOWN
