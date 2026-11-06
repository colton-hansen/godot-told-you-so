class_name InventoryLayout
extends RefCounted

const POCKET_COUNT := 4
const QUICK_SLOT_COUNT := 6
const BACKPACK_COLUMNS := 6
const BACKPACK_ROWS := 5
const BACKPACK_COUNT := BACKPACK_COLUMNS * BACKPACK_ROWS
const BACKPACK_LOCKED_COUNT := 12
const BACKPACK_UNLOCKED_COUNT := BACKPACK_COUNT - BACKPACK_LOCKED_COUNT

const ACCENT_COLOR := Color("#0527E4")
const COLOR_ACTIVE := ACCENT_COLOR
const COLOR_POCKET := Color("#3d9a4a")
const COLOR_FAVORITE := Color("#d4a017")
const COLOR_BACKPACK := Color("#5a5a5a")
const SLOT_FILL := Color("#00000095")
const PANEL_BG := Color("#00000090")
const LOCKED_CROSS := Color("#ffffff80")
const LABEL_COLOR := Color(1, 1, 1, 0.92)
const BADGE_BG := Color("#00000095")

const SLOT_SIZE_PX := 64
const SLOT_GAP_PX := 8
const PANEL_PADDING_PX := 16
const SEPARATOR_HEIGHT_PX := 4
const BORDER_WIDTH_PX := 3
const LOCKED_CROSS_WIDTH_PX := 4.0


static func is_backpack_slot_locked(index: int) -> bool:
	return index >= BACKPACK_UNLOCKED_COUNT


static func quick_row_width_px() -> int:
	return QUICK_SLOT_COUNT * SLOT_SIZE_PX + (QUICK_SLOT_COUNT - 1) * SLOT_GAP_PX


static func backpack_grid_width_px() -> int:
	return BACKPACK_COLUMNS * SLOT_SIZE_PX + (BACKPACK_COLUMNS - 1) * SLOT_GAP_PX


static func backpack_grid_height_px() -> int:
	return BACKPACK_ROWS * SLOT_SIZE_PX + (BACKPACK_ROWS - 1) * SLOT_GAP_PX


static func panel_inner_width_px() -> int:
	return maxi(quick_row_width_px(), backpack_grid_width_px())


static func panel_popup_size_px(backpack_visible: bool) -> Vector2:
	var inner_w := panel_inner_width_px()
	var inner_h := SLOT_SIZE_PX
	if backpack_visible:
		inner_h += SLOT_GAP_PX + SEPARATOR_HEIGHT_PX + SLOT_GAP_PX + backpack_grid_height_px()
	var pad := PANEL_PADDING_PX * 2
	return Vector2(inner_w + pad, inner_h + pad)


static func hud_bar_size_px() -> Vector2:
	var pad := PANEL_PADDING_PX * 2
	return Vector2(quick_row_width_px() + pad, SLOT_SIZE_PX + pad)
