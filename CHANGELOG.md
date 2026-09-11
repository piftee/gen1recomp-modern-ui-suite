# Changelog

## [0.1.28] - 2026-09-11

- Fix Gen 2 item-PC pages being drawn twice at different sizes. Keep deposit
  quantity prompts and messages visible, and fit compact footer text.
- Align Gen 2 battle framing, controls and background masks. Add Fill, 16:9
  and 4:3 in Battle settings; retain framing for native/text-only moves and
  prevent duplicate scenes under transparent prompts.
- Render Pocket skin labels with crisp bitmap text, including MEDS.
- Keep small-icon selection in Party → Icon Source. Add Sprite Info to
  explain portrait providers, matching choices and artwork fallbacks.
- Track collected shiny species per save in Gen 1 and Gen 2. Show shiny
  markers and an L/R shiny-only Pokédex filter. Backfill from owned Pokémon
  and recorded shiny Hall of Fame entries; preserve history after release.
- Adapt selected Highlander contributions: optional shop owned counts,
  two-second area names and reduced/off low-HP alerts. Shop counts and area
  names default off; low-HP alerts retain the native default. Crystal's
  existing map signs keep priority. Credit Waifu4Life's source contribution.

## [0.1.27] - 2026-09-08

- Restore the visible four-move selector when learning a move in Gen 2 battles.
  The modern HUD had hidden the native list while its cursor still accepted A.
  Selection, cancellation and HM protection stay with the native controller.
- Remove the extra underline below the Gen 2 rename field. Highlight the
  active character on the same line as the name.
- Use the actual Gen 1 modern Bag renderer in Gen 2: pocket icons and colour
  palettes, framed six-row lists, selection arrows, side detail cards,
  portrait stacking, empty states, descriptions and readable button hints.
- Use Gen 1 menu frames for Gen 2 Bag actions, sorting and toss confirmation;
  anchor quantity selection to the selected item. Keep native four-pocket
  storage, six virtual views, TM/HM rules, battle callbacks and touch controls.

## [0.1.26] - 2026-09-08

- Share the Gen 1 Pokédex renderer with Gen 2: identical index rows, actions,
  top tabs, INFO cards, field notes, STATS, FAMILY and MOVES layouts.
- Match Gen 1's softer interface palette, frames, spacing and compact layout.
  Retain Gen 2 artwork, all six base stats, native evolution conditions,
  learnsets, TM/HM and tutor data, and discovery restrictions.
- Match Gen 1 controls: A opens index actions; Left/Right changes entry tabs;
  Up/Down scrolls notes, selects relatives or moves; A plays a cry or opens
  the selection; B returns. SELECT opens search and START opens Gen 2 tools.
- Combine both native description pages into the scrollable INFO notes card.
  New-catch entries retain their native two-page completion sequence.
- Show complete evolution families in the shared grid, replacing 0.1.25's
  separately paged cards. Preserve native AREA, ordering and Unown tools.

## [0.1.25] - 2026-09-07

- Remove repeated name, Dex number and type labels from the Gen 2 DATA
  portrait panel, and enlarge and center its sprite. Keep identifying details
  on the right, moving the number into the header on compact layouts.
- Give Gen 2's Pokédex EVO page Gen 1-style sprite cards with type-coloured
  selection, shadows and the selected evolution condition. Left/Right or
  Up/Down selects; A opens a known relative; B returns to the original entry.
  Larger families page automatically and undiscovered forms stay hidden.
- Keep compact descriptions within the panel and scroll long text; reset
  scrolling when changing species, description page or layout width.

## [0.1.24] - 2026-09-07

- Fix Party's Left/Right navigation on native-width and 4:3 Gen 2 grids.
- Preserve Kanto Reforged's extra summary page, including gender, held item,
  ability and complete scrolling description. Unknown extra pages use their
  inherited renderer.
- Enlarge stats portraits on wide summaries and move the Pokédex number and
  type labels above the stats column.
- Fit Gen 4 Battle Art menu portraits to shared animation bounds, preserving
  every frame's positioning and white markings.
- Add optional direct touch to START, Party and Modern Bag lists/pockets.
  One tap selects; a second tap within two seconds confirms through the native
  controller. Swipes navigate lists and pockets. Native dialogs retain normal
  controls. Each component's DIRECT TOUCH option defaults to On.
- Add the [full screen gallery and setup examples](GALLERY.md).


## [0.1.23] - 2026-09-07

- Add independent Fill, 16:9 and 4:3 aspect-ratio controls to Party, Bag,
  PC and Pokédex, including their related full-page views. Preserve native
  Widescreen Off and Faithful Ratio preferences.
- Prevent Gen 2's native overlay pass from drawing a second compact copy of
  a modern menu underneath messages such as Wilds of Kanto's Follow action.
  Native messages inherit the menu's scale on narrow displays.
