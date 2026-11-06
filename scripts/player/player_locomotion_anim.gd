extends RefCounted

const BODY_MAT: Material = preload("res://assets/player/man_body_mat.tres")

const CLIP_SCENES: Dictionary = {
	&"idle": preload("res://assets/player/animations/idle.fbx"),
	&"f_walk": preload("res://assets/player/animations/f-walk.fbx"),
	&"b_walk": preload("res://assets/player/animations/b-walk.fbx"),
	&"l_walk": preload("res://assets/player/animations/l-walk.fbx"),
	&"r_walk": preload("res://assets/player/animations/r-walk.fbx"),
	&"f_run": preload("res://assets/player/animations/f-run.fbx"),
	&"crouch_idle": preload("res://assets/player/animations/crouch-idle.fbx"),
	&"crouch_f_walk": preload("res://assets/player/animations/crouch-f-walk.fbx"),
	&"crouch_b_walk": preload("res://assets/player/animations/crouch-b-walk.fbx"),
	&"crouch_l_walk": preload("res://assets/player/animations/crouch-l-walk.fbx"),
	&"crouch_r_walk": preload("res://assets/player/animations/crouch-r-walk.fbx"),
}

const F_WALK_CYCLE_SEC := 1.16666666666667
const F_RUN_CYCLE_SEC := 0.75
const CROUCH_WALK_CYCLE_SEC := 1.2
const WALK_METERS_PER_CYCLE := 3.15
const RUN_METERS_PER_CYCLE := 4.85
const CROUCH_METERS_PER_CYCLE := 1.55

const CLIP_LOOP: Dictionary = {
	&"idle": Animation.LOOP_LINEAR,
	&"f_walk": Animation.LOOP_LINEAR,
	&"b_walk": Animation.LOOP_LINEAR,
	&"l_walk": Animation.LOOP_LINEAR,
	&"r_walk": Animation.LOOP_LINEAR,
	&"f_run": Animation.LOOP_LINEAR,
	&"crouch_idle": Animation.LOOP_LINEAR,
	&"crouch_f_walk": Animation.LOOP_LINEAR,
	&"crouch_b_walk": Animation.LOOP_LINEAR,
	&"crouch_l_walk": Animation.LOOP_LINEAR,
	&"crouch_r_walk": Animation.LOOP_LINEAR,
}


static func apply_body_material(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, BODY_MAT)


static func install_locomotion_library(anim_player: AnimationPlayer) -> void:
	var lib := AnimationLibrary.new()
	var rest_root_y := 0.0
	var have_rest_y := false
	for clip_name: StringName in CLIP_SCENES:
		var packed: PackedScene = CLIP_SCENES[clip_name]
		var temp: Node = packed.instantiate()
		var src_ap := temp.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if src_ap == null:
			temp.free()
			continue
		var anim: Animation = _duplicate_clip_from_fbx(src_ap)
		if anim == null:
			temp.free()
			continue
		if not have_rest_y and clip_name == &"idle":
			rest_root_y = _root_position_y(anim)
			have_rest_y = true
		anim.loop_mode = CLIP_LOOP.get(clip_name, Animation.LOOP_LINEAR)
		_strip_character_root_tracks(anim, rest_root_y)
		lib.add_animation(String(clip_name), anim)
		temp.free()
	if anim_player.has_animation_library(&"locomotion"):
		anim_player.remove_animation_library(&"locomotion")
	anim_player.add_animation_library(&"locomotion", lib)
	_remove_imported_clip(anim_player, &"mixamo_com")


static func clip_anim_id(clip: StringName) -> StringName:
	return StringName("locomotion/" + String(clip))


