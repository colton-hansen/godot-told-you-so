extends Node

var loadout: PlayerLoadout


func _ready() -> void:
	loadout = RunState.inventory
