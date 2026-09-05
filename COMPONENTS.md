# Component provenance

Modern UI Suite 0.1.0 was initialized from the workspace working trees on
2026-09-03. These copies are now maintained as suite components rather than
loaded from the legacy directories.

| Component | Imported version |
| --- | ---: |
| Modern Start Menu UI | 0.1.19 |
| Modern Party UI | 0.4.9 |
| Modern Bag UI | 0.6.1 |
| Modern PC UI | 0.6.1 |
| Modern Pokedex UI | 0.2.13 |
| Battle Info HUD | 0.10.1 |
| Typed Move Colors | 0.5.1 |
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
Gen 1 presentation can intentionally differ. This corrective build explicitly
shares only the reviewed PC/Pokedex sprite helpers and Typed Gen 2 fixes with
the corresponding standalone sources. Unlimited PP has its own standalone.
