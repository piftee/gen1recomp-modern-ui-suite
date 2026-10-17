# 0.1.42

- Give temporary Gen 2 battle popups solid backgrounds over Voxel scenery,
  including level-up stat confirmation, switching Yes/No prompts and the
  move-forget list. Keep the main dialogue/command transparency preference.
- Keep enemy HP numbers white and readable over the unfilled black bar,
  including at low and zero HP. Draw the meter inside the enemy HUD's own
  transform, preserve the native HP label and avoid a duplicate overlay.
- Give the native caught marker a white face and thin dark outline matching
  the battle text. Retain the game's caught/uncaught visibility rules.
- Preserve native popup input, the enemy-counter toggle, HUD-off rendering
  and ordinary 2D battles. Restore temporary drawing functions after errors.

Verified on official Gen1recomp 0.3.89 with Battle Art Voxel Gen2 2.1.0: 468
native assertions across Gold, Silver and Crystal. GPU checks verify solid
popup pixels and white HP/caught pixels at full, 40%, 10% and zero health in
classic/wide layouts at landscape/portrait sizes. Native A/B popup controls
and uncaught-marker visibility pass. The installed custom Suite candidate
passes another 156 checks. All 1,864 headless checks and eight distribution
checks pass. Tests ran muted in nonactivating background windows.

Includes the dialogue, EXP and area-label improvements in 0.1.40–0.1.41.
No ROM data, fonts or provider artwork is bundled.
