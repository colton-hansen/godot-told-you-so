class_name PlayerLoadout
extends RefCounted

signal changed
signal item_used(definition: ItemDefinition)

enum Area { ACTIVE, POCKET, BACKPACK }

const POCKET_COUNT := InventoryLayout.POCKET_COUNT
const BACKPACK_COUNT := InventoryLayout.BACKPACK_COUNT

var pockets: Array[ItemStack] = []
var backpack: Array[ItemStack] = []
var backpack_enabled: bool = false
## Which pocket is in the hero's hand. The hand HUD slot is a view of this pocket.
var held_pocket: int = 0

## Points at pocket/backpack slot for yellow frame (item stays in place).
var favorite_area: Area = Area.POCKET
var favorite_index: int = -1


func _init() -> void:
	pockets.resize(POCKET_COUNT)
	backpack.resize(BACKPACK_COUNT)
	for i in POCKET_COUNT:
		pockets[i] = ItemStack.new()
	for i in BACKPACK_COUNT:
		backpack[i] = ItemStack.new()


func emit_changed() -> void:
	changed.emit()


func held_stack() -> ItemStack:
	return slot_at(Area.POCKET, held_pocket)


func setup_storage(slot_count: int) -> void:
	backpack_enabled = false
	favorite_index = -1
	held_pocket = 0
	pockets.clear()
	pockets.resize(slot_count)
	for i in slot_count:
		pockets[i] = ItemStack.new()


func set_held_pocket(index: int) -> void:
	if index < 0 or index >= pockets.size():
		return
	if held_pocket == index:
		return
	held_pocket = index
	emit_changed()


func set_backpack_equipped(equipped: bool) -> void:
	if backpack_enabled == equipped:
		return
	backpack_enabled = equipped
	if not backpack_enabled:
		_move_all_backpack_to_pockets_or_drop_logic()
	_clear_favorite_if_invalid()
	emit_changed()


func total_slots_used() -> int:
	var n := 0
	for s in pockets:
		if not s.is_empty():
			n += 1
	if backpack_enabled:
		for s in backpack:
			if not s.is_empty():
				n += 1
	return n


func slot_at(area: Area, index: int) -> ItemStack:
	match area:
		Area.ACTIVE:
			return held_stack()
		Area.POCKET:
			if index < 0 or index >= pockets.size():
				return null
			return pockets[index]
		Area.BACKPACK:
			if not backpack_enabled or index < 0 or index >= BACKPACK_COUNT:
				return null
			if InventoryLayout.is_backpack_slot_locked(index):
				return null
			return backpack[index]
	return null


func is_favorite(area: Area, index: int) -> bool:
	return favorite_index >= 0 and favorite_area == area and favorite_index == index


func set_favorite(area: Area, index: int) -> void:
	var stack := slot_at(area, index)
	if stack == null or stack.is_empty():
		return
	favorite_area = area
	favorite_index = index
	emit_changed()


func clear_favorite() -> void:
	favorite_index = -1
	emit_changed()


func favorite_stack() -> ItemStack:
	if favorite_index < 0:
		return null
	return slot_at(favorite_area, favorite_index)


func equip_from_slot(from_area: Area, from_index: int) -> void:
	if from_area == Area.ACTIVE:
		return
	if from_area == Area.POCKET:
		set_held_pocket(from_index)
		return
	var src := slot_at(from_area, from_index)
	if src == null:
		return
	swap_slots(from_area, from_index, Area.POCKET, held_pocket)


func extract_slot(area: Area, index: int) -> ItemStack:
	var s := slot_at(area, index)
	if s == null or s.is_empty():
		return null
	var out := ItemStack.new(s.definition, s.quantity)
	s.definition = null
	s.quantity = 0
	if is_favorite(area, index):
		favorite_index = -1
	emit_changed()
	return out


func use_from_slot(area: Area, index: int) -> bool:
	var s := slot_at(area, index)
	if s == null or s.is_empty() or s.definition == null:
		return false
	if not s.definition.is_usable():
		return false
	var used := s.definition
	s.quantity -= 1
	if s.quantity <= 0:
		if is_favorite(area, index):
			favorite_index = -1
		s.definition = null
		s.quantity = 0
	emit_changed()
	item_used.emit(used)
	return true