- Give Gen 1 native child scenes a complete backing at their parent's size.
  The newer transparent evolution controller retains its actual intro
  TextBox over opaque paper, including evolution entered through the Bag.
  Keep centered artwork and palette/true-colour regions aligned.
- Clip Gen 2 menu decoration to the selected aspect ratio so backdrop lines
  cannot spill into the surrounding margins.

## [0.1.22] - 2026-09-06

- Fix Category Asc/Desc sorting within individual Bag pockets in Gen 1 and
  Gen 2. Use consistent item-family priorities and numeric TM/HM order,
  preserve the selected pocket/item and quantities, and retain sorting after
  Gen 2 rebuilds its machine list.
- Add independent SPRITE and ICONS controls to the suite hub. Large summary,
  Pokédex and PC portraits can follow Battle Art or Crystal Animated Sprites,
  or retain the existing Default handling. Preserve front-generation choices,
  animation, shiny variants and source colours in both generations.
- Keep small Party/PC icons separate from battle portraits. Auto, Original,
  Menu Pack and Followers share Party's existing Icon Source preference;
  unavailable providers fall back to the existing renderer.
- Fix grey battle-HUD patches appearing over the Gen 1 Bag. Remember the
  current pocket, item and scroll position across Bag visits during play,
  including after using an item in battle.
- Fix Gen 2 Text Only moves: retain the native list, cursor, TYPE/PP box and
  move-reordering controls while applying legible type colours.
- Align Gen 1 move-learning colours with the engine's actual native rows;
  preserve native text when the layout is unknown.
- Make the Gen 2 party selection visible on pale cards and recognize
  translated built-in START actions when selecting their icons.
- Draw one caught-species marker instead of a deferred six-slot party row
  in Gen 1 battles with sprite companions. Preserve its red/white colours,
  monochrome modes, Battle Art capture and native trainer rows.
- Retain the Crystal sprite fixes from 0.1.21. Gen 4 source-frame padding is
  unchanged; some animations still appear smaller in fitted menu portraits.

## [0.1.21] - 2026-09-05

- Fix Crystal Animated Sprites with Shiny Visuals compatibility in the Gen 2
  Pokédex, party summary and PC previews. Preserve static and animated source
  colours, shiny variants and companion animations; keep cartridge palettes
  for native artwork.

## 0.1.20 - 2026-09-05

- Gen 2 Party: show native refusal and item-result messages with an A/B
  acknowledgement hint. Selecting a fainted Pokémon previously left an
  invisible message consuming input until A or B dismissed it.

- Gen 2: when the party and current box are full, ordinary wild-ball attempts
  automatically select the next box with space, wrapping from Box 14 to Box 1.
  The selected box remains active for subsequent catches and PC visits.
- Keep native capture data, held items, nickname prompts, Pokédex updates,
  storage healing and specialty-ball effects. Full storage still refuses
  without using a ball or a turn; trainer/contest/tutorial flows stay native.

## 0.1.19 - 2026-09-05

- Party: Select picks up a slot, Select drops/swaps, and B cancels the hold.
  Add footer hints and preserve Gen 2 Mail ownership during swaps.
- Fix vertical navigation getting stuck in a single-slot column, including
  fainted-Pokémon replacement menus. Forced Gen 2 choices skip Cancel.
- Start: add START ICON ORDER for every live native/mod action, with Left/Right
  reordering and persistent preferences. Open Start once to discover the list.
- Bag: add Hide All Items, Open On and a Select-based Bag Pocket Order editor.
  Category sorting reveals its result in All Items when enabled; the selected
  All Items backpack symbol now contrasts with its active tab.

## 0.1.18 - 2026-09-05

- Suppress the original Gen 1 HP bar tiles while drawing the enhanced HUD,
  including their separate end caps. This removes the old cap protruding
  beyond the new meter and prevents Battle Art from adding a shadow to it.
- Apply the fix to classic battles and Battle Art's captured and fallback
  HUDs. The lower HUD bracket remains, and HUD OFF restores the original bars.
- Update the embedded Battle Info HUD to 0.10.1.

## 0.1.17 - 2026-09-05

- Replace Gen 1's separate large HP/EXP number rows with compact white
  readouts inside coloured bars, matching the party menu arrangement.
- Leave padding between the widescreen EXP bar and the panel's bottom border.
- Add these meters to Battle Art's captured 3D HUD and native fallback while
  preserving its HUD positions, scale, text contrast and scene composition.
- Align Gender Mod's ink, captured artwork and coloured overlay to the same
  cell, removing the offset edge beside the level. Reserve its cell when a
  status label is visible in the widescreen panel.
- Preserve the caught indicator and live HUD toggle; hide additions during
  catch/nickname screens and avoid duplicate meters after HUD snapping.
- Update the embedded Battle Info HUD to 0.10.0. Other components are unchanged.

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
