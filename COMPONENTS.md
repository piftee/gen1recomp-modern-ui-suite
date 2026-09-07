# Component provenance

Modern UI Suite 0.1.0 was initialized from the workspace working trees on
2026-09-03. These copies are now maintained as suite components rather than
loaded from the legacy directories.

| Component | Embedded version |
| --- | ---: |
| Modern Start Menu UI | 0.1.21 |
| Modern Party UI | 0.4.13 |
| Modern Bag UI | 0.6.3 |
| Modern PC UI | 0.6.4 |
| Modern Pokedex UI | 0.2.15 |
| Battle Info HUD | 0.10.2 |
| Typed Move Colors | 0.5.2 |
| Unlimited PP (independent QoL, default Off) | 0.1.0 |

All component code is MIT licensed. The Start Menu icon atlas also contains
CC0 artwork described in `THIRD_PARTY_NOTICES.md`.

## Architecture

- `core/components.lua` is the component inventory, version ledger, install
  order, required-file list, and settings namespace map.
- `core/scope.lua` gives imported code its original id and path while all
  loader registrations remain owned atomically by `modern_ui_suite`.
- `core/settings.lua` owns namespaced preferences, live master switches, and
  one-way migration from the legacy option buckets. Bulk UI actions exclude
  the independent default-off QoL component.
- `core/hub.lua` owns the only ordinary Options-menu entry.
- `core/ui_surfaces.lua` shares fixed aspect ratios, native-child backings
  and Gen 2 overlay composition across the four full-page menu components.
- `core/battle_portraits.lua` resolves optional large portraits;
  `core/menu_icons.lua` independently resolves small menu icons.
- `components/<legacy-id>/` contains each maintained feature implementation.

Hooks and ordinary lifecycle listeners consult their component switch at call time.
Screen records choose the component or the captured downstream/native factory
at construction time. The Bag storage patch is deliberately outside that
presentation gate so expanded saves remain usable. Battle Info HUD's provider
arbitration is likewise process-stable: it draws no suite UI while disabled,
but prevents Gender Mod and Crystal 251 from painting the same native cell.

## Updating a component

1. Make the change only in the suite's component directory.
2. Keep component-owned preferences behind `mod.options:get/set`; never read a
   legacy `loader.modOptions[legacyId]` bucket directly.
3. Load sibling files with `mod:load()` and assets through the scoped mod path.
4. Update the imported version and file/asset inventory in
   `core/components.lua` when the embedded snapshot changes.
5. Add optional dependencies and legacy conflicts to `manifest.json` when the
   integration surface changes.
6. Run the suite test, all seven frozen regression suites, Modkit validation,
   and the Gen 2 proof driver when a Gen 2 runtime is available.
7. Record player-visible behavior in `CHANGELOG.md` and rebuild the ZIP.

Do not wholesale synchronize standalone directories: their controllers and
Gen 1 presentation can intentionally differ. The 0.1.19 update also shares the reviewed Party controls, Start order editor,
and Bag preferences with their standalone versions. Bag additionally receives
the suite’s existing header money, description scrolling and Gen 2 pockets.
The 0.1.20 update shares the Gen 2 catch-storage routing helper with standalone
Modern PC UI 0.6.2, and the visible Gen 2 party-refusal messages with
standalone Modern Party UI 0.4.10. Unlimited PP has its own standalone.

The 0.1.22 embedded versions record suite-specific sorting, artwork, icon and
battle presentation changes. They do not indicate new standalone releases.
