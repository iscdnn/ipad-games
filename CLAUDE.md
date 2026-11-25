# Project context: iPad Games (Godot minigame collection)

## Goal
Collection of kid-friendly 2D minigames. Godot 4.7, GDScript, GL Compatibility
renderer. Web export into `/docs`, hosted on GitHub Pages, played on iPad
(landscape locked, touch tap + drag only, no multi-touch).

## Rules
- Do not do work unless Isaac asks; defer to him for input.
- Clarify technical decisions and outline the implementation plan with Isaac
  before writing code. Open a PR for review; never push to main.
- Isaac runs the web export and device testing himself.
- Placeholder sprites / SFX only; Isaac swaps in real packs later.

## Display
- Internal res 1180x820 (iPad Air), stretch `canvas_items` + `expand`
  (other iPad shapes show more world, no bars).
- World zoom is per minigame via a Camera2D (`pixel_zoom` export on the
  minigame root). World authored in art pixels at scale 1. UI on CanvasLayers
  stays full-res. Pop-up step art has its own `ui_art_scale` (default 2),
  NOT tied to world zoom. Hi-res pop-up sprites drawn at 2x -> scale 0.5.
- Building tiles: 16px. Goblin Fix-It world zoom 3x. Buildings 5x5 to ~20x20.

## Layout
- `scripts/core/sfx.gd` - autoload `Sfx`. `Sfx.play(&"name", pitch, volume_db, vary)`.
  Pitch variation via Godot's AudioStreamRandomizer. Register sounds in `SOUNDS`
  (several files per name = random variants).
- `assets/sprites`, `assets/sfx`, `assets/tiles` - placeholders.
- `docs/` - web export output (has `.gdignore` so the editor skips it).

## Goblin Fix-It (first minigame)
Main scene `scenes/goblin_fixit/site.tscn`. Top-down 2D view (not isometric),
flat green background, camera centred on the building. Tap a highlighted work
area, pop-up window runs its interaction chain, its tiles swap to repaired.
Goblin stands static at the left screen edge for now (walking later).
Goblin anims (`assets/anim/goblin_frames.tres`): idle default; while a pop-up
step runs it loops the step's `goblin_animation` (default `do`; place + nail
steps `carry`); `jump` once on area complete, then idle.
Tap area -> camera tweens to a goblin close-up (`closeup_zoom` 8, goblin centred
in the space left of the panel) -> pop-up slides in on the right
(`panel_width` 0.6 of screen) -> steps -> pop-up out -> camera back to overview.
Boards (place) and nails (nail) are dragged from the box on the goblin's head
(`carry_box_offset` on Goblin). Steps cover the full screen for input and lay
out inside `panel_rect`.
- `shed.tscn` (Building): `Structure` TileMapLayer = broken building;
  `Areas/<WorkArea>` each with `Fixed` TileMapLayer = repaired tiles drawn over
  it once done. Painted Fixed cells = the area (any contiguous shape).
  WorkArea exports: `steps` (`Array[StepConfig]`, play order), `board_count`
  (shared by every board step), `requires` (unlock order), marching-ants
  settings.
- Step configs (`scripts/goblin_fixit/steps/configs/`): one Resource subclass
  per step type, knows its scene (`scene()`) and holds that step's options.
  `SawStepConfig`, `PlaceStepConfig`, `NailStepConfig` (`nails_per_board`),
  `SandStepConfig` / `PaintStepConfig` (extend `RubStepConfig`: `surface`
  BOARDS or PANEL, `panel_texture`, `brush_radius`, `complete_at`, `passes`;
  paint adds `color`). `CleanStepConfig` (PANEL, big ~512px surfaces):
  `splashes` 3, `ring_radii` (20/40/70 texels = full / 66% / 33%),
  `clean_chances` per ring (1 / 1 / 0.33), `drip_chances` per ring
  (0.3 / 0.15 / 0.1), `drip_length`, `drip_shift`, `clean_passes` 3. The window sets `step.config` before `begin()`.
- Highlight: marching ants traced around the cells, clockwise; each ant
  followed by an equal gap, ants alternate yellow/black.
- Taps: area's cells grown by `tap_padding` (8 art px); overlap goes to the
  nearest area; locked areas still block.
- First building `shed.tscn`: 5x5, all 3 areas open from the start. Example
  chains: area 1 saw -> place -> nail -> sand -> paint (boards), area 2
  clean (512px window) -> sand -> paint (PANEL), area 3 saw -> place -> nail. Layout (X = structure):
  `X111X / X111X / XXXXX / XX33X / X2XXX`
- Placeholders: hatched flat-colour squares/rects for everything (tileset:
  grey structure, brown todo, green fixed, blue spare; tool art same sizes as
  before: board 160x24, saw 64x40, hammer 64x24, nail 8x24, box 64x48).
- Steps (`scripts/goblin_fixit/steps/`): `FixStep` base; `RubStep` base for
  rub-to-cover steps (`sand_step`, `paint_step`): `RubSurface` sprites keep a
  coverage mask (1 px per texture px, CPU-stamped soft brush) and the
  `rub_surface` shader blends before -> after by it; progress = covered pixels,
  rest auto-fills at `complete_at`; `clean_step`: tap = water splash (rings +
  drips run down, each drip/scrub pass adds 1/3, drips cross clean pixels
  free), drag starting on a not-fully-dirty pixel = scrub with bubbles; `saw_step` (drag back
  and forth), `place_step` (drag boards into outlines), `nail_step` (drag nail
  from box, hold to charge hammer, release to swing).
- New building = new scene with same layout; new interaction = new FixStep scene.

## Idea backlog (interactions)
Paint (rub), sand (rub), pull old nails, screwdriver/wrench (circle drag),
sweep debris, lay bricks (trowel + drop), measure and mark, clean windows.

## Later
Minigame hub/menu, save progress, music.
