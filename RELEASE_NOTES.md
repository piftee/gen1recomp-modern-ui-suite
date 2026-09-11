# Modern UI Suite 0.1.28

This release brings the changes since 0.1.23 to Gen 1 and Gen 2.

- Restore Gen 2's visible move-replacement list. Select which of the four moves
  to forget; cancellation and HM protection remain native. Remove the extra
  underline from the rename field.
- Use the actual Gen 1 layouts for the Gen 2 modern Bag and Pokédex: pocket
  icons, six-row item lists, action and quantity dialogs, portrait stacking,
  entry tabs, field notes, family grids and move pages.
- Fix Gen 2 item-PC pages being drawn twice at different sizes. Keep deposit
  quantity prompts and messages visible, and fit compact footer text.
- Align Gen 2 battle framing, controls and background masks. Add Fill, 16:9
  and 4:3 in Battle settings; retain framing for native/text-only moves and
  prevent duplicate scenes under transparent prompts.
- Fix Party navigation at 4:3. Add direct touch for START, Party and Bag,
  larger summary portraits, and Kanto Reforged's summary INFO integration.
- Render Pocket skin labels with crisp bitmap text, including MEDS. Improve
  Gen 4 portrait framing using the complete animation's artwork bounds.
- Keep small-icon selection in Party → Icon Source. Add Sprite Info to
  explain portrait providers, matching choices and artwork fallbacks.
- Track collected shiny species per save in Gen 1 and Gen 2. Show shiny
  markers and a D-pad Left/Right shiny-only Pokédex filter. Backfill from owned
  Pokémon and recorded shiny Hall of Fame entries; preserve history after release.
- Adapt selected Highlander contributions from Waifu4Life: optional shop owned
  counts, two-second area names and reduced/off low-HP alerts. Shop counts and
  area names default off; low-HP alerts retain the native default. Crystal's
  existing map signs keep priority. Highlander is not required.

Import `modern_ui_suite-0.1.28.zip` through the Mods manager, enable the suite,
apply and restart. Existing suite settings are retained. Disable standalone
versions of the bundled UI components before enabling the suite.

Validation: 99/99 automated test suites and 995 native checks passed with
muted, nonactivating test windows. The user also completed manual checks and
reported the release working. Native automation ran on Gen1Recomp 0.2.56 on
macOS; physical Android behavior was not verified by the automated runs.

Shiny history cannot recover previously released shinies without an owned or
historical record. The collection filter does not change portrait artwork.
