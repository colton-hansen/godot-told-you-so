class_name RunInteraction
extends Node3D

var prompt := ""
var action: Callable
var available: Callable


func _ready() -> void:
	add_to_group(&"run_interaction")


func enabled() -> bool:
	return not available.is_valid() or available.call()


static func create(parent: Node3D, point: Vector3, label: String, callback: Callable,
		condition: Callable = Callable()) -> RunInteraction:
	var target := RunInteraction.new()
	target.position = point
	target.prompt = label
	target.action = callback
	target.available = condition
	parent.add_child(target)
	return target
