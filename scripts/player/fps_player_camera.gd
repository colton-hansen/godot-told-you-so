extends Camera3D

const WORLD_LAYER: int = 1
const HIDDEN_FROM_PLAYER_LAYER: int = 2


func _ready() -> void:
	var all_layers := (1 << 20) - 1
	cull_mask = all_layers & ~HIDDEN_FROM_PLAYER_LAYER
