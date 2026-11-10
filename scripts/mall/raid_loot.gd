extends Node3D

const MODELS := {
	&"canned_food": preload("res://assets/models/mall/loot/canned_food.glb"),
	&"water_bottle": preload("res://assets/models/mall/loot/water_bottle.glb"),
	&"bandage": preload("res://assets/models/mall/loot/bandage.glb"),
}

var item: ItemDefinition


func _ready() -> void:
	var model: PackedScene = MODELS[item.id]
	var prop := model.instantiate() as Node3D
	prop.position.y = -0.12
	add_child(prop)
	RunInteraction.create(self, Vector3(0, 0.12, 0), "Take " + item.display_name, _take)


func _take() -> void:
	if RunState.take_loot(item):
		queue_free()
