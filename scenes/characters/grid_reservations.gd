class_name GridReservations

# Characters that walk tile by tile (AE and walking NPCs) join this group and keep a reserved_tiles
# array: while a step is underway it holds the tile they're leaving and the tile they're stepping to,
# and it is empty while they stand still. A character standing still is already caught by test_move,
# but a step's destination is still empty when another character checks it, so it has to be reserved.
const GROUP := &"grid_walkers"

# Whether any grid walker other than `walker` has reserved a tile that overlaps `tile`.
# Tiles count as overlapping when they are less than a tile apart on both axes, so this still works
# if two characters' grids are not lined up exactly.
static func is_reserved(walker: Node, tile: Vector2, tile_size: float) -> bool:
	for other in walker.get_tree().get_nodes_in_group(GROUP):
		if other == walker:
			continue
		for reserved: Vector2 in other.reserved_tiles:
			if absf(tile.x - reserved.x) < tile_size and absf(tile.y - reserved.y) < tile_size:
				return true
	return false
