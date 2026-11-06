# Структура проекта Told You So

Дерево папок (логика размещения ассетов и кода). Пустые каталоги держим через `.gitkeep`.

```
told-you-so/
├── docs/                          # Дизайн и заметки
│   ├── design.md
│   ├── project-structure.md
│   └── window-21-analysis.md
├── addons/                        # Сторонние плагины Godot
├── assets/
│   ├── art/                       # 2D UI, иконки, постеры
│   ├── audio/                     # SFX, музыка, voice
│   ├── models/                    # FBX/GLTF персонажи, пропсы, роботы
│   └── textures/                  # Общие текстуры, материалы
├── resources/
│   ├── items/                     # ItemDefinition (.tres)
│   ├── traits/                    # Трейты персонажей
│   ├── raids/                     # Данные локаций вылазок
│   └── appliances/                # Микроволновка, открывашка, вешалка…
├── scenes/
│   ├── basement/                  # Подвал (быт, сон, зона сбора)
│   ├── raid/                      # Локации вылазок (home, shop, …)
│   ├── player/                    # FPS rig, камера
│   ├── props/                     # Подбираемые предметы, двери, мусорка
│   ├── ui/                        # HUD, инвентарь, договорённости
│   └── world/                     # Общие sub-scenes, окружение
├── scripts/
│   ├── autoload/                  # GameState, RunManager, …
│   ├── basement/                  # День, сон, гости, приборы
│   ├── inventory/                 # Grid, items, storage
│   ├── net/                       # Мультиплеер (позже)
│   ├── player/                    # Движение, interact, vitals
│   ├── raid/                      # Роботы, шум, LOS, травмы
│   ├── systems/                   # Мораль, договорённости, время
│   └── ui/
├── tools/                         # Editor scripts, bake, validate
├── project.godot
├── icon.svg
└── .gitignore
```

## Соглашения

- **Сцены** — только компоновка; логика в `scripts/`.
- **Данные** — Resource (`.tres`) в `resources/`, не хардкод в сценах.
- **Имена сцен** — snake_case: `basement_main.tscn`, `raid_home.tscn`.
- **Группы Godot** — `player`, `raid_enemy`, `noise_source`, `interactable` (уточнять по мере кода).
