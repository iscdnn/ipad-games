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

## Layout
- `scripts/core/sfx.gd` - autoload `Sfx`. `Sfx.play(&"name", pitch, volume_db, vary)`.
  Pitch variation via Godot's AudioStreamRandomizer. Register sounds in `SOUNDS`
  (several files per name = random variants).
- `assets/sprites`, `assets/sfx`, `assets/tiles` - placeholders.
- `docs/` - web export output (has `.gdignore` so the editor skips it).

## Goblin Fix-It (first minigame)
Main scene `scenes/goblin_fixit/site.tscn`. Tap glowing part of building, goblin
walks over, pop-up window runs that part's interaction chain, part's tiles swap
to repaired.
- `shed.tscn` (Building): `Structure` TileMapLayer = run-down/bare tiles;
  `Areas/<WorkArea>` each with `Fixed` TileMapLayer = repaired tiles (also
  defines highlight/tap region). WorkArea exports: `steps` (scene chain),
  `board_count`, `nails_per_board`, `requires` (unlock order).
- Shed order: Floor -> Left/Right wall -> Roof. Each: saw -> place -> nail.
- Steps (`scripts/goblin_fixit/steps/`): `FixStep` base; `saw_step` (drag back
  and forth), `place_step` (drag boards into outlines), `nail_step` (drag nail
  from box, hold to charge hammer, release to swing).
- New building = new scene with same layout; new interaction = new FixStep scene.

## Idea backlog (interactions)
Paint (rub), sand (rub), pull old nails, screwdriver/wrench (circle drag),
sweep debris, lay bricks (trowel + drop), measure and mark, clean windows.

## Later
Minigame hub/menu, save progress, music.
