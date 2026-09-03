# Modern UI Suite

Modern UI Suite combines seven interface mods into one maintained package for
Gen 1 and Gen 2: Modern Start Menu, Modern Party UI, Modern Bag UI, Modern PC
UI, Modern Pokedex UI, Battle Info HUD, and Typed Move Colors.

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
  -o build/Modern-UI-Suite-v0.1.0.zip
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
