# Modern UI Suite 0.1.30 — Expanded Gen 2 Boxes

The PC workspace now supports [Expanded Gen 2 Boxes 0.2.0](https://github.com/Debatesmith/ExpandedGen2Boxes/releases/tag/v0.2)
in Gold, Silver and Crystal: 50 boxes holding 50 Pokémon each.

- Scroll down through all ten rows while the six-member party stays below the grid.
  The scrollbar and visible slot range show your position; icons keep their normal size.
- Open SELECT → A to browse all 50 boxes in a scrolling picker.
- Pick up, place, quick-transfer and group-swap Pokémon using the expanded capacity,
  including whole-party swaps from a full 50-Pokémon box.
- Keep compact, 4:3, widescreen and portrait storage layouts readable. Narrow screens
  use a full-width box grid; wider screens retain text details without a large portrait.
- Preserve native Mail and party safeguards, catch overflow and save persistence.

Import `modern_ui_suite-0.1.30.zip`, enable the suite and Expanded Gen 2 Boxes,
and restart. The expansion remains a separate mod; the suite does not increase
storage capacity on its own. Ordinary 20-slot storage is still supported.

Validation includes native Gold/Silver/Crystal tests on Gen1Recomp 0.2.58,
separate-process save reloads, 2,500-slot storage boundaries, rendered icon bounds,
and headless capacity/navigation regressions. All native tests use private saves,
muted audio from startup and windows prevented from taking focus.
