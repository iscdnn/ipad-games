# Project context: Sheep Shearer (Godot web game for iPad)

Handoff notes so a new chat/session can continue without the old conversation.

## Goal
Simple 2D farming-themed game, coded in Godot, exported to web, played by
someone on an iPad (Safari, added to Home Screen). No backend.

## Decisions made
- Engine: Godot 4.7, **Compatibility** renderer (only one supported on web).
- Web export: **single-threaded** (Thread Support OFF) so no COOP/COEP headers
  are needed; works on itch.io, Netlify, Cloudflare Pages, GitHub Pages.
- Saves: `user://` -> browser IndexedDB. Player must launch from the Home Screen
  icon; clearing Safari site data wipes saves. No sync/backup yet.
- Input: touch arrives as emulated left-click; `game.gd` only handles
  `InputEventMouseButton` (avoids double-handling).
- Everything procedural for now: sprites in `scripts/sheep_art.gd`, sounds in
  `scripts/sfx.gd`, UI built in code. Scenes are near-empty on purpose.
- Particles use `CPUParticles2D` (most reliable on web).
- Base viewport 1280x720, stretch `canvas_items`, aspect `expand`; landscape
  recommended. Sheep spawn using `get_viewport_rect().size`.

## Current state (v0.1 placeholder)
Menu (rainbow bg, "Tap to Play") -> 60 s round: sheep enter from random left or
right edge points at random speeds, tap to shear (2-frame walk cycle for
sheared and unsheared), wool particle burst + snip SFX, "+1" popup, score +
persisted high score, game-over panel (Play Again / Menu).

**Not yet run in Godot.** Scripts were hand-reviewed only. First job: open the
project, fix any parse/runtime errors, test in browser and on the iPad.
`export_presets.cfg` was hand-written; verify in Project > Export.

## File map
- `scenes/menu.tscn`, `scripts/menu.gd` - title screen
- `scenes/game.tscn`, `scripts/game.gd` - round logic, HUD, overlay, effects
- `scripts/sheep.gd` - sheep node (movement, animation, shear state)
- `scripts/sheep_art.gd` - placeholder sprite generator (+ wool particle tex)
- `scripts/sfx.gd` - placeholder audio generator
- `scripts/save.gd` - autoload `Save` (high score)
- `README.md` - export + hosting steps

## Export (short)
Project > Export > Web, Thread Support OFF, PWA ON, export to
`build/web/index.html`, host over HTTPS, iPad: Safari > Share > Add to Home
Screen. Details in README.md.

## Free asset shortlist (check each license before shipping)
CC0: Kenney Tiny Farm (16x16), Kenney Isometric Miniature Farm, Kenney Pixel
Platformer Farm Expansion, LushMustache PixelFarm, pixel32 farm and shack (OGA).
Free, other terms: Sunnyside (crops with 5 growth stages), Sprout Lands,
Bloomseed, VectoRaith Farming Sim pack (sheep/cow/chicken/goat), Padrosives
(credit required). Avoid for closed games: OGA LPC assets (CC-BY-SA/GPL).

## Ideas / backlog
- Swap in real sprites and SFX; add music + mute toggle
- Golden sheep (bonus), black sheep (penalty), bonus time
- Combo multiplier, difficulty select, pause button
- Wool collected as currency -> upgrades (the actual "farming" loop)
- Crops/field scene (Sunnyside crops), day/night
- Haptics via JS bridge (iOS Safari limited), fullscreen/PWA icons
- Optional: export/import save code for backup across devices
- Test on real iPad: touch accuracy, audio unlock, memory, safe-area insets

## Working notes
- Prefers terse "caveman" replies (set in user preferences).
- Dev machine "roshar", Windows, project at `C:\dev\bob\web-famework`.
