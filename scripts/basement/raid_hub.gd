extends Node3D

@onready var model: Node3D = $Basement
@onready var player: CharacterBody3D = $Player


func _ready() -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for index in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(index) as StandardMaterial3D
			if material != null and material.albedo_texture != null:
				material.vertex_color_use_as_albedo = true
		var label := String(mesh.name)
		if not label.begins_with("Concrete stair tread") and not label.begins_with("Steel stair nosing"):
			mesh.create_trimesh_collision()
	_build_stair_ramp()

	var exit := _marker("SOCKET_EXIT") + Vector3(0, 1.15, 0.45)
	RunInteraction.create(self, exit, "Start mall raid", RunState.begin_raid,
		func() -> bool: return RunState.phase == RunState.Phase.MORNING)
	RunInteraction.create(self, _marker("USE_REST") + Vector3(-2.9, 1.05, 0.9),
		"Rest / start a new run", RunState.rest, func() -> bool:
			return RunState.phase == RunState.Phase.EVENING or RunState.phase == RunState.Phase.ENDED)
	RunInteraction.create(self, _marker("USE_FRIDGE") + Vector3(0.3, 1.1, 0),
		"Open fridge", player._open_storage.bind(KitchenStorages.ID_FRIDGE))
	RunInteraction.create(self, _marker("USE_DRINK") + Vector3(0, 1.1, 0),
		"Water supplies", player._open_storage.bind(KitchenStorages.ID_DRINK_FRIDGE))
	RunInteraction.create(self, _marker("USE_COOK") + Vector3(0, 1.1, 0),
		"Medical supplies", player._open_storage.bind(KitchenStorages.ID_DRAWERS))

	for point in [Vector3(-3, 2.48, 2.2), Vector3(0.3, 2.48, -3.3),
			Vector3(2.6, 2.48, 2.5), Vector3(2.6, 2.48, 6.3), Vector3(7.25, 2.48, 2.75),
			Vector3(4.46, 3.5, -3.7)]:
		var lamp := OmniLight3D.new()
		lamp.position = point
		lamp.light_color = Color("#e4ceaa")
		lamp.light_energy = 1.5
		lamp.omni_range = 4.5
		add_child(lamp)


func _marker(marker_name: String) -> Vector3:
	var marker := model.find_child(marker_name, true, false) as Node3D
	return to_local(marker.global_position)


func _build_stair_ramp() -> void:
	var ramp := StaticBody3D.new()
	# Sink the lower edge into the floor so the flat player collider can enter the slope.
	ramp.position = Vector3(4.46, 1.24, -2.08)
	ramp.rotation.x = atan2(3.02, 4.75)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.66, 0.12, 5.63)
	collider.shape = shape
	add_child(ramp)
	ramp.add_child(collider)

	var barrier := StaticBody3D.new()
	barrier.position = Vector3(4.46, 3.8, -4.97)
	var stop := CollisionShape3D.new()
	var wall := BoxShape3D.new()
	wall.size = Vector3(1.8, 2.0, 0.12)
	stop.shape = wall
	add_child(barrier)
	barrier.add_child(stop)
