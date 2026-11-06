extends Node
## Replaces materials on imported kitchen/floor/wall meshes with 2012 basement tiles.
## Appliances with unique atlas UVs (fridge, microwave, toaster) keep the GLB textures.
## Sibling script: tools/gen_kitchen_textures.ps1

const TEX_FLOOR: Texture2D = preload("res://assets/textures/kitchen_procedural/floor_tile_grid_64.png")
const TEX_CABINET: Texture2D = preload("res://assets/textures/kitchen_procedural/cabinet_wood_worn_256.png")
const TEX_COUNTER: Texture2D = preload("res://assets/textures/kitchen_procedural/countertop_speckle_256.png")
const TEX_METAL: Texture2D = preload("res://assets/textures/kitchen_procedural/appliance_metal_smudge_256.png")
const TEX_WALL: Texture2D = preload("res://assets/textures/kitchen_procedural/wall_paint_basement_256.png")

@export var apply: bool = true
## Band above the lowest geometry global Y treated as "floor" (meters).
@export var floor_band: float = 0.55
## Local AABB height at or below this → candidate for floor (meters).
@export var floor_max_thickness: float = 0.25


func _ready() -> void:
	if not apply:
		return
	var sketch: Node3D = get_parent().get_node_or_null("BasementSketch") as Node3D
	if sketch == null:
		push_warning("basement_kitchen_textures: no BasementSketch")
		return
	var y_ext := _compute_global_y_extents(sketch)
	var y_min: float = y_ext.x
	_apply_recursive(sketch, y_min)


func _compute_global_y_extents(n: Node) -> Vector2:
	var ymin := INF
	var ymax := -INF
	return _extents_vec(n, ymin, ymax)


func _extents_vec(n: Node, ymin: float, ymax: float) -> Vector2:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var mesh: Mesh = mi.mesh
		if mesh != null:
			var gaabb: AABB = mi.global_transform * mesh.get_aabb()
			ymin = minf(ymin, gaabb.position.y)
			ymax = maxf(ymax, gaabb.position.y + gaabb.size.y)
	for c: Node in n.get_children():
		var v: Vector2 = _extents_vec(c, ymin, ymax)
		ymin = v.x
		ymax = v.y
	return Vector2(ymin, ymax)


func _apply_recursive(n: Node, y_min_global: float) -> void:
	if n is MeshInstance3D:
		_paint_mi(n as MeshInstance3D, y_min_global)
	for c: Node in n.get_children():
		_apply_recursive(c, y_min_global)


func _paint_mi(mi: MeshInstance3D, y_min_global: float) -> void:
	var mesh: Mesh = mi.mesh
	if mesh == null:
		return
	var laabb: AABB = mesh.get_aabb()
	var gaabb: AABB = mi.global_transform * laabb
	var nm := mi.name.to_lower()
	var thin := laabb.size.y <= floor_max_thickness
	var floor_ceiling := y_min_global + floor_band
	var is_floor := thin and gaabb.position.y + gaabb.size.y <= floor_ceiling + 0.02

	var tex: Texture2D
	var triplanar := false
	var uv_scale := Vector3.ONE
	var metallic := 0.0
	var roughness := 0.92
	var albedo := Color.WHITE

	if is_floor:
		tex = TEX_FLOOR
		triplanar = true
		uv_scale = Vector3(0.65, 0.65, 0.65)
		roughness = 0.78
	elif _match_any(nm, [
		"kitchen-furniture",
		"hanging-kitchen",
		"standing-kitchen",
		"kitchen cabinet",
		"cabinet",
		"handle",
	]):
		tex = TEX_CABINET
		triplanar = true
		uv_scale = Vector3(0.9, 0.9, 0.9)
		roughness = 0.86
		albedo = Color(1.0, 0.97, 0.92)
	elif _match_any(nm, ["cut table", "counter", "kitchen countertop", "kitchen-countertop"]):
		tex = TEX_COUNTER
		triplanar = true
		uv_scale = Vector3(0.8, 0.8, 0.8)
		roughness = 0.7
	elif _match_any(nm, ["metal-shelves"]):
		tex = TEX_METAL
		triplanar = true
		uv_scale = Vector3(1.1, 1.1, 1.1)
		metallic = 0.55
		roughness = 0.42
	elif _match_any(nm, ["wall"]):
		tex = TEX_WALL
		triplanar = true
		uv_scale = Vector3(0.5, 0.5, 0.5)
		roughness = 0.95
	else:
		return

	for surf: int in range(mesh.get_surface_count()):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.albedo_color = albedo
		mat.metallic = metallic
		mat.roughness = roughness
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		if triplanar:
			mat.uv1_triplanar = true
			mat.uv1_triplanar_sharpness = 4.0
			mat.uv1_scale = uv_scale
		else:
			mat.uv1_scale = uv_scale
		mi.set_surface_override_material(surf, mat)


func _match_any(s: String, parts: PackedStringArray) -> bool:
	for p: String in parts:
		if s.contains(p):
			return true
	return false
