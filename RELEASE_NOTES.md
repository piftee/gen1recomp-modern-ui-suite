# Modern UI Suite 0.1.22

Category sorting now orders items within each Bag pocket, and new SPRITE and
ICONS controls let you choose large portraits and small menu icons separately.
This release includes the tested menu and battle fixes developed after 0.1.21.

## What's changed

- **Bag sorting:** Category Asc/Desc arranges Balls, healing items, status
  cures and other item families in a consistent order, with numeric TM/HM
  sorting. It keeps your current pocket, selected item and quantities in both
  generations, including after Gen 2 rebuilds the TM/HM list.
- **Large portraits:** choose Battle Art, Crystal or Default under
  **Options → Modern UI Suite → SPRITE**. Summary, Pokédex and PC portraits
  retain the selected artwork's animation, shiny variants and colours.
  Battle Art follows its front-generation and Static/Animated choices.
- **Small icons:** **ICONS** independently selects Auto, Original, Menu Pack
  or Followers. This shares Party's Icon Source preference and uses actual
  icon sheets rather than shrinking battle portraits.
- **Battle Bag:** remove grey HUD patches from the Gen 1 Bag and remember
  its pocket, item and scroll position between visits, including item use.
- **Move displays:** Gen 2 Text Only keeps the native move list, cursor,
  TYPE/PP box and move-reordering controls with legible type colours. Gen 1
  move-learning colours follow the engine's actual text rows.
- **Indicators:** improve Gen 2 party selection on pale cards, recognize
  translated built-in START actions, and fix the caught-species marker
  displaying a six-slot row with sprite companions in Gen 1 battles.

The Crystal colour and animation fixes from 0.1.21 are retained. Some Gen 4
animations still look smaller because their source frames contain additional
transparent padding; this release does not crop that artwork.

## Installation

Import `modern_ui_suite-0.1.22.zip` in place of the previous suite, then apply
and restart. Keep overlapping standalone UI mods disabled. Battle Art, Crystal
Animated Sprites and icon packs are optional companions installed separately;
their artwork is not bundled. Missing providers retain the existing sprite
handling. Saved suite settings are preserved.

Validated with the suite's automated checks and native Gen1Recomp 0.2.56
tests. The latest Red/Crystal Gen 4 verification passed 1,361 checks in muted,
nonactivating test profiles, including normal/shiny frames, portraits, icon
choices and wide/portrait layouts.
