extends Node3D
## Collision for imported map: one merged trimesh + thin safety floor.
## Per-mesh trimesh bodies leave tiny gaps between adjacent meshes; merging removes those "holes".

@export var enabled: bool = true
## Pads the safety floor horizontally so character snap still hits solid under mesh edges.
@export var safety_floor_margin: float = 3.0
@export var safety_floor_thickness: float = 0.25
## Blender exports often have inward-facing normals; Godot culls backfaces → looks like "holes".
@export var materials_double_sided: bool = true


func _ready() -> void:
	if not enabled:
		return
	var sketch: Node3D = get_node_or_null("BasementSketch") as Node3D
	if sketch == null:
		return
	if materials_double_sided:
		_apply_double_sided_materials(sketch)
	var merged: ArrayMesh = _build_merged_mesh(sketch)
	if merged == null:
		push_warning("basement_map_collision: failed to build merged mesh")
		return
	var trimesh_shape: Shape3D = merged.create_trimesh_shape()
	if trimesh_shape == null:
		push_warning("basement_map_collision: create_trimesh_shape failed")
		return
	var body := StaticBody3D.new()
	body.name = "MapCollisionMerged"
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	col.shape = trimesh_shape
	body.add_child(col)
	sketch.add_child(body)
	_add_safety_floor(sketch, merged)


func _apply_double_sided_materials(root: Node) -> void:
	if root is MeshInstance3D:
		_double_side_mesh_instance(root as MeshInstance3D)
	for c: Node in root.get_children():
		_apply_double_sided_materials(c)


func _double_side_mesh_instance(mi: MeshInstance3D) -> void:
	var mesh: Mesh = mi.mesh
	if mesh == null:
		return
	for surface_idx: int in range(mesh.get_surface_count()):
		var mat: Material = mi.get_active_material(surface_idx)
		if mat == null:
			continue
		if mat is BaseMaterial3D:
			var bm := mat.duplicate() as BaseMaterial3D
			bm.cull_mode = BaseMaterial3D.CULL_DISABLED
			mi.set_surface_override_material(surface_idx, bm)


func _build_merged_mesh(sketch: Node3D) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inv := sketch.global_transform.affine_inverse()
	var any := _append_surfaces_recursive(sketch, inv, st)
	if not any:
		return null
	return st.commit()


func _append_surfaces_recursive(node: Node, inv_sketch: Transform3D, st: SurfaceTool) -> bool:
	# Skinned preview characters in the FBX cannot be merged (bones/weights).
	if node is Skeleton3D:
		return false
	var any := false
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if (
			mi.skin == null
			and not _is_swing_door_or_frame(mi)
			and not _is_fridge_door_mesh(mi)
			and not _is_drawer_mesh(mi)
			and not _is_lid_mesh(mi)
		):
			var mesh: Mesh = mi.mesh
			var am := mesh as ArrayMesh
			if am != null:
				var xf: Transform3D = inv_sketch * mi.global_transform
				for si: int in range(am.get_surface_count()):
					st.append_from(am, si, xf)
					any = true
	for c: Node in node.get_children():
		any = _append_surfaces_recursive(c, inv_sketch, st) or any
	return any


func _is_swing_door_or_frame(mi: MeshInstance3D) -> bool:
	var n := String(mi.name).to_lower()
	if n.begins_with("frame") or n.begins_with("door-frame"):
		return true
	if not n.begins_with("door"):
		return false
	var p := mi.get_parent()
	if p == null:
		return false
	var pn := String(p.name).to_lower()
	return pn.begins_with("frame") or pn.begins_with("door-frame")


func _is_fridge_door_mesh(mi: MeshInstance3D) -> bool:
	var n := String(mi.name).to_lower()
	return n.begins_with("fridge-door") or n == "drink-fridge-door" or n == "microwave-door"


func _is_drawer_mesh(mi: MeshInstance3D) -> bool:
	return String(mi.name).to_lower().begins_with("drawer")


func _is_lid_mesh(mi: MeshInstance3D) -> bool:
	var n := String(mi.name).to_lower()
	return n == "oven-door" or n == "toilet-top" or n == "washing-maschine-top"


func _add_safety_floor(sketch: Node3D, merged: ArrayMesh) -> void:
	var aabb: AABB = merged.get_aabb()
	var pad := safety_floor_margin
	var size := Vector3(aabb.size.x + pad * 2.0, safety_floor_thickness, aabb.size.z + pad * 2.0)
	var box := BoxShape3D.new()
	box.size = size
	var body := StaticBody3D.new()
	body.name = "MapCollisionSafetyFloor"
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	col.shape = box
	body.add_child(col)
	var cx: float = aabb.position.x + aabb.size.x * 0.5
	var cy: float = aabb.position.y - safety_floor_thickness * 0.5 - 0.02
	var cz: float = aabb.position.z + aabb.size.z * 0.5
	body.position = Vector3(cx, cy, cz)
	sketch.add_child(body)
