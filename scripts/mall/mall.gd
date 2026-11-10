extends Node3D

const MARKET := preload("res://assets/models/mall/market/market.glb")
const SECURITY := preload("res://assets/models/mall/security/security.glb")
const STOCKROOM := preload("res://assets/models/mall/stockroom/stockroom.glb")
const LOADING_DOCK := preload("res://assets/models/mall/spawn/loading_dock.glb")
const PLAYER := preload("res://scenes/player/player.tscn")
const LOOT := preload("res://scripts/mall/raid_loot.gd")
const ROBOT := preload("res://scripts/mall/raid_robot.gd")
const HIDING_PROPS := [
	preload("res://assets/models/mall/market/hiding/open_freezer.glb"),
	preload("res://assets/models/mall/market/hiding/open_crate.glb"),
]
const HEIGHT := 3.2
const WALL := 0.18

# Entry sockets face +Z in each imported room.
const TEMPLATES := [
	{"scene": MARKET, "name": "Market", "sign": "GROCERY", "size": Vector2(26, 10),
		"entry": "SOCKET_MALL", "exit": "SOCKET_SERVICE", "exit_width": 1.6},
	{"scene": SECURITY, "name": "Security", "sign": "SECURITY", "size": Vector2(7, 6),
		"entry": "SOCKET_SECURITY", "exit": "SOCKET_SECURITY_REAR", "exit_width": 1.64},
	{"scene": STOCKROOM, "name": "Stockroom", "sign": "STOCKROOM", "size": Vector2(10, 9),
		"entry": "SOCKET_STOCKROOM", "exit": "SOCKET_DISPATCH", "exit_width": 1.6},
]

@export var layout_seed := -1

var _footprints: Array[Rect2] = [
	Rect2(-4.5, 0, 9, 8), # Loading dock
	Rect2(-6, -11, 12, 11), # First room
]

