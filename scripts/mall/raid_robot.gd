extends CharacterBody3D

enum State { PATROL, CHASE, SEARCH }

const CELL := 0.5
const MASK := 1
const PATROL_SPEED := 1.45
const CHASE_SPEED := 3.15
const VISION := 10.0

var player: CharacterBody3D
var footprints: Array[Rect2]
var state := State.PATROL
var _graph := AStar3D.new()
var _points := {}
var _patrol: PackedVector3Array
var _path: PackedVector3Array
var _patrol_index := 0
var _route_timer := 0.0
var _search_timer := 0.0
var _last_seen := Vector3.ZERO
var _audio: AudioStreamPlayer3D
var _anim: AnimationPlayer
var _attack_time := -1.0
var _attack_hit := false
const Motion = preload("res://scripts/player/player_locomotion_anim.gd")


func _ready() -> void:
	collision_layer = 0
	collision_mask = MASK
	floor_snap_length = 0.18
	var shape := CapsuleShape3D.new()
	shape.radius = 0.23
	shape.height = 1.8
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.9
	add_child(collider)
	var variant := randi_range(1, 3)
	var model := (load("res://assets/characters/sint-bot/sint-bot-model-%d.glb" % variant) as PackedScene).instantiate() as Node3D
	add_child(model)
	Motion.apply_body_material(model)
	model.rotation.y = PI
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	Motion.install_locomotion_library(_anim, {"idle": "idle", "walk": "walk", "run": "run", "overhead-punch": "overhead-punch"})
	_anim.play("locomotion/idle")
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = _motor_sound()
	_audio.volume_db = -12
	_audio.max_distance = 13
	_audio.unit_size = 2.3
	_audio.position.y = 0.5
	add_child(_audio)


func _physics_process(delta: float) -> void:
	if _graph.get_point_count() == 0:
		_build_navigation()
		if _graph.get_point_count() == 0:
			queue_free()
		return
	if not is_instance_valid(player) or RunState.phase != RunState.Phase.RAID:
		return

	if _attack_time >= 0.0:
		_attack_time += delta
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y -= 18.0 * delta
		move_and_slide()
		var duration := _anim.get_animation("locomotion/overhead-punch").length
		if not _attack_hit and _attack_time >= duration * 0.55:
			_attack_hit = true
			if global_position.distance_to(player.global_position) < 1.15 and _can_see():
				RunState.caught()
		if _attack_time >= duration:
			_attack_time = -1.0
		return
	var sees := _can_see()
	if sees:
		_last_seen = player.global_position
		if state != State.CHASE:
			_route_timer = 0
		state = State.CHASE
		if global_position.distance_to(player.global_position) < 0.83:
			_attack_time = 0.0
			_attack_hit = false
			_anim.play("locomotion/overhead-punch", 0.1)
			return
	elif state == State.CHASE:
		state = State.SEARCH
		_search_timer = 5.0
		_route_timer = 0
	elif state == State.SEARCH:
		_search_timer -= delta
		if _search_timer <= 0:
			state = State.PATROL
			_route_timer = 0

	_route_timer -= delta
	if _route_timer <= 0:
		_update_route()
		_route_timer = 0.25
	_move(delta)


