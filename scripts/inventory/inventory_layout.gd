class_name InventoryLayout
extends RefCounted

const POCKET_COUNT := 6
const QUICK_SLOT_COUNT := POCKET_COUNT
const STORAGE_SLOT_COUNT := 12
const STORAGE_COLUMNS := 6
const BACKPACK_COLUMNS := 6
const BACKPACK_ROWS := 3
const BACKPACK_COUNT := BACKPACK_COLUMNS * BACKPACK_ROWS
const BACKPACK_LOCKED_COUNT := BACKPACK_COUNT
const BACKPACK_UNLOCKED_COUNT := 0

const ACCENT_COLOR := Color("#0527E4")
const COLOR_ACTIVE := ACCENT_COLOR
const COLOR_SLOT := Color(1, 1, 1, 0.85)
const COLOR_POCKET := COLOR_SLOT
const COLOR_FAVORITE := COLOR_SLOT
const COLOR_BACKPACK := COLOR_SLOT
const SLOT_FILL := Color("#00000095")
const PANEL_BG := Color("#00000090")
const LOCKED_CROSS := Color("#ffffff80")
const LABEL_COLOR := Color(1, 1, 1, 0.92)
const BADGE_BG := Color("#00000095")

const SLOT_SIZE_PX := 64
const SLOT_GAP_PX := 8
const PANEL_PADDING_PX := 16
const SEPARATOR_HEIGHT_PX := 4
const STORAGE_TITLE_HEIGHT_PX := SLOT_SIZE_PX / 2
const BORDER_WIDTH_PX := 3
const LOCKED_CROSS_WIDTH_PX := 4.0
const TITLE_PAD_PX := 8.0
const INVENTORY_DIVIDER := SLOT_FILL
const FONT: Font = preload("res://assets/fonts/GeistPixel.ttf")
const FONT_SIZE := 18


static func is_backpack_slot_locked(_index: int) -> bool:
	return true


static func quick_row_width_px() -> int:
	return QUICK_SLOT_COUNT * SLOT_SIZE_PX + (QUICK_SLOT_COUNT - 1) * SLOT_GAP_PX


static func backpack_grid_width_px() -> int:
	return BACKPACK_COLUMNS * SLOT_SIZE_PX + (BACKPACK_COLUMNS - 1) * SLOT_GAP_PX


static func backpack_grid_height_px() -> int:
	return BACKPACK_ROWS * SLOT_SIZE_PX + (BACKPACK_ROWS - 1) * SLOT_GAP_PX


static func panel_inner_width_px() -> int:
	return maxi(quick_row_width_px(), backpack_grid_width_px())


static func panel_popup_size_px(
	backpack_visible: bool,
	storage_visible: bool = false,
	storage_slots: int = STORAGE_SLOT_COUNT
) -> Vector2:
	var inner_w := panel_inner_width_px()
	var inner_h := STORAGE_TITLE_HEIGHT_PX + SLOT_GAP_PX + SLOT_SIZE_PX
	if backpack_visible:
		inner_h += SLOT_GAP_PX + STORAGE_TITLE_HEIGHT_PX + SLOT_GAP_PX + backpack_grid_height_px()
	if storage_visible:
		inner_h += (
			SLOT_GAP_PX
			+ STORAGE_TITLE_HEIGHT_PX
			+ SLOT_GAP_PX
			+ storage_grid_height_px(storage_slots)
		)
	var pad := PANEL_PADDING_PX * 2
	return Vector2(inner_w + pad, inner_h + pad)


static func hud_bar_size_px() -> Vector2:
	var pad := PANEL_PADDING_PX * 2
	return Vector2(quick_row_width_px() + pad, SLOT_SIZE_PX + pad)


static func storage_columns_for(slot_count: int) -> int:
	return clampi(slot_count, 1, STORAGE_COLUMNS)


static func storage_rows(slot_count: int = STORAGE_SLOT_COUNT) -> int:
	return ceili(float(maxi(slot_count, 1)) / float(storage_columns_for(slot_count)))


static func storage_grid_width_px(slot_count: int = STORAGE_SLOT_COUNT) -> int:
	var cols := storage_columns_for(slot_count)
	return cols * SLOT_SIZE_PX + (cols - 1) * SLOT_GAP_PX


static func storage_grid_height_px(slot_count: int = STORAGE_SLOT_COUNT) -> int:
	var rows := storage_rows(slot_count)
	return rows * SLOT_SIZE_PX + (rows - 1) * SLOT_GAP_PX


static func storage_panel_size_px() -> Vector2:
	var title_h := 24
	var inner_w := storage_grid_width_px()
	var inner_h := title_h + SLOT_GAP_PX + storage_grid_height_px()
	var pad := PANEL_PADDING_PX * 2
	return Vector2(inner_w + pad, inner_h + pad)
