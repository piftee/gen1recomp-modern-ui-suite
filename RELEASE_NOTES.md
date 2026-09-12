# Modern UI Suite 0.1.31 — QoL, Highlander and expanded storage

This release brings the complete QoL update to GitHub, alongside the expanded
PC storage support introduced in 0.1.30. The 0.1.30 GitHub ZIP contained the PC
changes; the Highlander and EXP improvements from the local previews are now
included in the published package.

## Gameplay and progression

- **Running Shoes:** walk at twice the normal speed by holding or toggling B.
  Bike and surfing speeds stay native.
- **Boosted EXP:** apply the traded EXP bonus without changing Pokémon ownership
  or obedience.
- **Modern EXP Share:** each eligible fighter receives full EXP, while healthy
  nonparticipants receive half. Eggs and fainted Pokémon receive none. The rest
  of the party gets one combined EXP message, followed by native level-ups,
  stats and move-learning. Different individual bonuses display an EXP range.
- **Trainer and gym rematches:** challenge defeated trainers again, with their
  teams scaled to your weakest non-Egg party member. Levels, level evolutions
  and moves are recalculated; badges and first-win story rewards are not repeated.
- **Hidden Sparkles and Decapitalize:** mark uncollected hidden items and optionally
  show ordinary uppercase words in title case without renaming saved Pokémon.
- **Gen 1 extras:** unlimited Safari steps and, in Yellow, an option to use
  Pikachu's regular chip cry.

## PokeMoves

- Forget HMs in the normal move-learning flow and optionally reuse TMs.
- Use contextual field shortcuts for Cut, Surf and Strength, with SELECT shortcuts
  for available Flash, Fly, Dig and Teleport actions.
- Use field HMs without occupying a move slot when you have the badge, own the HM
  and have a compatible party Pokémon. Gen 2 includes Waterfall and Whirlpool.
- Relearn eligible moves, including moves an earlier evolution could learn at
  the Pokémon's current level.

## Menus, controls and presentation

- **Pokebox:** open Pokémon storage from the START menu wherever START is available.
- Choose cartridge-themed START colours and remember them per game or per save.
- Show the enemy's current/max HP; Gen 1 also gains optional ball-specific colours
  and type-coloured move animations.
- **Full Control:** reassign Start/Back using the native binding editor and enable
  the left and right movement sticks independently.
- **Controller Rumble:** optional short vibration pulses with adjustable intensity.
- With **Crystal Animated Sprites** installed, new games can choose Red/Leaf in
  Gen 1 or Gold/Kris in Gold/Silver. Crystal retains its native gender selection.
- Improve Gen 2 party readability on narrow screens, including level 100 labels.
- Existing shop owned-item counts, area-name banners and low-HP alert options
  remain available.

## Expanded Gen 2 Boxes

Support for [Expanded Gen 2 Boxes 0.2.0](https://github.com/Debatesmith/ExpandedGen2Boxes/releases/tag/v0.2)
is retained: 50 boxes of 50 Pokémon, scrolling box contents and box picker,
visible scroll position, and correct limits for transfers and group swaps.
The six-member party stays below the box grid at every aspect ratio.
Use **Down** to scroll through a box and **SELECT → A** to choose a box.
The expansion remains a separate mod and must be enabled for expanded capacity.

## Setup

Import `modern_ui_suite-0.1.31.zip`, enable the suite, apply and restart. Open
**Options → Modern UI Suite** to choose your settings. New gameplay features
default off; PokeMoves has its own master switch and individual options. Rumble
and Full Control are opt-in. **Enable All UI** controls the visual components.

**Force Crystal** defaults on but only takes effect after a hero choice. Turning
it off restores the provider settings saved before that choice. Existing saves
without a choice keep their provider settings.

Existing suite settings are retained. Disable standalone versions of the bundled
components. The separate Project Highlander fork is not required. Credit to
**Waifu4Life** for the Highlander contribution; see the
[feature guide](https://github.com/piftee/gen1recomp-modern-ui-suite/blob/v0.1.31/HIGHLANDER.md)
for individual options and generation differences.

Validation: **109/109 automated suites** and **2,008 native checks**
on Gen1Recomp 0.2.58 passed across Red, Gold, Silver and Crystal. Native runs
used private saves, muted audio from startup and windows prevented from taking focus.
Physical controller vibration and Android hardware were not exercised.