func _build_navigation() -> void:
	var space := get_world_3d().direct_space_state
	var probe := CapsuleShape3D.new()
	probe.radius = 0.28
	probe.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.collision_mask = MASK
	var offsets := [Vector2i.LEFT, Vector2i.UP]
	for rect in footprints:
		for x in range(floori(rect.position.x / CELL), ceili(rect.end.x / CELL)):
			for z in range(floori(rect.position.y / CELL), ceili(rect.end.y / CELL)):
				var cell := Vector2i(x, z)
				if _points.has(cell):
					continue
				var point := Vector3((x + 0.5) * CELL, 0, (z + 0.5) * CELL)
				query.transform.origin = point + Vector3.UP * 0.95
				if not space.intersect_shape(query, 1).is_empty():
					continue
				var floor_query := PhysicsRayQueryParameters3D.create(
					point + Vector3.UP * 0.15, point - Vector3.UP * 0.3, MASK)
				if space.intersect_ray(floor_query).is_empty():
					continue
				var id := _graph.get_available_point_id()
				_graph.add_point(id, point)
				_points[cell] = id
	for cell: Vector2i in _points:
		for offset: Vector2i in offsets:
			if not _points.has(cell + offset):
				continue
			var from_id: int = _points[cell]
			var to_id: int = _points[cell + offset]
			query.transform.origin = _graph.get_point_position(from_id) + Vector3.UP * 0.95
			query.motion = _graph.get_point_position(to_id) - _graph.get_point_position(from_id)
			var sweep := space.cast_motion(query)
			if sweep.size() == 2 and sweep[0] >= 0.999:
				_graph.connect_points(from_id, to_id)
	if _points.is_empty():
		return

	var start_id := _graph.get_closest_point(Vector3(0, 0, -3))
	global_position = _graph.get_point_position(start_id)
	_patrol.append(global_position)
	for rect in footprints:
		var center := rect.get_center()
		if center.y >= 0:
			continue
		var goal := _graph.get_closest_point(Vector3(center.x, 0, center.y))
		if goal != start_id and not _graph.get_id_path(start_id, goal).is_empty():
			_patrol.append(_graph.get_point_position(goal))
	_audio.play()


func _can_see() -> bool:
	var eye := global_position + Vector3.UP * 0.93
	var target := player.global_position + Vector3.UP * 0.76
	var offset := target - eye
	if offset.length() > VISION:
		return false
	if state == State.PATROL and offset.length() > 1.3 and -global_basis.z.dot(offset.normalized()) < 0.35:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, target, MASK, [player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _update_route() -> void:
	var target: Vector3
	if state == State.PATROL:
		if global_position.distance_to(_patrol[_patrol_index]) < 0.55:
			_patrol_index = (_patrol_index + 1) % _patrol.size()
		target = _patrol[_patrol_index]
	else:
		target = _last_seen
	var start := _graph.get_closest_point(global_position)
	var goal := _graph.get_closest_point(target)
	_path = _graph.get_point_path(start, goal)
	if _path.size() > 1:
		_path.remove_at(0)


func _move(delta: float) -> void:
	while not _path.is_empty() and global_position.distance_to(_path[0]) < 0.16:
		_path.remove_at(0)
	var direction := Vector3.ZERO
	if not _path.is_empty():
		direction = _path[0] - global_position
		direction.y = 0
		direction = direction.normalized()
		rotation.y = atan2(-direction.x, -direction.z)
	var speed := CHASE_SPEED if state == State.CHASE else PATROL_SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y -= 18.0 * delta
	move_and_slide()
	_audio.pitch_scale = 1.55 if state == State.CHASE else 1.0
	var clip := "idle" if direction == Vector3.ZERO else ("run" if state == State.CHASE else "walk")
	var anim_id := "locomotion/" + clip
	if _anim.current_animation != anim_id:
		_anim.play(anim_id, 0.18)


func _visual(point: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	part.mesh = shape
	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	surface.emission_enabled = point.z < 0
	part.material_override = surface
	part.position = point
	add_child(part)
	return part


func _motor_sound() -> AudioStreamWAV:
	var audio := AudioStreamWAV.new()
	audio.mix_rate = 11025
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var buffer := PackedByteArray()
	buffer.resize(audio.mix_rate * 2)
	for i in audio.mix_rate:
		var t := float(i) / audio.mix_rate
		var pulse := 0.36 + 0.64 * pow(sin(t * TAU * 2), 4.0)
		var sample := (sin(t * TAU * 69) * 0.52 + sin(t * TAU * 144) * 0.19) * pulse
		buffer.encode_s16(i * 2, roundi(sample * 12000))
	audio.data = buffer
	audio.loop_end = audio.mix_rate
	return audio
