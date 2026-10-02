# 0.1.35

- Fix overlapping summary sprites with Battle Art + G9 when the modern party
  menu is disabled. The original picture no longer appears beneath the G9
  animation. Provider toggles and missing-art fallbacks remain intact.
- Add move rearranging on Gen 1's modern summary Moves page. Press Select to
  pick a move, use arrows to choose the destination, then A to swap. B or
  Select cancels. PP, PP Ups and companion metadata stay with the move.
- Verify Gen 1 and Gen 2 summary sprites and move controls on Gen1recomp 0.3.47.
  Includes the G9 modern summary and Japanese compatibility fixes from 0.1.34.

For G9 artwork with Battle Art, select MODDED for Battle Art's DUPLICATE FIX
and INTERFACE SPRITES. Use BATTLE ART or DEFAULT as the suite's menu sprite
source and enable G9's master switch and SUMMARY SPRITES. Provider artwork
must be installed separately.

The new launcher's Kanto Ribbons dependency note describes optional load
ordering when that mod is enabled; it is not a requirement to install it.
Keep the suite after Kanto Ribbons so its summary pages compose correctly.

Automated native tests used muted, nonactivating disposable profiles. Release
assets exclude game artwork, ROM data, test captures and translation fonts.