var _plaster := _material(Color("#68695c"))
var _skirt := _material(Color("#38534e"))
var _floor := _material(Color("#5b554b"))
var _dark_tile := _material(Color("#414943"))
var _metal := _material(Color("#36413c"))
var _warning := _material(Color("#917142"))
var _diffuser := _material(Color("#c6ccad"))


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	if layout_seed != -1:
		rng.seed = layout_seed
	elif RunState.raid_seed == -1:
		rng.randomize()
	else:
		rng.seed = RunState.raid_seed
	_diffuser.emission_enabled = true
	_diffuser.emission = _diffuser.albedo_color

	var lobby := LOADING_DOCK.instantiate() as Node3D
	lobby.name = "LoadingLobby"
	lobby.rotation.y = PI
	add_child(lobby)
	lobby.position -= _socket(lobby, "SOCKET_SPAWN")
	for x: float in [-2.62, 2.62]:
		for z: float in [-1.45, 1.9]:
			_light(lobby, Vector3(x, 2.93, z), Color("#f3c796"), 1.25, 5.5)

	var center := Vector3(0, 0, -5.5)
	var doors := {Vector2i.DOWN: Vector2(0, 3.0)}
	var signs := {}
	var sides: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]
	var remaining := TEMPLATES.duplicate()
	var branch_count := rng.randi_range(1, 3)
	var branch_heads: Array[Dictionary] = []
	while branch_heads.size() < branch_count and not sides.is_empty():
		var side: Vector2i = sides.pop_at(rng.randi_range(0, sides.size() - 1))
		var direction := Vector3(side.x, 0, side.y)
		var port := center + Vector3(side.x * 6.0, 0, side.y * 5.5 + _side_offset(side))
		var length := 0 if branch_heads.is_empty() else rng.randi_range(4, 7)
		var branch := _grow(remaining, port, direction, length, rng)
		if branch.is_empty():
			continue
		doors[side] = Vector2(_side_offset(side), 2.0)
		signs[side] = branch.spec.sign
		branch_heads.append(branch)

	# A single branch can still combine a direct door with a corridor farther along.
	var extend := branch_heads.size() == 1 or rng.randf() < 0.55
	for branch in branch_heads:
		var room: Node3D = branch.room
		var spec: Dictionary = branch.spec
		var rear := _socket(room, spec.exit)
		if extend and not remaining.is_empty():
			var next := _grow(remaining, rear, branch.direction,
				rng.randi_range(4, 7) if branch_heads.size() == 1 else 0, rng)
			if not next.is_empty():
				_seal(next.room, next.spec)
				extend = false
				continue
		_seal(room, spec)

	var receiving := rng.randi_range(0, 1) == 0
	var first := _room("Receiving" if receiving else "Concourse", center, Vector2(12, 11), doors)
	if receiving:
		_build_service(first, rng)
	else:
		for x: float in [-2.35, 2.35]:
			_cover(first, Vector3(x, 0, 0), Vector3(2.2, 2.15, 2.05))
			for z: float in [-3.3, 3.3]:
				_fixture(first, Vector3(x, 0, z), Color("#e1cfac"))
	for side: Vector2i in signs:
		_port_sign(first, side, signs[side])
	_port_sign(first, Vector2i.DOWN, "EVAC")
	_sign(lobby, Vector3(0, 2.72, -3.65), "EVACUATION", 0.010, 2.4, false)
	RunInteraction.create(lobby, Vector3(0, 1.10, -2.7), "Evacuate", RunState.evacuate,
		func() -> bool: return RunState.phase == RunState.Phase.RAID)
	var market := get_node_or_null("Market") as Node3D
	if market != null:
		_place_market_hiding(market, rng)

	var spawn := lobby.find_child("PLAYER_START", true, false) as Node3D
	var player := PLAYER.instantiate() as Node3D
	player.transform = global_transform.affine_inverse() * spawn.global_transform
	add_child(player)
	if RunState.phase == RunState.Phase.RAID:
		var robot := ROBOT.new()
		robot.name = "SecurityRobot"
		robot.player = player
		robot.footprints = _footprints
		add_child(robot)
		_place_raid_loot(first, rng)


func _place_market_hiding(market: Node3D, rng: RandomNumberGenerator) -> void:
	var markers := market.find_children("HIDE_MARKER*", "Node3D", true, false)
	markers.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name) < String(b.name))
	for i in mini(rng.randi_range(2, 4), markers.size()):
		var marker: Node3D = markers.pop_at(rng.randi_range(0, markers.size() - 1))
		var scene: PackedScene = HIDING_PROPS[rng.randi_range(0, HIDING_PROPS.size() - 1)]
		var shelter := scene.instantiate() as Node3D
		marker.add_child(shelter)
		for node in shelter.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			mesh.create_trimesh_collision()


func _place_raid_loot(first: Node3D, rng: RandomNumberGenerator) -> void:
	_drop_loot(first, Vector3(-4.9, 0.18, 3.45), RunState.FOOD)
	_drop_loot(first, Vector3(4.9, 0.18, 3.45), RunState.WATER)
	var supplies: Array[ItemDefinition] = [RunState.FOOD, RunState.WATER, RunState.BANDAGE]
	var first_room := true
	for spec: Dictionary in TEMPLATES:
		var room := get_node_or_null(spec.name) as Node3D
		if room == null:
			continue
		if room.name == &"Market":
			_place_market_loot(room, supplies, rng)
			continue
		var size: Vector2 = spec.size
		var item := RunState.BANDAGE if first_room else supplies[rng.randi_range(0, supplies.size() - 1)]
		_drop_loot(room, Vector3(0, 0.18, size.y / 2 - 0.75), item)
		first_room = false


