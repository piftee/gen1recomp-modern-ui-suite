# Modern UI Suite gallery

Full-window captures from Gen1Recomp 0.2.56, taken in isolated Red and Crystal
test profiles. These are native renders, with no image edits. Click an image
to inspect its full size. The fixtures contain sample parties and inventory;
they do not show a user's save. Pokédex captures use suite 0.1.26;
Bag, rename and move-replacement captures use 0.1.27; other captures show
the 0.1.24 improvements. The September report captures below show the
0.1.28 changes (captured before the version-number bump).

[Install and configure the suite](README.md#install) · [Touch controls](README.md#direct-touch)

## START

The launcher uses the right side of the landscape window. Position, colour,
clock, icons and entry order are configurable under **Start Menu**.

![START launcher](screenshots/feedback-0.1.24/start.png)

## Party and summary

**Party → Aspect Ratio → 4:3** produces this two-column roster. All four
directions follow the visible grid, including item targeting and replacement
pickers. On a phone-shaped window, a chosen fixed ratio remains centered.

![Crystal Party at 4:3](screenshots/feedback-0.1.24/party.png)

![Crystal Party in a portrait window](screenshots/feedback-0.1.24/party-portrait.png)

Stats portraits have more room. The number and type labels sit above the
stats column; OT and trainer ID remain beneath the picture.

![Red summary at 16:9](screenshots/feedback-0.1.24/summary-red.png)

![Crystal summary at 4:3](screenshots/feedback-0.1.24/summary-crystal.png)

With **Kanto Reforged 1.7.3** enabled, the additional INFO page shows the
provider's gender, held item, ability and complete description. Long text
scrolls automatically while the ability name stays visible.

![Kanto Reforged INFO page](screenshots/feedback-0.1.24/kanto-info.png)

## Bag

**Bag → Skin → Modern** offers pocket tabs, a large list and descriptions.
Tap a pocket to switch. Tap an item once to select it and again to open its
native actions. Action/quantity/confirmation dialogs use the normal controls.

Gen 1 and Gen 2 share the same pocket icons, colour ramps, list frames,
selection rows and detail cards. Portrait windows stack the details below the
list. Gen 2 retains its native items, four physical pockets and item actions.

![Modern Bag in Gen 2](screenshots/bag-0.1.27/bag.png)

![Gen 1 reference](screenshots/bag-0.1.27/gen1-bag.png)

![Medicine pocket in Gen 2](screenshots/bag-0.1.27/medicine.png)

![Portrait Bag](screenshots/bag-0.1.27/portrait.png)

![Native item actions in the Modern Bag](screenshots/bag-0.1.27/actions.png)

![Quantity anchored to the selected item](screenshots/bag-0.1.27/quantity.png)

## Gen 2 rename and move learning

The rename field has one line, with its current slot highlighted. When
learning a fifth move, all four existing moves and the selection cursor are
visible; A replaces the selected slot and B opens the native cancellation flow.

![Single-line rename field](screenshots/bag-0.1.27/rename.png)

![Choose a move to replace in battle](screenshots/bag-0.1.27/move-replacement.png)

![Move replacement outside battle](screenshots/bag-0.1.27/field-move-replacement.png)

## PC

Party and Box share a workspace. Use the normal controls to move, inspect,
reorder and manage Pokémon; START opens additional actions.

![PC workspace](screenshots/feedback-0.1.24/pc.png)

## Pokédex

**0.1.26** uses the same presentation code in both generations. The index,
actions dialog, top tabs, INFO cards, notes, stats, family grid and move pages
share their geometry and styling. Gen 2 retains its native artwork and data.
These Gen 2 captures use **Battle Art Gen 2 2.1.0**, animated Gen 4 front
sprites, and the suite's **SPRITE → Battle Art** setting.

![Gen 2 Pokédex index](screenshots/pokedex-0.1.26/index.png)

![Gen 2 INFO](screenshots/pokedex-0.1.26/info.png)

![Gen 2 FAMILY](screenshots/pokedex-0.1.26/family.png)

From the index, **A** opens actions, **SELECT** opens search, and **START**
opens Gen 2's ordering/Unown tools. Inside an entry, **Left/Right** changes
tabs; **Up/Down** scrolls notes or selects a relative/move. **A** plays a cry
or opens the selection, and **B** returns. AREA and PRNT remain in the actions.

Both Gen 2 description pages appear in the scrollable INFO notes. Compact
layouts put the sprite and identity card above full-width notes or stats.
The six Gen 2 base stats fit without clipping the last row.

![Gen 2 compact INFO](screenshots/pokedex-0.1.26/info-compact.png)

![Gen 2 compact STATS](screenshots/pokedex-0.1.26/stats-compact.png)

Complete families use the same grid as Gen 1, including branching families.
Unknown forms remain inaccessible; known relatives retain Gen 2's evolution
conditions, including time of day, held items and stat comparisons.

![Gen 2 Eevee family](screenshots/pokedex-0.1.26/family-eevee.png)

The Gen 1 reference uses its native Red artwork and prose:

![Gen 1 INFO reference](screenshots/pokedex-0.1.26/gen1-info.png)

![Gen 1 FAMILY reference](screenshots/pokedex-0.1.26/gen1-family.png)

## Battle HUD and move colours

The HUD preserves the native battle scene. **Move Colors** controls the move
cards, type colours and the Power/PP strip. These captures also have Kanto
Reforged enabled.

![Battle HUD](screenshots/feedback-0.1.24/battle-hud.png)

![Type-coloured move cards](screenshots/feedback-0.1.24/move-colors.png)

## Optional Gen 4 portraits

These require the separate **Battle Art** provider. Set the suite's
**Menu Sprites → Battle Art** and the provider's front animation generation
to **Gen 4**. Transparent margins are trimmed using one rectangle shared by
every animation frame, retaining motion and white details.

![Gen 4 Wartortle](screenshots/feedback-0.1.24/gen4-wartortle.png)

![Gen 4 Blastoise](screenshots/feedback-0.1.24/gen4-blastoise.png)

Android and Steam Deck hardware have not been tested directly. Portrait
captures and native pointer tests were performed on macOS with audio muted
from startup and windows prevented from taking focus.

## September Discord reports — 0.1.28

The Gen 2 item PC draws once and keeps deposit quantities visible.

![Item PC withdrawal](screenshots/reports-0.1.28/item-pc.png)

![Deposit quantity prompt](screenshots/reports-0.1.28/deposit-quantity.png)

Battle framing and the surrounding world share one viewport.

![Crystal battle at 4:3](screenshots/reports-0.1.28/battle-4x3.png)

Pocket labels use the bitmap font; L/R on the Pokédex index toggles shiny history.

![Readable MEDS label](screenshots/reports-0.1.28/pocket-meds.png)

![Collected shiny species](screenshots/reports-0.1.28/shiny-dex.png)

Optional shop counts update after a purchase. Area names expire after two
visible seconds and defer to Crystal's native signs.

![Owned count after purchase](screenshots/reports-0.1.28/shop-count.png)

![Area name banner](screenshots/reports-0.1.28/area-name.png)
