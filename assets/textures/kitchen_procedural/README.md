# Kitchen / floor textures (2012 basement)

Hand-painted-looking tiles, **not noise**. Floor **64×64**, everything else **256×256**. NEAREST filter to sit next to `assets/player/man_0.png`.

Setting: prepared nerd basement, ~2012 — cheap Leroy/IKEA kitchen, linoleum, painted шлакоблок.

| File | What it is |
|------|------------|
| `floor_tile_grid_64.png` | Beige кафель, dirty grout |
| `floor_lino_worn_64.png` | Линолеум «под паркет» (kept; floor meshes use кафель) |
| `cabinet_wood_worn_256.png` | Laminate doors, ольха |
| `countertop_speckle_256.png` | Laminate «искусственный камень» |
| `appliance_metal_smudge_256.png` | Brushed steel (metal shelves only) |
| `wall_paint_basement_256.png` | Painted cinder block |

Fridge / microwave / toaster keep the GLB atlas (unique UVs).

**Regenerate:** `powershell -ExecutionPolicy Bypass -File tools/gen_kitchen_textures.ps1`

**In scene:** `scripts/basement/basement_kitchen_textures.gd` on `KitchenTextures`. Tune `floor_band` / `floor_max_thickness` if a mesh sorts wrong.