func _place_market_loot(room: Node3D, supplies: Array[ItemDefinition],
		rng: RandomNumberGenerator) -> void:
	if rng.randf() < 0.18:
		return
	var markers := room.find_children("LOOT_MARKER_*", "Node3D", true, false)
	markers.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name) < String(b.name))
	for node in markers:
		var marker := node as Node3D
		if rng.randf() < 0.42:
			_drop_loot(marker, Vector3.ZERO, supplies[rng.randi_range(0, supplies.size() - 1)])


func _drop_loot(room: Node3D, point: Vector3, item: ItemDefinition) -> void:
	var loot := LOOT.new()
	loot.position = point
	loot.item = item
	room.add_child(loot)


func _unhandled_key_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		get_viewport().set_input_as_handled()
		RunState.reset_debug_layout()
		get_tree().reload_current_scene()


func _socket(room: Node3D, socket_name: String) -> Vector3:
	var marker := room.find_child(socket_name, true, false) as Node3D
	return to_local(marker.global_position)


func _side_offset(side: Vector2i) -> float:
	return -2.8 if side.x != 0 else 0.0


func _grow(remaining: Array, port: Vector3, direction: Vector3, length: int,
		rng: RandomNumberGenerator) -> Dictionary:
	if remaining.is_empty():
		return {}
	var entry := port + direction * length
	var corridor_size := Vector2(length, 3) if direction.x != 0 else Vector2(3, length)
	var corridor_center := port.lerp(entry, 0.5)
	var corridor_bounds := _bounds(corridor_center, corridor_size)
	if length > 0 and not _fits(corridor_bounds):
		return {}
	var start_index := rng.randi_range(0, remaining.size() - 1)
	for offset in range(remaining.size()):
		var index := (start_index + offset) % remaining.size()
		var spec: Dictionary = remaining[index]
		var size: Vector2 = spec.size
		var center := entry + direction * size.y / 2
		var bounds := _bounds(center, Vector2(size.y, size.x) if direction.x != 0 else size)
		if not _fits(bounds):
			continue

		var scene: PackedScene = spec.scene
		var room := scene.instantiate() as Node3D
		room.name = spec.name
		room.rotation.y = atan2(-direction.x, -direction.z)
		add_child(room)
		room.position += entry - _socket(room, spec.entry)
		var sign_mount := Node3D.new()
		sign_mount.position = Vector3(0, 2.73, size.y / 2 - 0.25)
		sign_mount.rotation.y = PI
		room.add_child(sign_mount)
		_sign(sign_mount, Vector3.ZERO, "BACK TO EVAC", 0.008, 1.85, false)
		_footprints.append(bounds)
		if length > 0:
			_footprints.append(corridor_bounds)
			var side := Vector2i(int(direction.x), int(direction.z))
			var corridor := _room("CorridorTo" + str(spec.name), corridor_center, corridor_size,
				{side: Vector2(0, 2.0), -side: Vector2(0, 2.0)})
			_fixture(corridor, Vector3.ZERO, Color("#bfcdb6"))
		_light_template(room)
		remaining.remove_at(index)
		return {"room": room, "spec": spec, "direction": direction}
	return {}


func _bounds(center: Vector3, size: Vector2) -> Rect2:
	return Rect2(Vector2(center.x, center.z) - size / 2, size)


func _fits(bounds: Rect2) -> bool:
	for footprint in _footprints:
		if bounds.grow(-0.01).intersects(footprint):
			return false
	return true


func _seal(room: Node3D, spec: Dictionary) -> void:
	var point := room.to_local(to_global(_socket(room, spec.exit)))
	_block(room, "Closed service shutter", point + Vector3.UP * 1.21,
		Vector3(spec.exit_width, 2.42, 0.12), _metal)
	for row in range(1, 16):
		_block(room, "Shutter rib", point + Vector3.UP * row * 0.15,
			Vector3(spec.exit_width, 0.018, 0.15), _skirt, false)


