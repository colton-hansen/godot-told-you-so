extends Node
## Marks kitchen meshes as interactable. Picking is triangle-accurate (no oversized AABB areas).
## Fridge / cabinets / appliances map by Blender mesh names. Kitchen sofa is `sofa` (not `sofa_001`).

const GROUP_INTERACT_MESH := &"interactable_mesh"

@export var enabled: bool = true


func _ready() -> void:
	if not enabled:
		return
	call_deferred("_build_regions")


func _build_regions() -> void:
	var sketch: Node3D = get_parent().get_node_or_null("BasementSketch") as Node3D
	if sketch == null:
		return
	_scan_mesh(sketch)


func _scan_mesh(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var mesh: Mesh = mi.mesh
		if mesh != null:
			if _is_kitchen_sofa(mi.name):
				_tag_seat(mi)
			else:
				var sid := _storage_for_name(mi.name)
				if sid != StringName():
					_tag_mesh(mi, sid)
	for c: Node in n.get_children():
		_scan_mesh(c)


func _is_kitchen_sofa(mesh_name: String) -> bool:
	# Кухонный диван в GLB называется `sofa`. `sofa_001` — другой, его не трогаем.
	return mesh_name.to_lower() == "sofa"


func _storage_for_name(mesh_name: String) -> StringName:
	var s := mesh_name.to_lower()
	if s.contains("metal-shelves") or s.contains("metal_shelves") or (s.contains("metal") and s.contains("shelf")):
		return KitchenStorages.ID_METAL_SHELVES
	if s.contains("toster") or s.contains("toaster"):
		return KitchenStorages.ID_TOASTER
	if s.contains("microwave"):
		return KitchenStorages.ID_MICROWAVE
	if s == "tv" or s.contains("television"):
		return KitchenStorages.ID_TV
	if s.contains("fridge") or s.contains("refrigerator") or s.contains("freezer-door") or s.contains("fridge-door"):
		return KitchenStorages.ID_FRIDGE
	if s.contains("countertop") or s.contains("kitchen-countertop"):
		return StringName()
	if (
		s.contains("hanging-kitchen-furniture")
		or s.contains("standing-kitchen-furniture")
		or s.contains("kitchen-furniture")
		or s.contains("kitchen cabinet")
		or s.contains("kitchen furniture")
		or s.contains("cupboard")
		or s.contains("wall cabinet")
		or s.contains("base cabinet")
		or (
			s.contains("cabinet")
			and not s.contains("microwave")
			and not s.contains("range hood")
		)
	):
		return KitchenStorages.ID_CABINETS
	return StringName()


func _tag_mesh(mi: MeshInstance3D, storage_id: StringName) -> void:
	mi.add_to_group(GROUP_INTERACT_MESH)
	mi.set_meta(&"interact_kind", &"storage")
	mi.set_meta(&"storage_id", storage_id)
	var mesh: Mesh = mi.mesh
	if mesh != null:
		mi.set_meta(&"interact_faces", mesh.get_faces())


func _tag_seat(mi: MeshInstance3D) -> void:
	mi.add_to_group(GROUP_INTERACT_MESH)
	mi.set_meta(&"interact_kind", &"sit")
	var mesh: Mesh = mi.mesh
	if mesh != null:
		mi.set_meta(&"interact_faces", mesh.get_faces())