func swap_slots(a_area: Area, a_index: int, b_area: Area, b_index: int) -> void:
	take_from(self, a_area, a_index, b_area, b_index)


func take_from(
	src: PlayerLoadout,
	src_area: Area,
	src_index: int,
	dst_area: Area,
	dst_index: int
) -> bool:
	if src == null:
		return false
	if src == self and src_area == dst_area and src_index == dst_index:
		return false
	if _is_backpack_slot_locked_ref(dst_area, dst_index):
		return false
	if src._is_backpack_slot_locked_ref(src_area, src_index):
		return false
	var a := src.slot_at(src_area, src_index)
	var b := slot_at(dst_area, dst_index)
	if a == null or b == null or a.is_empty() or a == b:
		return false
	if b.is_empty():
		b.definition = a.definition
		b.quantity = a.quantity
		a.definition = null
		a.quantity = 0
		if src.is_favorite(src_area, src_index):
			src.favorite_index = -1
	elif b.definition == a.definition:
		var room: int = b.definition.max_stack - b.quantity
		if room <= 0:
			return false
		var put: int = mini(room, a.quantity)
		b.quantity += put
		a.quantity -= put
		if a.quantity <= 0:
			a.definition = null
			a.quantity = 0
			if src.is_favorite(src_area, src_index):
				src.favorite_index = -1
	else:
		var tmp_def := a.definition
		var tmp_qty := a.quantity
		a.definition = b.definition
		a.quantity = b.quantity
		b.definition = tmp_def
		b.quantity = tmp_qty
		if src == self:
			_fix_favorite_after_swap(src_area, src_index, dst_area, dst_index)
	src.emit_changed()
	if src != self:
		emit_changed()
	return true


func try_add_item(def: ItemDefinition, qty: int = 1) -> int:
	var remaining := qty
	for i in pockets.size():
		if remaining <= 0:
			break
		remaining = _fill_stack(pockets[i], def, remaining)
	if backpack_enabled:
		for i in BACKPACK_COUNT:
			if remaining <= 0:
				break
			if InventoryLayout.is_backpack_slot_locked(i):
				continue
			remaining = _fill_stack(backpack[i], def, remaining)
	if remaining < qty:
		emit_changed()
	return qty - remaining


func _fill_stack(stack: ItemStack, def: ItemDefinition, qty: int) -> int:
	if qty <= 0:
		return 0
	if stack.is_empty():
		var put := mini(qty, def.max_stack)
		stack.definition = def
		stack.quantity = put
		return qty - put
	if stack.definition != def:
		return qty
	var room := stack.definition.max_stack - stack.quantity
	if room <= 0:
		return qty
	var put := mini(qty, room)
	stack.quantity += put
	return qty - put


func _fix_favorite_after_swap(a_area: Area, a_index: int, b_area: Area, b_index: int) -> void:
	if favorite_index < 0:
		return
	if favorite_area == a_area and favorite_index == a_index:
		favorite_area = b_area
		favorite_index = b_index
	elif favorite_area == b_area and favorite_index == b_index:
		favorite_area = a_area
		favorite_index = a_index


func _clear_favorite_if_invalid() -> void:
	if favorite_index < 0:
		return
	var s := slot_at(favorite_area, favorite_index)
	if s == null or s.is_empty():
		favorite_index = -1


func _move_all_backpack_to_pockets_or_drop_logic() -> void:
	for i in BACKPACK_COUNT:
		if InventoryLayout.is_backpack_slot_locked(i):
			continue
		var s := backpack[i]
		if s.is_empty():
			continue
		var leftover := s.quantity
		leftover -= try_add_item(s.definition, leftover)
		if leftover > 0:
			push_warning("PlayerLoadout: lost %d x %s when removing backpack" % [leftover, s.definition.display_name])
		s.definition = null
		s.quantity = 0


func _is_backpack_slot_locked_ref(area: Area, index: int) -> bool:
	return area == Area.BACKPACK and InventoryLayout.is_backpack_slot_locked(index)
