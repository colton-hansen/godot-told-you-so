# Анализ проекта `window-21` (соседняя папка)

Путь: `c:\Users\morrayne\Desktop\gamedev\godot\window-21`  
Движок: **Godot 4.7**, main scene `scenes/world/world.tscn`, физика **Jolt**, рендер Forward+.

Это **FPS-прототип** с инвентарём, подбором предметов, modular level kit и отдельной sci-fi системой «vitals» (наследие другого сеттинга). Для **Told You So** полезно переносить **паттерны и модули**, не lore и не баланс vitals.

---

## Что уже есть (карта систем)

| Область | Файлы / сцены | Суть |
|--------|----------------|------|
| **FPS игрок** | `scripts/player/player.gd`, `fps_player_camera.gd`, `fps_man_view.gd`, `player_locomotion_anim.gd`, `scenes/player/player.tscn`, `fps_man.tscn` | CharacterBody3D: walk/sprint/crouch/jump, head bob, anchor камеры, видимая рука/тело, анимации pickup |
| **Interact** | `interact_focus.gd`, `player_interaction.gd`, `interact_highlight.gd`, `interact_door.gd` | Ray/focus на предметы и двери, **line of sight** для interact, outline подсветка |
| **Инвентарь** | `inventory_grid.gd`, `inventory_stack.gd`, `item_definition.gd`, `inventory_layout.gd`, UI в `scripts/ui/inventory_*.gd` | Сетка **6×8**, **вес + объём (cells)**, locked rows, repack/sort |
| **Мир + лут** | `world_item_pickup.gd`, `world_item_spawner.gd`, `scenes/props/*` | Подбор с анимацией и задержкой `time_to_move` |
| **Storage** | `storage_cube.gd`, `modular_block_storage.gd` | Общий контейнер с тем же `InventoryGrid`, другие лимиты |
| **Модular level** | `scenes/modular/*`, `modular_snap.gd`, tools `bake_modular_*` | Сборка интерьеров из кусков (пол, дверь, roof…) |
| **Мир** | `world.tscn`, `home.tscn`, `perimeter_terrain.tscn` | Тестовый outdoor + дом |
| **UI** | `player_hud.gd`, `crosshair.gd`, `quick_use_wheel.gd` | HUD, reticle, quick use |
| **Vitals (другой дизайн)** | `player_vitals.gd`, `connection_zone.gd` | HP, sync, charge, blood, rust, oxygen, маска, connection zones — **не про TYS 1:1** |
| **Tools** | `tools/test_*.gd`, `validate_*.gd`, terrain bake | CI-style проверки скриптов, тесты инвентаря |

---

## Что имеет смысл **подтянуть** в Told You So

### Высокий приоритет

1. **FPS stack** — `player.gd` + `InteractFocus` + pickup pipeline (`player_interaction` + `fps_man_view.play_pickup`). Совпадает с вашим упором на **анимации и иммерсивность**.
2. **InventoryGrid + ItemDefinition** — weight + grid cells + locked «карманные» ряды (`PLAYER_LOCKED_BOTTOM_ROWS`). Близко к **личным карманам + отдельному storage** (`StorageCube` / layout constants).
3. **Storage pattern** — отдельный `InventoryGrid` с большим лимитом на объекте базы; можно повесить на **общее хранилище подвала** и позже на **вешалку** (отдельный grid только для одежды — расширение).
4. **Interact + LOS** — `_has_clear_line_of_sight` в `interact_focus.gd` — база для **LOS роботов** (переиспользовать raycast layer/mask).
5. **Modular kit** — быстрая сборка **подвала** и **дома** (первая рейд-локация без роботов).

### Средний приоритет

6. **World item pickup** — sync длительности анимации и `ItemDefinition.time_to_move`.
7. **Inventory UI** — grid view, context menu, character preview (для экипировки/одежды).
8. **Input map** — move, crouch, interact, inventory (уже в `project.godot` window-21).

### Низкий приоритет / переработать

9. **PlayerVitals** — заменить на **голод / жажда / мораль / травмы**; можно оставить только идею **debuff скорости** (`move_speed_scale`).
10. **ConnectionZone** — sci-fi «связь»; в TYS не нужна как есть.
11. **Perimeter terrain tools** — если рейды в основном интерьеры/городские локации, terrain optional.

---

## Чего **нет** в window-21 (нужно писать с нуля)

- Кооп / сеть / proximity chat  
- Фазы «день → все спят → сбор 1 мин → вылазка»  
- Роботы: FSM investigate / chase, **noise cylinders**, LOS pursuit  
- Мораль, гости, бартер, договорённости  
- Приборы (микроволновка, открывашка), мусорка, автосброс лута после рейда  
- Питомцы, лоток, вонь, рвота как шум  
- Трейты и социальные конфликты  

---

## Рекомендуемая стратегия переноса

1. **Не копировать проект целиком** — зависимости от assets/world window-21 и vitals lore.  
2. **Портировать файлами** с префиксом/адаптацией: `inventory/*`, `player/*` (без vitals), `interact_*`, `storage_*`.  
3. **Согласовать `InventoryLayout`**: player pockets vs `STORAGE_*` vs future `CLOTHING_RACK_*`.  
4. **Единые collision layers** — world, player, interact, enemy sight, noise (задать в `project.godot` TYS до первого робота).  
5. **Тесты** — перенести идею `tools/test_inventory_mechanics.gd`, `validate_all_scripts.gd`.

---

## Зависимости прототипа

- FBX персонаж (`fps_man`, animations sync tool)  
- Test items: `resources/items/test_item_*.tres`  
- Modular pieces baked from FBX (`assets/modular`, tools в `tools/`)

При переносе в TYS заменить placeholder assets на PS1-style модели, **API скриптов** можно сохранить.

---

*Документ для планирования портов; vertical slice TYS — отдельно, когда будет запрос.*
