# 0.1.41

- Give Gen 2 Voxel battle dialogue, command labels and Yes/No prompts the same
  light lettering and thin dark outline as the battle stats. This fixes black
  text disappearing against the transparent dialogue box's scenery.
- Keep the native dialogue reveal, page advancement, A/B controls and chosen
  box fill. Preserve custom text alignment and leave move-card styling with
  its own renderer. Ordinary 2D battles and HUD-off rendering stay native.
- Share the scoped text renderer with the upper HUD, restoring every temporary
  drawing override even if a renderer raises an error.

Verified on official Gen1recomp 0.3.89 with Battle Art Voxel Gen2 2.1.0: 261
native dialogue checks across Gold, Silver and Crystal. GPU screenshot checks
verify light text and dark outlines in classic and wide battle layouts at
landscape and portrait sizes. Native text reveal, page advancement, FIGHT/B,
Yes/No input, all four box fills and custom alignment pass. All 1,839 headless
checks pass. Tests ran muted in nonactivating background windows.

Includes the EXP bar, move-category and duplicate-area-label fixes in 0.1.40.
No ROM data, fonts or provider artwork is bundled.
