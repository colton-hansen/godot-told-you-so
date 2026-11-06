extends Node

var loadout: PlayerLoadout


func _ready() -> void:
	loadout = PlayerLoadout.new()
	loadout.backpack_enabled = true
