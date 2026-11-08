extends Node
## Restores the packed PS1 console/controller albedo that FBX export dropped.
## Atlas: res://assets/textures/ps1/ps1_atlas.png (256² product-photo sheet).
##
## Style (for later props in the same look):
## - One 256² atlas, orthographic product photos on white (#F8F8F8–#FFFFFF).
## - Pack every major face: front / top / bottom / thin side strips + one hero 3/4 object.
## - Body plastic #C0C4C8–#D4D8DC, crevice AO a bit darker, vents almost black.
## - Printed marks stay sharp (yellow warning, black logos, DualShock RGB/CMY buttons).
## - Soft studio light, no environment bake, slight highlight on rounded edges.
## - UVs: console is a box unwrap across the left/bottom; controller sits in the right half.
## - Filter LINEAR (this is a photo, not pixel art). Do not tile.

const TEX: Texture2D = preload("res://assets/textures/ps1/ps1_atlas.png")
const NAME_MARKERS: PackedStringArray = ["ps1", "playstation", "dualshock", "gamepad"]


func _ready() -> void:
	call_deferred("_apply")


func _apply() -> void:
	var sketch: Node3D = get_parent().get_node_or_null("BasementSketch") as Node3D
	if sketch == null:
		push_warning("hub_ps1_texture: no BasementSketch")
		return
	var n := _paint(sketch)
	if n == 0:
		push_warning("hub_ps1_texture: no PS1 meshes found")


func _paint(n: Node) -> int:
	var hit := 0
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if _is_ps1(mi) and mi.mesh != null:
			_override(mi)
			hit += 1
	for c: Node in n.get_children():
		hit += _paint(c)
	return hit


func _is_ps1(mi: MeshInstance3D) -> bool:
	if _name_has_ps1(String(mi.name)) or _name_has_ps1(String(mi.mesh.resource_name)):
		return true
	for surf: int in range(mi.mesh.get_surface_count()):
		var mat := mi.get_active_material(surf)
		if mat != null and _name_has_ps1(String(mat.resource_name)):
			return true
	return false


func _name_has_ps1(s: String) -> bool:
	var nm := s.to_lower()
	for mark: String in NAME_MARKERS:
		if nm.contains(mark):
			return true
	return false


func _override(mi: MeshInstance3D) -> void:
	var mesh: Mesh = mi.mesh
	for surf: int in range(mesh.get_surface_count()):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = TEX
		mat.albedo_color = Color.WHITE
		mat.metallic = 0.02
		mat.roughness = 0.48
		mat.metallic_specular = 0.45
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mat.texture_repeat = false
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.set_surface_override_material(surf, mat)
