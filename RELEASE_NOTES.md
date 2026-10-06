# 0.1.37

- Restore numeric HP values on Gold, Silver and Crystal party cards. Verify
  values, percentages, status labels and level 100 at compact and wide sizes.
- Apply LOW HP BEEP reductions/muting even when the visual Battle HUD is off.
  Verify the native Crystal alarm loop, its initial alert budget and rearming.
- Fix taller translation-font clipping in the shared Bag and Pokédex layouts.
  Measure the active glyph height, retain full scrolling-description strokes,
  and give headers, footers and wrapped text enough space.
- Verify on Gen1recomp 0.3.55, with Japanese Fusion Pixel 8px/10px and the
  translation generator's fallback Plain Pixel font. Recheck move rearranging.

Includes the move rearranging and Battle Art/G9 compatibility fixes from
0.1.35–0.1.36. Translation fonts and provider artwork remain separate installs.
