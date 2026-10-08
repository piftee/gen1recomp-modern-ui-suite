# 0.1.38

- Fix fractional-DPI rendering in the Gen 2 Bag and Pokédex. Their internal
  buffers now retain one texel per cartridge pixel, preventing uneven text
  strokes and distorted glyphs on high-density mobile displays.
- Apply the same pixel sizing rule to Gen 1/Gen 2 Battle HUD buffers and
  translation-font measurements.
- Retain the HP values, low-HP alarm controls, translation clipping and move
  rearranging fixes from 0.1.35–0.1.37.

Adds ROM-free regressions for fractional display density, resized Pokédex
buffers and compact/wide/portrait Bag layouts. All 1,726 headless checks
pass against the official Gen1recomp 0.3.62 source. The new DPI checks fail
against 0.1.37 and pass with this fix. Native visual confirmation was unavailable
because the test workstation was locked.

No ROM data, translation fonts or provider artwork is included.
