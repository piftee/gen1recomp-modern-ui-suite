# Project Highlander

Open **Options → Modern UI Suite**. New gameplay options default off; choose
the features you want. **Enable All UI** affects the seven visual components.
The PokeMoves page has its own master switch and five individual switches.

| Page | Option | Behavior |
| --- | --- | --- |
| QoL | Running Shoes | Off, Hold B or Press B; running doubles walking speed. Bikes and surfing retain their speed. |
| QoL | Boosted EXP | Uses the traded EXP bonus without changing ownership or obedience. |
| QoL | Modern EXP Share | Every eligible participant gets full EXP; healthy nonparticipants get half. The rest of the party gets one combined EXP message, followed by level-ups and move-learning. Different bonuses display an EXP range. Eggs and fainted Pokémon get none. Native EXP.ALL/EXP.SHARE splitting is bypassed while enabled; items remain owned. |
| QoL | Decapitalize | Displays ordinary uppercase words in title case. Preserves common acronyms and text tokens; does not rename saved Pokémon. |
| QoL | Hidden Sparkles | Marks uncollected hidden items; markers disappear after collection. |
| QoL | Modern Stores / Area Names | Owned item counts in shops and two-second area banners. Crystal's native map signs keep priority. |
| QoL | Rematch Anyone | Talk to a defeated trainer or gym leader, then choose Yes. Party levels match your weakest non-egg Pokémon, including fainted members. Level evolutions and moves are recomputed for that level. Item/trade evolutions are retained. Badges and first-win story rewards are not repeated. |
| QoL | Infinite Safari | Gen 1: unlimited steps. Leaving or running out of Safari Balls still ends the visit. |
| QoL | Pikachu Sound | Yellow: choose the regular chip cry instead of the sampled voice. |
| Start Menu | Pokebox | Adds a box-and-ball icon opening Pokémon storage anywhere the START menu is available. |
| Start Menu | Colour / Remember | Auto, Red, Green, Blue, Yellow, Gold, Silver, Crystal or DMG. Store the colour per game edition or in the current save. |
| Battle HUD | Enemy HP Counter | Shows current/max HP inside a taller enemy bar in both generations. |
| Battle HUD | Low HP Alert | Native, reduced or off. |
| Move Colors | Colored Balls / Colored Moves | Gen 1: ball-specific colours and type-coloured move-animation tiles. Gen 2 retains its native coloured animations and omits these switches. |
| PokeMoves | Forgettable HMs | Allows HM replacement in the normal learning flow, in and out of battle. |
| PokeMoves | TMs Forever | Retains a TM after use; ordinary selling and tossing still work. |
| PokeMoves | Instant TMs/HMs | A handles Cut/Surf/Strength contextually. SELECT lists available Flash/Fly/Dig/Teleport actions. Native location restrictions remain. Gen 2 already supports contextual A. |
| PokeMoves | No Learn HMs | Requires the appropriate badge, an owned HM in the Bag and a compatible party Pokémon. Enables field use without occupying a move slot. Includes Gen 2 Waterfall and Whirlpool. |
| PokeMoves | Move Relearning | Adds RELEARN to a Pokémon's party actions. Includes moves its earlier forms could learn at its current level, including before stone evolution. |
| Controller Rumble | Enabled / Intensity | Short vibration pulses for battle and progression events on a supported controller. Off by default. |
| Full Control | Enabled / Edit Bindings | Uses the normal binding editor and existing saved bindings. Start and Back can be reassigned; fixed controller display shortcuts are disabled while enabled. |
| Full Control | Left Stick / Right Stick | Enable either or both movement sticks independently. Defaults are left on, right off. |

## Crystal Animated Sprites integration

With **Crystal Animated Sprites with Shiny Visuals** enabled, a new Red/Blue/Yellow
game offers Red or Leaf; Gold/Silver offers Gold or Kris. The suite sets that
provider's **Replace Sprites → All** and **Player Sprite** to the chosen hero,
covering portraits and the provider's overworld art. The provider supplies the
images; Highlander contains no replacement ROM or sprite pack.

**QoL → Force Crystal** defaults on but takes effect only after a hero choice.
Turn it off to restore the two provider settings that preceded the choice and
allow normal customization. Existing saves without a Highlander choice keep
their settings. Crystal retains its original gender selection.

## Compatibility and verification

Tested on Gen1Recomp **0.2.56 and 0.2.58** using isolated, muted, nonactivating macOS runs
with Red, Gold, Silver and Crystal generated data. Link battle EXP remains
native. Blue and Yellow were not run natively because their generated data
was not available; Yellow's cry fallback has an automated recursion check.
Controller vibration was tested against a simulated backend, without activating
a physical controller. Other sprite-provider versions and every individual
trainer script have not been exhaustively exercised.

Adapted from Waifu4Life's Modern UI Suite / Project Highlander contribution.
See [third-party notices](THIRD_PARTY_NOTICES.md).
