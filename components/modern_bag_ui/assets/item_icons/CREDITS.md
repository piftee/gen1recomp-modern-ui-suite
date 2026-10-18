# Bag item artwork

This atlas deliberately uses original symbolic objects rather than official game
sprites. It maps every audited Gen I/II named item; aliases and type-coloured machine
discs are intentional. Unknown items added by other mods retain a category
fallback and are not claimed as covered.

## Openmon Item Icons Set 1

- Publisher / commissioning creator: **Screen Smith**. The creator page identifies
  the commissioned illustrator as a Fiverr artist, without a personal name.
- Source: https://screensmith.itch.io/item-icon-sprites-set-1-openmon
- Published terms: **CC0**, linked to Creative Commons' CC0 public-domain tool:
  https://creativecommons.org/publicdomain/zero/1.0/
- Original download: `OpenmonItemIcons.png`, 320 × 272 pixels.
- Original SHA-256: `7fc30fd75eb6691aedd6206504ae8c34e3bc7c49551ba788aac1bc0e41f7a8e9`.
- Retrieved and inspected 18 October 2026. The creator says the sprites were
  commissioned and they own full rights. No separate notice file or commission
  agreement accompanies the download. This record preserves the published claim;
  it does not independently guarantee ownership or clear third-party rights.
- Changes: selected generic object cells, transparent-bound cropping, nearest
  sampling to a 24px canvas, opaque pixel edges, a 32-level colour grid, selected
  hue variants, and original effect/strength labels. A separate 12px export is
  used in compact lists. Source coordinates and every derivative are recorded in
  the developer recipe/coverage files. Credit is voluntary under the published
  CC0 terms; it is preserved here for provenance.

## New source artwork and symbolic templates

The round capture-ball sheet, Lure Ball refinement, travel map, gold dentures
and optical disc were generated for this mod with OpenAI's built-in ImageGen
tool on 18 October 2026. The ball artwork used the inspected Openmon sheet as a
visual style reference. It is new AI-assisted fan artwork with recognizable
round capture-ball designs, not a copy of an imported official sprite sheet.
It is **not part of Openmon** and is not attributed to or licensed by Screen
Smith. The generation prompts, references and source files are preserved in
`artwork/item_icons` in this repository (source download). These outputs are
AI-generated; no claim of exclusive copyright or clearance of underlying
Pokémon design rights is made. Only the approved round-ball source is included; superseded capsule art is excluded.

The other new geometric pixel templates (including apricorns, gemstones, cards,
mail, devices, sprays, rope, surfboard, fossils, amber,
coins, toy, flute, tail, bows and star valuables), emblems and label glyphs were
created for this update in the deterministic atlas compiler. The generated catching balls have distinct cap colours/patterns, a separating
band and central latch. GS Ball has its own gold/silver story-item image; Light
Ball and Smoke Ball retain separate Openmon held-object artwork. Potions and other
families use explicit strength/effect variants. TM/HMs intentionally share 18 type-coloured disc variants selected from the
loaded game's taught move data, including Gen II's special Curse type. The visible
item names retain their numbers and actual moves taught. S.S. Tickets and Card Keys have generation-specific labels.

To the extent any copyright or related rights exist in these new artwork
contributions and can be dedicated, they are offered under **CC0 1.0 Universal**.
The included `CC0-1.0.txt` supplies the legal tool. This dedication does not apply
to any game names, underlying Pokémon intellectual property or third-party
rights. Code retains the mod's existing MIT license.

## Packaging

`items-24.png` and `items-12.png` contain 201 frames. `item_icon_map.lua` maps 276
named engine IDs to those frames. `THUNDER_STONE` / `THUNDERSTONE` are an explicit
spelling alias; 94 machine IDs dynamically use 18 move-type disc variants. All other named
base-game items have an explicit art recipe. No download, generator, API key or
network connection is needed while playing.
