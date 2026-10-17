# 0.1.39

- Restore the level-up stat confirmation in Gold, Silver and Crystal when
  Battle HUD is enabled. The native box was hidden by the widescreen battle
  renderer even though the battle still waited for its A/B confirmation.
- Display Attack, Defense, Special Attack, Special Defense and Speed using
  the game's own stat renderer and current values. Keep the box aligned with
  the centred battle scene at wide, compact, native and portrait sizes.
- Preserve native A/B dismissal, the HUD-off path and subsequent battle menus.

Verified on the official Gen1recomp 0.3.89 runtime: 570 native level-up checks
across Gold, Silver and Crystal, plus regressions for move learning, move
rearranging and the party EXP summary. All 1,743 headless checks pass against
the matching official engine source. The reported missing box was reproduced
before the fix and visually verified after it.

Includes the earlier fractional-DPI, HP display, low-HP alarm, translation
clipping and move-selection fixes. No ROM data, fonts or provider artwork
is bundled.
