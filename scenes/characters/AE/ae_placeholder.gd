class_name AE
extends CharacterBody2D

# Stores the last non-zero walking direction so the animation states know which sprite to display.
var ae_direction: Vector2
# The tile AE last stood on, recorded each time a step starts. AE touches an enemy partway through a
# step, so this is the last whole tile AE was on before the contact.
var tile_position: Vector2