func _room(title: String, center: Vector3, size: Vector2, doors: Dictionary) -> Node3D:
	var room := Node3D.new()
	room.name = title
	room.position = center
	add_child(room)
	_block(room, "Floor", Vector3(0, -0.10, 0), Vector3(size.x, 0.20, size.y), _floor)
	_block(room, "Ceiling", Vector3(0, HEIGHT + 0.08, 0),
		Vector3(size.x, 0.16, size.y), _plaster)
	for x in range(int(size.x)):
		for z in range(int(size.y)):
			var tile := _floor if (x + z) % 2 == 0 else _dark_tile
			_block(room, "Terrazzo", Vector3(x + 0.5 - size.x / 2, 0.002, z + 0.5 - size.y / 2),
				Vector3(0.988, 0.006, 0.988), tile, false)
	for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var edge := Node3D.new()
		edge.position = Vector3(side.x * (size.x - WALL) / 2, 0, side.y * (size.y - WALL) / 2)
		if side.x != 0:
			edge.rotation.y = -PI / 2
		room.add_child(edge)
		var half := (size.y if side.x != 0 else size.x) / 2.0
		var door: Vector2 = doors.get(side, Vector2.ZERO)
		if door.y == 0.0:
			_wall_strip(edge, -half, half)
		else:
			_wall_strip(edge, -half, door.x - door.y / 2)
			_wall_strip(edge, door.x + door.y / 2, half)
			_block(edge, "Lintel", Vector3(door.x, (HEIGHT + 2.42) / 2, 0),
				Vector3(door.y, HEIGHT - 2.42, WALL), _metal)
	return room


func _wall_strip(edge: Node3D, from: float, to: float) -> void:
	var center := (from + to) / 2.0
	var width := to - from
	_block(edge, "Wall", Vector3(center, HEIGHT / 2, 0),
		Vector3(width, HEIGHT, WALL), _plaster)
	_block(edge, "Enamel band", Vector3(center, 0.53, 0),
		Vector3(width, 0.91, WALL + 0.014), _skirt, false)


func _build_service(room: Node3D, rng: RandomNumberGenerator) -> void:
	var partition_z := rng.randf_range(-0.55, 0.55)
	# Two separate doors between the receiving and dispatch areas.
	for span: Vector2 in [Vector2(-6, -4.6), Vector2(-2.5, 2.5), Vector2(4.6, 6)]:
		var wall := Node3D.new()
		wall.position.z = partition_z
		room.add_child(wall)
		_wall_strip(wall, span.x, span.y)
	for x: float in [-3.55, 3.55]:
		_block(room, "Internal lintel", Vector3(x, 2.81, partition_z),
			Vector3(2.1, 0.78, WALL), _metal)

	var cover_side := -1.0 if rng.randi_range(0, 1) == 0 else 1.0
	_cover(room, Vector3(cover_side * 1.8, 0, 2.5), Vector3(2.9, 2.15, 0.9))
	_cover(room, Vector3(-cover_side * 1.55, 0, -2.9), Vector3(2.45, 2.15, 0.85))
	for x: float in [-3.55, 3.55]:
		for z: float in [-3.7, 2.9]:
			_fixture(room, Vector3(x, 0, z), Color("#cbdabf"))


func _port_sign(room: Node3D, side: Vector2i, title: String) -> void:
	var mount := Node3D.new()
	mount.position = Vector3(side.x * 5.76, 2.74, side.y * 5.26 + _side_offset(side))
	mount.rotation.y = atan2(-side.x, -side.y)
	room.add_child(mount)
	_sign(mount, Vector3.ZERO, title, 0.008, 1.54, false)


func _cover(room: Node3D, point: Vector3, size: Vector3) -> void:
	_block(room, "Locker bank", point + Vector3.UP * size.y / 2, size, _metal)
	var count := 5
	var door_width := size.x / count
	for i in range(count):
		var x := (i + 0.5) * door_width - size.x / 2
		var face := point + Vector3(x, size.y / 2, size.z / 2)
		_block(room, "Locker door", face, Vector3(door_width - 0.035, size.y - 0.14, 0.045),
			_skirt, false)
		_block(room, "Locker handle", face + Vector3(door_width * 0.32, 0.03, 0.044),
			Vector3(0.035, 0.16, 0.042), _warning, false)


