# Modern UI Suite 0.1.20

Gen 2 party refusals are now visible. Selecting a fainted Pokémon previously
opened an invisible message that held navigation until A or B was pressed.
The modern screen now displays the message with **A/B CONTINUE**. Small party
grids also let Up/Down escape a column containing only one Pokémon.

When a Gen 2 party and current box are full, ordinary wild-ball attempts select
the next box with room, skipping full boxes and wrapping from Box 14 to Box 1.
That box stays active for subsequent catches and PC visits, including after a
failed throw. A free party slot still takes priority. If all fourteen boxes
are full, the game refuses before consuming a ball or a turn.

Native capture handling retains ownership, caught data, nickname prompts,
Pokédex updates, held items, HP/PP restoration and specialty-ball effects.
Trainer battles, the Bug-Catching Contest and the tutorial keep their original
behavior. Automatic box selection follows the Modern PC UI component switch.

## Party, Start and Bag controls

- **Party:** Select picks up a slot, Select on another swaps, and B cancels
  the hold. Footer hints show pickup/drop controls. Gen 2 Mail follows its owner.
- **Start:** START ICON ORDER lists every live native and mod-added action.
  Open Start once to discover the set; Up/Down highlights and Left/Right moves
  the action. The saved order applies when Start reopens.
- **Bag:** add Hide All Items, Open On, and one Bag Pocket Order editor.
  Select picks up/swaps tabs; B cancels the hold. Available tabs follow the
  skin and compatible inventory provider.
- Category sorting reveals its grouped result in All Items when that tab is
  enabled. The selected All Items backpack icon now contrasts with its tab.

## Install

Import **modern_ui_suite-0.1.20.zip** through the Mods manager, enable Modern UI
Suite, then apply and restart. Disable overlapping standalone components.
Settings are under **Options → Modern UI Suite**.

## Validation

Native tests with Gen1Recomp 0.2.56 cover Gen 2 catch overflow on Gold, Silver
and Crystal, including original-failure reproduction, skipped boxes, wraparound,
last-slot catches, full storage, failed throws, specialty balls, native
save/load and process restart. The party refusal was reproduced with the
installed Silver code; fixed compact and wide messages, A/B acknowledgement,
and successful replacement were verified in Silver and Crystal.

The Party/Start/Bag checklist also passes in native Red and Crystal sessions,
including Gen 2 Mail ownership and preference persistence. Suite, component and
focused regression checks pass. Automated native runs used isolated saves,
silent audio and background windows; physical phone/controller input was not
part of this validation.
