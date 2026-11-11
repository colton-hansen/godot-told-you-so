extends RefCounted

const CLIPS := {"idle": "idle", "f_walk": "walk", "f_run": "run", "crouch_idle": "crouch", "stand_to_sit": "sit-down", "sit_idle": "sitting", "sit_to_stand": "stand-up", "interact": "interact-1"}

static func apply_body_material(_root: Node) -> void:
	for mesh: MeshInstance3D in _root.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as StandardMaterial3D
			if material != null:
				material.vertex_color_use_as_albedo = true

static func install_locomotion_library(player: AnimationPlayer, clips: Dictionary = CLIPS) -> void:
	var root := player.get_node(player.root_node)
	var skeleton := root.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		push_error("Character has no Skeleton3D")
		return
	var library := AnimationLibrary.new()
	for alias: String in clips:
		var file: String = clips[alias]
		var packed := load("res://assets/characters/animations/" + file + ".glb") as PackedScene
		var source := packed.instantiate()
		var source_player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if source_player == null:
			source.free()
			continue
		var animation: Animation = null
		for name in source_player.get_animation_list():
			if name != &"RESET":
				animation = source_player.get_animation(name).duplicate()
				break
		if animation != null:
			for i in range(animation.get_track_count() - 1, -1, -1):
				var path := animation.track_get_path(i)
				# Copy bone rotations, retaining target proportions and root position.
				if animation.track_get_type(i) != Animation.TYPE_ROTATION_3D:
					animation.remove_track(i)
					continue
				# Animation-only GLBs import their joints as Node3D hierarchies.
				var bone := String(path.get_subname(0)) if path.get_subname_count() > 0 else String(path.get_name(path.get_name_count() - 1))
				if skeleton.find_bone(bone) < 0:
					animation.remove_track(i)
					continue
				animation.track_set_path(i, NodePath(String(root.get_path_to(skeleton)) + ":" + bone))
			animation.loop_mode = Animation.LOOP_NONE if alias in ["stand_to_sit", "sit_to_stand", "interact", "overhead-punch"] else Animation.LOOP_LINEAR
			library.add_animation(alias, animation)
		source.free()
	for name in player.get_animation_library_list():
		player.remove_animation_library(name)
	player.add_animation_library(&"locomotion", library)

static func clip_anim_id(clip: StringName) -> StringName:
	return StringName("locomotion/" + String(clip))

static func pick_locomotion(body: CharacterBody3D, threshold: float) -> StringName:
	if bool(body.get("is_crouching")):
		return &"crouch_idle"
	if Vector2(body.velocity.x, body.velocity.z).length() < threshold:
		return &"idle"
	var pivot := body.get_node("CameraPivot") as Node3D
	var local := pivot.global_basis.inverse() * body.velocity
	if local.z > 0.1 or absf(local.x) > absf(local.z):
		return &"idle" # Missing backward and strafe clips are disabled.
	return &"f_run" if bool(body.get("is_sprinting")) else &"f_walk"

static func locomotion_speed_scale(clip: StringName, _body: CharacterBody3D, speed: float) -> float:
	if clip == &"f_run":
		return clampf(speed / 7.5, 0.7, 1.5)
	if clip == &"f_walk":
		return clampf(speed / 4.5, 0.7, 1.5)
	return 1.0

static func blend_time(_from: StringName, _to: StringName) -> float:
	return 0.18
