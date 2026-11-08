extends Node
## Test wood on the desk under the PS (table-2).
## Mesh is FBX-scaled (~cm). Box-unwrap from the real AABB onto a full-bleed grain sheet.

const TEX: Texture2D = preload("res://assets/textures/ps1/table_atlas.png")

var _aabb: AABB


func _ready() -> void:
	call_deferred("_apply")


func _apply() -> void:
	var sketch: Node3D = get_parent().get_node_or_null("BasementSketch") as Node3D
	if sketch == null:
		push_warning("hub_table_texture: no BasementSketch")
		return
	if _paint(sketch) == 0:
		push_warning("hub_table_texture: table-2 not found")


func _paint(n: Node) -> int:
	var hit := 0
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if String(mi.name).to_lower() == "table-2" and mi.mesh != null:
			_unwrap_and_paint(mi)
			hit += 1
	for c: Node in n.get_children():
		hit += _paint(c)
	return hit


func _unwrap_and_paint(mi: MeshInstance3D) -> void:
	var src: Mesh = mi.mesh
	_aabb = src.get_aabb()
	if _aabb.size.x < 0.000001 or _aabb.size.y < 0.000001 or _aabb.size.z < 0.000001:
		push_warning("hub_table_texture: degenerate aabb")
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s: int in range(src.get_surface_count()):
		var arr: Array = src.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrms: PackedVector3Array = PackedVector3Array()
		if arr[Mesh.ARRAY_NORMAL] != null:
			nrms = arr[Mesh.ARRAY_NORMAL]
		var idxs := PackedInt32Array()
		if arr[Mesh.ARRAY_INDEX] != null:
			idxs = arr[Mesh.ARRAY_INDEX]
		var have_n := nrms.size() == verts.size()
		var have_idx := idxs.size() >= 3
		var tri_n: int = idxs.size() if have_idx else verts.size()
		for t: int in range(0, tri_n, 3):
			var i0: int = idxs[t] if have_idx else t
			var i1: int = idxs[t + 1] if have_idx else t + 1
			var i2: int = idxs[t + 2] if have_idx else t + 2
			_emit_tri(st, verts, nrms, have_n, i0, i1, i2)
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = TEX
	mat.albedo_color = Color.WHITE
	mat.metallic = 0.0
	mat.roughness = 0.72
	mat.metallic_specular = 0.25
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.texture_repeat = false
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for surf: int in range(mi.mesh.get_surface_count()):
		mi.set_surface_override_material(surf, mat)


func _emit_tri(
	st: SurfaceTool,
	verts: PackedVector3Array,
	nrms: PackedVector3Array,
	have_n: bool,
	i0: int,
	i1: int,
	i2: int
) -> void:
	var p0 := verts[i0]
	var p1 := verts[i1]
	var p2 := verts[i2]
	var n := (p1 - p0).cross(p2 - p0)
	if n.length_squared() < 0.000000000001:
		n = Vector3.UP
	else:
		n = n.normalized()
	var n0 := nrms[i0] if have_n else n
	var n1 := nrms[i1] if have_n else n
	var n2 := nrms[i2] if have_n else n
	st.set_normal(n0)
	st.set_uv(_box_uv(n, p0))
	st.add_vertex(p0)
	st.set_normal(n1)
	st.set_uv(_box_uv(n, p1))
	st.add_vertex(p1)
	st.set_normal(n2)
	st.set_uv(_box_uv(n, p2))
	st.add_vertex(p2)


func _box_uv(n: Vector3, p: Vector3) -> Vector2:
	var an := n.abs()
	var p0 := _aabb.position
	var p1 := _aabb.position + _aabb.size
	var tu: float
	var tv: float
	if an.x >= an.y and an.x >= an.z:
		tu = inverse_lerp(p0.y, p1.y, p.y)
		tv = inverse_lerp(p0.z, p1.z, p.z)
	elif an.y >= an.z:
		tu = inverse_lerp(p0.x, p1.x, p.x)
		tv = inverse_lerp(p0.z, p1.z, p.z)
	else:
		tu = inverse_lerp(p0.x, p1.x, p.x)
		tv = inverse_lerp(p0.y, p1.y, p.y)
	return Vector2(clampf(tu, 0.02, 0.98), clampf(tv, 0.02, 0.98))