func _fixture(room: Node3D, point: Vector3, tint: Color) -> void:
	_block(room, "Strip fixture", point + Vector3.UP * 3.11,
		Vector3(0.26, 0.10, 1.28), _diffuser, false)
	_light(room, point + Vector3.UP * 2.98, tint, 1.28, 5.6)


func _sign(parent: Node3D, point: Vector3, message: String, pixel_scale: float, width: float, hanging: bool = true) -> void:
	_block(parent, "Sign casing", point + Vector3.FORWARD * 0.055,
		Vector3(width, 0.36, 0.10), _metal, false)
	if hanging:
		for side: float in [-1.0, 1.0]:
			var hanger_height := HEIGHT - point.y
			_block(parent, "Sign hanger",
				point + Vector3(side * width * 0.36, hanger_height / 2.0, -0.055),
				Vector3(0.05, hanger_height, 0.05), _metal, false)
	var label := Label3D.new()
	label.position = point
	label.text = message
	label.font_size = 30
	label.pixel_size = pixel_scale
	label.modulate = Color("#f3dbab")
	parent.add_child(label)


func _light_template(room: Node3D) -> void:
	match room.name:
		&"Market":
			for node in room.find_children("*", "MeshInstance3D", true, false):
				var mesh := node as MeshInstance3D
				var geometry := mesh.mesh as ArrayMesh
				if geometry == null:
					continue
				for index in geometry.get_surface_count():
					if geometry.surface_get_format(index) & Mesh.ARRAY_FORMAT_COLOR:
						var material := mesh.get_active_material(index) as StandardMaterial3D
						if material != null:
							material.vertex_color_use_as_albedo = true
			for point in [Vector3(-3, 2.85, 0.1), Vector3(-0.5, 2.85, 0.1),
					Vector3(2, 2.85, 0.1), Vector3(-0.5, 2.85, -2.53),
					Vector3(2, 2.85, -2.53), Vector3(3.5, 2.85, 3.3),
					Vector3(-7.65, 2.85, -2.15), Vector3(7.65, 2.85, -2.15),
					Vector3(-7.65, 2.85, 2.05), Vector3(7.65, 2.85, 2.05),
					Vector3(-10.85, 2.85, -3.6), Vector3(10.85, 2.85, -3.6),
					Vector3(-10.85, 2.85, 0.0), Vector3(10.85, 2.85, 0.0),
					Vector3(-10.85, 2.85, 3.55), Vector3(10.85, 2.85, 3.55)]:
				_light(room, point, Color("#d1dbc1"), 1.15, 5.0)
		&"Security":
			_light(room, Vector3(-1.7, 2.86, -0.7), Color("#bed7c8"), 1.1, 4.7)
			_light(room, Vector3(1.7, 2.86, -0.7), Color("#bed7c8"), 0.85, 4.5)
			_light(room, Vector3(0, 2.65, 2.66), Color("#e3a360"), 0.85, 3.2)
		&"Stockroom":
			for x: float in [-1.45, 1.45]:
				_light(room, Vector3(x, 2.9, -0.1), Color("#c2d6b5"), 1.25, 5.8)


func _material(color: Color) -> StandardMaterial3D:
	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	return surface


func _block(parent: Node3D, label: String, center: Vector3, size: Vector3,
		surface: Material, solid: bool = true) -> void:
	var visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	visual.mesh = box
	visual.material_override = surface
	visual.position = center
	visual.name = label
	parent.add_child(visual, true)
	if solid:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		visual.add_child(body)
		body.add_child(collider)


func _light(parent: Node3D, point: Vector3, color: Color, energy: float, reach: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = point
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	parent.add_child(lamp)
