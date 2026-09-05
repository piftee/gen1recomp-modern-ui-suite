# Changelog

## 0.1.16 - 2026-09-05

- Fix Battle Art 2.1.0's Gen 2 3D battles being covered by the suite's flat
  battle presentation. Recognize `BATTLE_ART_VOXEL_GEN2` and query its public
  scene contract with the live battle screen, retaining support for older
  providers that identify scenes with the battle model.
- Declare the new Battle Art ID as an optional dependency so it installs its
  renderer before the suite captures that renderer.
- Keep Battle Art's arena, sprites, camera and animation composition while
  the suite's move cards remain available. Restore normal suite presentation
  when no active 3D scene owns this battle.
- Honor Battle HUD OFF immediately on an already-open Gen 2 battle.
- Add actual-release native coverage for 3D scenes, component toggles, aspect
  ratios, move navigation/reordering, animation and 3D OFF/ON transitions.
- Update the embedded Battle Info HUD ledger to 0.9.4.

## 0.1.15 - 2026-09-05

- Corrected Gen 2 caught/nickname dialogue: native page wrapping and glyph-safe
  long-word breaks remain visible, including the native Yes/No menu, focus,
  timing, B cancellation and callbacks. Move/command state remains native.
- Corrected Red's GAME move-row phase guard so FIGHT/PKMN labels are not
  overwritten; restore row RGB after the native palette pass. Keep the player
  HUD below the opponent picture and give the engine-wide EXP footer its own
  border row. Existing GAME layout and third-party ownership remain intact.
- Re-audited all 831 Gen 2 pictures and restored questionable white cutouts.
  Silver/Crystal Goldeen now restores its complete verified native white fin,
  including transparency already missing in the runtime's source image.
  Exact-source guards preserve replacement sprites and original RGB/outline;
  Gold Goldeen is unchanged. Earlier mask agreement did not prove that every
  removed white region was background; independent preservation checks now
  protect genuine white details and retain uncertain regions.
- Added independent QOL → UNLIMITED PP, a single player-only On/Off control,
  OFF by default. It works with every interface disabled, does not rewrite
  stored PP, and keeps native Disable/opponent/link-battle rules. Bulk UI
  switches never change it. Active battle PP uses a hand-pixelled ∞ symbol;
  no unsupported font glyph or global text/HP substitution is used.
- Gen 2 retains its native move menu when Move Colors is Off, including when
  Battle HUD stays On; no empty replacement controls are left behind.
- Retained all 0.1.14 PC group/box controls, Bag money/sorting/scrolling,
  Pokédex actions, full-width Gen 2 2×2 moves and amber held-source indicator.
- Published release; see RELEASE_NOTES.md for the complete changes since 0.1.12.
- Release packaging excludes QA files and publishes detailed versioned notes.

## 0.1.14 QoL test - 2026-09-05

- PC: party end wrapping; optional Box Exclusive local navigation, Off by
  default; START Multiple Selections across boxes, ordered group placement,
  cross-party swaps and Swap Whole Party for six selected boxed Pokémon.
  Complete-result checks and rollback preserve capacity, the usable party,
  Eggs, Pokémon identities, move data, held items and native Mail ownership.
- Battle: stable Left/Center/Right dialogue alignment, full-opacity-only
  Default/Gray/White/Black neutral panels, and responsive Original/Left/Right
  information placement in supported native/Wide presentations.
- Normal 16:9 Gen 2 battles use a full-width 2×2 move grid with a slim Power/PP
  strip below. Very narrow intermediate canvases retain the readable list;
  explicit side details require sufficient width. The amber reorder border
  now belongs to the held source move, not Power/PP; destination focus and
  native reorder/PP/Disable/Transform behavior are preserved.
- Bag: exact money replaces the Modern/Pocket header title in Gen 1 and Gen 2.
  Descriptions remain still when they fit; only overflow scrolls horizontally,
  retaining all final words and resetting on selection/content/layout changes.
  Native prompts/actions stay static, and Gen 2 Pocket clipping respects its
  cartridge panel. Six virtual views, sorting and full-width Modern details
  remain intact.
- PC/Pokédex portraits: reviewed background cutouts cover 153 species and 387
  game/form variants across the complete 831-picture Gen 2 audit. Exact full-
  image signatures preserve white artwork and skip unknown/modified sprites;
  no source assets or global native picture methods are changed.
- Preserved the existing Pokédex EVO/MOVE coexistence, Gen 2 native PC entry,
  Mail actions, Start color labels, renderer ownership and suite OFF/ON gates.
- Packaged QA drivers and fixtures are now explicitly excluded. This is a
  distinct local test build; the delivered 0.1.13 archive remains unchanged.

## 0.1.13 - 2026-09-05

- Gen 2's Modern Bag now matches Gen 1's six views: All, Items, Medicine,
  Balls, TMs/HMs and Key. These are filters over the four native stores,
  retaining their capacities and each item's native actions.
- START offers category ascending/descending and names A-Z/Z-A, preserving
  item quantities and selection. Name-sorted TMs/HMs stay visibly sorted;
  manual reorder and per-view cursor memory are retained. The Pocket skin
  keeps its four-pocket presentation and also gains START sorting.
- Kept compact Bag description and confirmation lines inside their footer,
  including while the sort menu is open.
- Moved Modern Bag details into a full-width bottom panel, giving all six
  tabs and the item list the full available width. Labels step down to
  shorter forms only when the actual tab width requires it.
- Renamed Start menu colour choices MAP to AUTO (area-palette inheritance)
  and DMG to GREEN (fixed classic Game Boy green). Theme labels now say
  Colour; RED/BLUE, saved values, defaults and actual palettes are unchanged.
- Picking up a Gen 2 battle move with Select now shows a persistent hollow
  arrow at its source and turns the existing Power/PP panel border amber.
  Normal move details remain visible, without added labels or instructions.
  The focus frame still follows the destination; native input, PP and move
  data stay authoritative, and compact move-name space is preserved.
- Gen 2 Bill's/Someone's PC now opens the combined party-and-box grid
  directly, with Gen 1's pickup, drop, swap, reorder and cross-box controls.
- Native Gen 2 Item, Mail and Mailbox actions are available from START.
  Letters follow party reordering; transfers protect Mail carriers, Eggs and
  the last usable party member. Closing saves safely with failure retry.
- PC integration passed 109 native checks per game on Gold, Silver and
  Crystal using isolated imports and fixture saves.
- Gen 2 Pokédex entries now expose MOVE: level-up moves, precisely numbered
  compatible TMs/HMs, and Crystal tutors. Select a move for its source, type,
  power, accuracy, PP, Gen 2 damage class and ROM/mod description. Compact
  and wide layouts share A/B navigation.

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