static func pick_locomotion(body: CharacterBody3D, walk_speed_threshold: float) -> StringName:
	var h := Vector2(body.velocity.x, body.velocity.z).length()
	var crouching: bool = false
	if body.get("is_crouching") != null:
		crouching = bool(body.get("is_crouching"))
	var pivot := body.get_node_or_null("CameraPivot") as Node3D
	var sprinting: bool = false
	if body.get("is_sprinting") != null:
		sprinting = bool(body.get("is_sprinting"))
	if h < walk_speed_threshold:
		return &"crouch_idle" if crouching else &"idle"
	if pivot == null:
		if crouching:
			return &"crouch_f_walk"
		return &"f_run" if sprinting else &"f_walk"
	var world := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var local := pivot.global_transform.basis.inverse() * world
	var forward: float = -local.z
	var side: float = local.x
	if sprinting:
		return &"f_run"
	if absf(forward) > 0.1:
		if crouching:
			return &"crouch_f_walk" if forward >= 0.0 else &"crouch_b_walk"
		return &"f_walk" if forward >= 0.0 else &"b_walk"
	if crouching:
		return &"crouch_r_walk" if side >= 0.0 else &"crouch_l_walk"
	return &"r_walk" if side >= 0.0 else &"l_walk"


static func locomotion_speed_scale(
	clip: StringName, body: CharacterBody3D, horizontal_speed: float
) -> float:
	var walk_ref := WALK_METERS_PER_CYCLE / F_WALK_CYCLE_SEC
	var run_ref := RUN_METERS_PER_CYCLE / F_RUN_CYCLE_SEC
	var crouch_ref := CROUCH_METERS_PER_CYCLE / CROUCH_WALK_CYCLE_SEC
	match clip:
		&"f_walk", &"b_walk", &"l_walk", &"r_walk":
			return clampf(horizontal_speed / walk_ref, 0.7, 1.55)
		&"f_run":
			return clampf(horizontal_speed / run_ref, 0.75, 1.45)
		&"crouch_idle":
			return 1.0
		&"crouch_f_walk", &"crouch_b_walk", &"crouch_l_walk", &"crouch_r_walk":
			return clampf(horizontal_speed / crouch_ref, 0.65, 1.4)
	return 1.0


static func blend_time(from_clip: StringName, to_clip: StringName) -> float:
	if from_clip == to_clip or from_clip == &"":
		return 0.18
	var from_crouch := String(from_clip).begins_with("crouch")
	var to_crouch := String(to_clip).begins_with("crouch")
	if from_crouch != to_crouch:
		return 0.08
	if from_clip == &"crouch_idle" or to_clip == &"crouch_idle":
		return 0.1
	if from_clip == &"idle" or to_clip == &"idle":
		return 0.34
	if from_clip == &"f_run" or to_clip == &"f_run":
		return 0.3
	return 0.26


static func _remove_imported_clip(anim_player: AnimationPlayer, clip_name: StringName) -> void:
	for lib_name: StringName in anim_player.get_animation_library_list():
		var anim_lib: AnimationLibrary = anim_player.get_animation_library(lib_name)
		if anim_lib != null and anim_lib.has_animation(clip_name):
			anim_lib.remove_animation(clip_name)


static func _root_position_y(anim: Animation) -> float:
	for i in anim.get_track_count():
		if String(anim.track_get_path(i)) != "simple_character":
			continue
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		if anim.track_get_key_count(i) <= 0:
			continue
		var value: Variant = anim.track_get_key_value(i, 0)
		if value is Vector3:
			return (value as Vector3).y
	return 0.0


static func _strip_character_root_tracks(anim: Animation, rest_root_y: float) -> void:
	for i in range(anim.get_track_count() - 1, -1, -1):
		if String(anim.track_get_path(i)) != "simple_character":
			continue
		var track_type := anim.track_get_type(i)
		if track_type == Animation.TYPE_POSITION_3D:
			_keep_root_height(anim, i, rest_root_y)
		else:
			anim.remove_track(i)


static func _keep_root_height(anim: Animation, track: int, rest_root_y: float) -> void:
	for key_idx in anim.track_get_key_count(track):
		var value: Variant = anim.track_get_key_value(track, key_idx)
		if not (value is Vector3):
			continue
		var pos := value as Vector3
		pos.x = 0.0
		pos.z = 0.0
		pos.y -= rest_root_y
		anim.track_set_key_value(track, key_idx, pos)


static func _duplicate_clip_from_fbx(src_ap: AnimationPlayer) -> Animation:
	var names := src_ap.get_animation_list()
	if names.is_empty():
		return null
	return src_ap.get_animation(names[0]).duplicate()
