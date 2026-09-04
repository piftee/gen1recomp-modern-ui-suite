# Changelog

## 0.1.12 - 2026-09-04

- Modern PC now themes the Gold, Silver, and Crystal storage mode chooser, so
  the component is visible immediately instead of only after an operation is
  selected. Native mail, box-selection, and save-confirmation states remain
  intact.
- Fixed Gen 2 move names collapsing to two-letter abbreviations on compact
  widescreen layouts. Common 200px and 256px battle canvases now use four
  readable move rows beside the Power/PP card; genuinely wide canvases retain
  the 2x2 grid.
- Matched Gen 2 move navigation to the visible responsive layout and reclaimed
  excess spacing before effectiveness markers so ten-character stock names
  remain intact when they fit.

## 0.1.11 - 2026-09-04

- Fixed literal `(PROMPT)` control markers appearing in Gen 3 Inspired UI
  battle dialogue. The compatibility adapter now supplies a display-only
  clean message while leaving the engine's queue and prompt timing unchanged.
- Fixed overlapping move names and cursors on Gen 3 UI's in-battle move-
  replacement screen. Typed Move Colors now yields Summary and move-learning
  surfaces when Gen 3's Pokemon presentation owns them.

## 0.1.9 - 2026-09-04

- Restored visibly distinct Start Menu placement choices. **LEFT** and
  **RIGHT** now dock to the true logical screen edges while **MID-L**,
  **CENTER**, and **MID-R** retain their inset positions.
- Fixed the one-frame white flash when returning from a Pokemon's Party stats
  on portrait phones. Summary now preserves and fills the Party screen's
  active render surface instead of reallocating a 160x144 canvas.

## 0.1.8 - 2026-09-04

- Fixed suite menu cursors inheriting a fast **Overworld Speed** setting.
  Start, Party, Summary, Bag, item and Pokemon PC, Pokedex, and their child
  prompts now consistently follow **Menu Speed** without changing battles or
  ordinary overworld play.

## 0.1.7 - 2026-09-04

- Fixed the Start Menu crash in Phosphor on iPhone when Phosphor's controller
  overlay is enabled. The overlay fallback now uses sandbox-safe device and
  display signals instead of the blocked `love.system` module.

## 0.1.6 - 2026-09-04

- Fixed doubled move names and cursors in the Gen 1 GAME battle layout when a
  localization moves the native move-list columns left for longer strings.
- Colours are now applied while the native row is drawn, so translated names
  retain the localization's coordinates and the stock layout stays unchanged.

## 0.1.5 - 2026-09-04

- Preserved active Stadium 2 battle scenes in Gold, Silver, and Crystal. The
  Battle Info HUD now yields its stock widescreen compositor to the captured
  3D presenter instead of replacing the arena with a centred 2D capture.

## 0.1.4 - 2026-09-04

- Added a Start-button Bag sorting menu with ascending and descending category
  and item-name orders. Category sorting keeps each pocket's internal order.
- Fixed Voxel battle gender rendering when Gender Mod and Crystal 251 are both
  enabled: one coloured marker now owns each level instead of overlapping a
  second black symbol.
- Kept that provider arbitration active under **Disable All UI**, without
  enabling any Modern UI presentation, and removed the isolated gender glyphs
  from caught-mon nickname and PC-transfer frames.

## 0.1.3 - 2026-09-03

- Shortened flat-manager and component-page labels so every setting fits the
  original 160x144 options layout on Gen 1 and Gen 2.
- Removed unsupported percent glyphs from battle-opacity value labels.
- Added a live options sweep that reaches all 31 persisted settings, the Start
  icon action, and all 77 advertised values through the real menu controller.
- Added reusable suite adapters and focused Party fixtures for complete visual
  regression coverage of all seven embedded components.
- Fixed the native Gen 2 proof so its settings smoke restores the Start Menu
  master toggle before the screen matrix runs.

## 0.1.0 - 2026-09-03

- Combined seven current Modern UI components into one package.
- Added live component switches and one unified settings hub.
- Added native/downstream screen fallback and hook/event gating.
- Added idempotent migration from standalone option buckets.
- Kept expanded Bag storage active as a save-safety layer when its UI is off.
