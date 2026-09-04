# Modern UI Suite

**Classic Pokémon, made clearer at a glance.**

Modern UI Suite refreshes the menus and information screens throughout the
game while keeping the character of the original handheld adventures. It uses
the familiar pixel type, Pokémon sprites, palettes, sounds, and controls, then
gives them more room to breathe on modern displays. The result feels less like
a replacement interface and more like the UI the games might have grown into.

The layouts respond to the space available instead of simply stretching the
Game Boy screen. They can stay compact at the original 160×144 aspect ratio,
spread out across a desktop window, or reorganize for a tall phone-shaped
view. The mod changes presentation and convenience—not battles, progression,
or the rules of the game.

**[Download the latest installable release](https://github.com/piftee/gen1recomp-modern-ui-suite/releases/latest)**

## What it changes

- **A quicker START menu** — a compact, paged icon launcher keeps more of the
  overworld visible and puts important context within easy reach. Gen 2 games
  receive their proper PACK and POKéGEAR actions.
- **A more expressive party and summary view** — responsive, type-tinted cards
  make HP, experience, status, stats, and moves easier to scan without losing
  the original game's visual language.
- **A genuinely useful Bag and Item PC** — sensible pockets, item descriptions,
  money and capacity readouts, two visual skins, and layouts suited to both
  wide and narrow screens. Press Start to sort the Bag by pocket category or
  item name in either direction. Expanded storage supports 255 unique entries
  and stacks of up to 999 items.
- **Direct Pokémon storage management** — see the party and current Box
  together, inspect a Pokémon before moving it, and pick up, place, reorder,
  or swap Pokémon in one workspace.
- **A Pokédex built for browsing** — caught and seen progress, filters, artwork,
  and dedicated information, stats, evolution-family, and move views make the
  Pokédex feel like a research tool rather than a long list.
- **More informative battles** — readable colored HP bars, experience progress,
  status, level, gender, and caught indicators add useful information while
  preserving the battlefield and the native battle flow. On Gen 2, an active
  Stadium 2 battle keeps ownership of its complete 3D scene.
- **Type-aware move displays** — move cards and text use their type colors
  consistently in battle, summaries, move learning, move forgetting, Mimic,
  and PP selection, with clearer PP and effectiveness cues where relevant.

Modern UI Suite supports Red, Blue, and Yellow, plus Gold, Silver, and Crystal
on Gen 2-capable Gen1Recomp builds. Every major feature has its own switch, so
you can use the complete visual refresh or keep only the parts that suit your
game. Detailed appearance and behavior options remain independent too.

## Install

Disable the seven standalone versions before enabling this suite. The suite
declares hard conflicts so duplicate screen owners cannot silently overwrite
one another. Import the packaged ZIP in the Mods manager, enable **Modern UI
Suite**, then apply and restart.

Existing standalone presentation settings are copied into the suite the first
time it loads. Values already saved for the suite take precedence. The old
settings are left untouched.

## Settings

Open **Options → Modern UI Suite**. The hub provides **Enable All**, **Disable
All UI**, and a page for each component. Left or Right on a component in the
hub toggles it directly; A opens its detailed settings.

Hooks such as battle overlays respond immediately. Screen replacements switch
the next time the affected screen is opened; an already-open menu is never
rebuilt underneath the player.

Disabling Modern Bag UI restores the native or compatible Bag presentation,
but the expanded 255-slot/x999 storage support remains active. This is a save
safety rule: lowering capacity while an expanded inventory exists could strand
items. Cartridge `.sav` export still has the original cartridge limits.

All seven components are enabled by default. **Disable All UI** preserves each
component's detailed preferences so they return unchanged when re-enabled.

## Compatibility API

The suite exports its component APIs beneath one mod identity:

```lua
local suite = mod.find("modern_ui_suite")
local dex = suite and suite.exports.components.modern_pokedex_ui
local dexExports = dex and dex.exports
```

Each component entry contains `version`, `enabled()`, and `exports`. The suite
also provides `suite.exports.isEnabled(legacyModId)`. Because the mod loader
does not support manifest aliases, `mod.find("modern_pokedex_ui")` does not
resolve to an embedded component; integrations should use the suite path above.

## Development

The component sources under `components/` are the authoritative suite copies.
The former standalone repositories are frozen legacy releases and are not read
at runtime or during packaging.

```sh
luajit mods/modern_ui_suite/tests/modern_ui_suite_test.lua
python3 tools/modkit.py validate mods/modern_ui_suite --base auto
python3 tools/modkit.py lint mods/modern_ui_suite
python3 tools/modkit.py pack mods/modern_ui_suite \
  -o build/Modern-UI-Suite-v0.1.8.zip
```

The live settings sweep opens every component page, drives all 31 persisted
rows through all 77 advertised values, and captures each state:

```sh
SHOT_DIR=/tmp/modern-ui-suite-options \
POKEPORT_DRIVER=mods/modern_ui_suite/tests/options_preview_driver.lua \
POKEPORT_IDENTITY=modern-ui-suite-options POKEPORT_VERSION=red love .
```

On a Gen 2-capable engine checkout with a generated Gold, Silver, or Crystal
cache, the suite-specific proof driver captures the full native screen matrix:

```sh
SHOT_DIR=/tmp/modern-ui-suite-gen2 \
POKEPORT_DRIVER=mods/modern_ui_suite/tests/preview_driver.lua \
POKEPORT_IDENTITY=modern-ui-suite-gen2 love .
```

See `COMPONENTS.md` for the imported snapshot versions and
`THIRD_PARTY_NOTICES.md` for asset attribution.
