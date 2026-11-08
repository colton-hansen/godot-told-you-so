extends Node
## Blender floor Array (0.5 m cubes) does not land in the FBX — Godot gets one stretched slab.
## Rebuild that grid here and put the 16² white/black vinyl on each cell.

const TEX_WHITE: Texture2D = preload("res://assets/textures/kitchen_procedural/floor_check_white_16.png")
const TEX_BLACK: Texture2D = preload("res://assets/textures/kitchen_procedural/floor_check_black_16.png")
const TILE_M: float = 0.5
const FLOOR_NAMES: PackedStringArray = ["cube_020"]


func _ready() -> void:
	call_deferred("_apply")


func _apply() -> void:
	var sketch: Node3D = get_parent().get_node_or_null("BasementSketch") as Node3D
	if sketch == null:
		return
	var mat_w := _make_mat(TEX_WHITE, 0.52)
	var mat_b := _make_mat(TEX_BLACK, 0.84)
	if _paint(sketch, mat_w, mat_b) == 0:
		push_warning("hub_kitchen_floor: no arrayed floor slabs found")


func _make_mat(tex: Texture2D, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = Color.WHITE
	mat.metallic = 0.0
	mat.roughness = roughness
	mat.metallic_specular = 0.18
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.texture_repeat = false
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _paint(n: Node, mat_w: StandardMaterial3D, mat_b: StandardMaterial3D) -> int:
	var hit := 0
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if _is_floor_slab(mi) and mi.mesh != null:
			_rebuild_tiles(mi, mat_w, mat_b)
			hit += 1
	for c: Node in n.get_children():
		hit += _paint(c, mat_w, mat_b)
	return hit


func _is_floor_slab(mi: MeshInstance3D) -> bool:
	var nm := String(mi.name).to_lower().replace(".", "_")
	for mark: String in FLOOR_NAMES:
		if nm == mark:
			return true
	return false


func _rebuild_tiles(mi: MeshInstance3D, mat_w: StandardMaterial3D, mat_b: StandardMaterial3D) -> void:
	var gaabb: AABB = mi.global_transform * mi.mesh.get_aabb()
	if gaabb.size.x < 0.05 or gaabb.size.z < 0.05:
		push_warning("hub_kitchen_floor: degenerate slab " + mi.name)
		return
	var nx: int = maxi(1, int(round(gaabb.size.x / TILE_M)))
	var nz: int = maxi(1, int(round(gaabb.size.z / TILE_M)))
	var inv: Transform3D = mi.global_transform.affine_inverse()
	var st_w := SurfaceTool.new()
	var st_b := SurfaceTool.new()
	st_w.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_b.begin(Mesh.PRIMITIVE_TRIANGLES)
	var white_n: int = 0
	var black_n: int = 0
	for iz: int in range(nz):
		for ix: int in range(nx):
			var x0: float = gaabb.position.x + float(ix) * TILE_M
			var z0: float = gaabb.position.z + float(iz) * TILE_M
			var x1: float = gaabb.end.x if ix == nx - 1 else x0 + TILE_M
			var z1: float = gaabb.end.z if iz == nz - 1 else z0 + TILE_M
			var y0: float = gaabb.position.y
			var y1: float = gaabb.end.y
			var is_black: bool = ((ix + iz) & 1) == 1
			if is_black:
				_emit_box(st_b, inv, x0, x1, y0, y1, z0, z1)
				black_n += 1
			else:
				_emit_box(st_w, inv, x0, x1, y0, y1, z0, z1)
				white_n += 1
	var mesh := ArrayMesh.new()
	if white_n > 0:
		st_w.commit(mesh)
	if black_n > 0:
		st_b.commit(mesh)
	mi.mesh = mesh
	var surf: int = 0
	if white_n > 0:
		mi.set_surface_override_material(surf, mat_w)
		surf += 1
	if black_n > 0:
		mi.set_surface_override_material(surf, mat_b)


func _emit_box(
	st: SurfaceTool,
	inv: Transform3D,
	x0: float,
	x1: float,
	y0: float,
	y1: float,
	z0: float,
	z1: float
) -> void:
	_quad(st, inv, Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1))
	_quad(st, inv, Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x0, y0, z0))
	_quad(st, inv, Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x0, y0, z1))
	_quad(st, inv, Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x1, y0, z0))
	_quad(st, inv, Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3(x0, y0, z0))
	_quad(st, inv, Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y0, z1))


func _quad(
	st: SurfaceTool,
	inv: Transform3D,
	p0: Vector3,
	p1: Vector3,
	p2: Vector3,
	p3: Vector3
) -> void:
	var a: Vector3 = inv * p0
	var b: Vector3 = inv * p1
	var c: Vector3 = inv * p2
	var d: Vector3 = inv * p3
	var n: Vector3 = (b - a).cross(d - a)
	if n.length_squared() < 0.000000000001:
		n = Vector3.UP
	else:
		n = n.normalized()
	st.set_normal(n)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(a)
	st.set_normal(n)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(b)
	st.set_normal(n)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(c)
	st.set_normal(n)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(a)
	st.set_normal(n)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(c)
	st.set_normal(n)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(d)
