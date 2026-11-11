extends Node3D

const SCALE := 1.5
const STEP := 0.2
const ROOMS := [Rect2(-3, -3, 3, 4.2), Rect2(0, -3, 2, 2.2), Rect2(0, -0.8, 5.2, 2), Rect2(3.2, -3, 2, 2.2)]
var cells := {}
@onready var player: CharacterBody3D = $Player

func _ready() -> void:
	# Coordinates follow Blender's X / -Y floor plan, enlarged for usable passages.
	for room: Rect2 in ROOMS:
		var middle := room.get_center() * SCALE
		_box(Vector3(middle.x, -0.08, middle.y), Vector3(room.size.x * SCALE, 0.16, room.size.y * SCALE), Color("#66665c"))
	for x in range(-15, 26):
		for z in range(-15, 6):
			var center := Vector2((x + 0.5) * STEP, (z + 0.5) * STEP)
			for room: Rect2 in ROOMS:
				if room.has_point(center):
					cells[Vector2i(x, z)] = true
	for cell: Vector2i in cells:
		var center := Vector3((cell.x + 0.5) * STEP * SCALE, -0.08, (cell.y + 0.5) * STEP * SCALE)
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not cells.has(cell + side):
				var offset := Vector3(side.x, 0, side.y) * STEP * SCALE * 0.5
				var size := Vector3(0.10, 2.7, STEP * SCALE) if side.x != 0 else Vector3(STEP * SCALE, 2.7, 0.10)
				_box(center + offset + Vector3.UP * 1.43, size, Color("#8c9185"))
	_prop("dorm-kitchenette", Vector3(-3.55, 0, -3.6), 2.6, 0)
	_prop("fridge-freezer", Vector3(-1.35, 0, -3.8), 0.8, 0)
	_prop("wire-shelving", Vector3(1.6, 0, -3.8), 1.4, 0)
	_prop("lounge-sofa", Vector3(-3.5, 0, 0.7), 2.2, PI)
	_prop("dining-table", Vector3(-2.6, 0, -1.2), 1.35, 0)
	_prop("area-rug", Vector3(-2.5, 0.01, -0.8), 2.2, 0, false)
	_prop("sideboard", Vector3(0.5, 0, -2.3), 1.3, PI / 2)
	_prop("field-workbench", Vector3(6.1, 0, -3.8), 1.6, 0)
	_prop("wall-first-aid", Vector3(7.65, 1.2, -2.5), 0.5, -PI / 2, false)
	_prop("fire-extinguisher", Vector3(7.4, 0, 0.9), 0.3, 0)
	_prop("floor-houseplant", Vector3(-4.0, 0, -0.2), 0.65, 0)
	_prop("exit-sign", Vector3(7.55, 2.1, -0.4), 0.65, -PI / 2, false)
	# Ventilation footprint from sketch, raised above the corridor.
	_box(Vector3(3.9, 2.45, -3), Vector3(1.2, 0.35, 3), Color("#515e61"), false)
	for point in [Vector3(-2.4, 2.4, -1.6), Vector3(1.5, 2.4, -2.9), Vector3(4.7, 2.4, 0.5), Vector3(6.5, 2.4, -3)]:
		var lamp := OmniLight3D.new()
		lamp.position = point
		lamp.light_color = Color("#f5dfb0")
		lamp.light_energy = 2.0
		lamp.omni_range = 6
		add_child(lamp)
	RunInteraction.create(self, Vector3(7.1, 1.1, -0.35), "Start mall raid", RunState.begin_raid, func() -> bool: return RunState.phase == RunState.Phase.MORNING)
	RunInteraction.create(self, Vector3(-3.5, 1, 0.7), "Rest / start a new run", RunState.rest, func() -> bool: return RunState.phase in [RunState.Phase.EVENING, RunState.Phase.ENDED])
	RunInteraction.create(self, Vector3(-1.35, 1, -3.3), "Open fridge", player._open_storage.bind(KitchenStorages.ID_FRIDGE))
	RunInteraction.create(self, Vector3(1.6, 1, -3.3), "Medical supplies", player._open_storage.bind(KitchenStorages.ID_DRAWERS))
	RunInteraction.create(self, Vector3(-3.4, 1, -3.4), "Water supplies", player._open_storage.bind(KitchenStorages.ID_DRINK_FRIDGE))

func _box(point: Vector3, size: Vector3, color: Color, solid: bool = true) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material_override = material
	mesh.position = point
	add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		mesh.add_child(body)
		body.add_child(collision)

func _prop(prefix: String, point: Vector3, width: float, yaw: float, solid: bool = true) -> Node3D:
	var node: Node3D
	for file in DirAccess.get_files_at("res://assets/props/build"):
		if file.begins_with(prefix) and file.ends_with(".glb"):
			node = (load("res://assets/props/build/" + file) as PackedScene).instantiate() as Node3D
			break
	assert(node != null, "Missing hub prop: " + prefix)
	add_child(node)
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as StandardMaterial3D
			if material != null:
				material.vertex_color_use_as_albedo = true
		var local_bounds: AABB = (node.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = local_bounds if first else bounds.merge(local_bounds)
		first = false
	var factor := width / maxf(bounds.size.x, 0.01)
	node.scale = Vector3.ONE * factor
	node.rotation.y = yaw
	var base := bounds.get_center()
	base.y = bounds.position.y
	node.position = point - node.basis * base
	if solid:
		for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			mesh.create_trimesh_collision()
	return node
