extends Resource

@export var name: String = "Enemy" 
@export var texture: Texture = null
@export var WN: float = 20
@export var VHM: float = 20
@export var ERL: float = 20
@export var EB: float = 0
@export var EM: float = 1
@export var pi_ACM: float = 1
@export var pi_tDIM: float = 1
@export var exertions: Array = []
@export var exertion_locked: bool = false
@export var locked_exertion: String = ""
@export_range(0, 100) var exertion_lock_turns: int = 0
