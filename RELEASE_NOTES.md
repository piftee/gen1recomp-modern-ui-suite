# Modern UI Suite 0.1.15 — storage, Gen 2 parity and battle fixes

This release includes all changes since public **0.1.12**, including the work
validated in local 0.1.13 and 0.1.14 test builds.

## Installation

Download `modern_ui_suite-0.1.15.zip`, then choose **MODS → Import mod .zip**,
enable Modern UI Suite and apply/restart. Disable overlapping standalone Start,
Party, Bag, PC, Pokédex, Battle HUD, Typed Move Colors and Unlimited PP mods.
Unlimited PP is **Off by default** and remains independent of bulk UI switches.

## Changes and fixes


### Pokémon PC and storage

- **Direct Gen 2 workspace:** Bill's/Someone's PC now opens the combined party
  and box grid. The published release only themed the original operation
  chooser. Gold, Silver and Crystal now receive the pickup, drop, swap,
  reorder and cross-box workflow already familiar from Gen 1, across all
  fourteen native boxes.
- **Native Item and Mail actions:** START offers the appropriate held-item or
  Mail menu for a party Pokémon, plus Mailbox access. These are native actions,
  not replacement letter data. Letters follow their owners when the party is
  reordered; unsafe transfers of Mail carriers are refused.
- **Safer state changes:** transfer, release and group operations protect box
  capacity, Eggs and the last usable party Pokémon. Closing changed Gen 2
  storage saves safely and supports retry after a failed save.
- **Group management in Gen 1 and Gen 2:** START → MULTIPLE SELECTIONS marks the
  focused Pokémon; A marks more on that side, including across boxes. An
  empty/opposite-side destination places or swaps the ordered group. Selecting
  six boxed Pokémon enables START → SWAP WHOLE PARTY. B cancels.
- **Navigation:** party rows wrap at the actual party ends. The new PC → BOX
  EXCLUSIVE setting defaults to **Off** and limits automatic box navigation
  when enabled; deliberate SELECT box browsing remains available. The flat
  Mods settings label is shortened to BOX ONLY.

### Bag

- **Gen 2 Modern-skin parity:** six browse views—All, Items, Medicine, Balls,
  TMs/HMs and Key Items—replace the four-view presentation. These filter the
  existing four native stores; they do not move items between stores or change
  ownership/action rules.
- **Gen 2 START sorting:** category ascending/descending and names A–Z/Z–A.
  Sorting retains quantities and the selected item; name-sorted TMs/HMs stay
  in the requested order. Manual reorder and per-view cursor memory remain.
  The Pocket skin retains its four-pocket look and also supports sorting.
- **More room for Gen 2 items:** the Modern skin uses a full-width bottom
  description area, leaving the tabs and item list the whole panel width.
  Tab labels shorten only when their actual available space requires it.
- **Money headers in both generations:** Modern and Pocket skins show exact
  money, with capacity/control spacing adapted to the available width.
- **Complete descriptions:** text that fits remains still; overflow scrolls
  horizontally with pauses at the ends. Scrolling resets on a new selection,
  changed description or changed layout. Confirmation/action/sort overlays
  stay static and their compact text stays inside the footer.

Gen 1 already had six Bag views and START sorting in the published 0.1.12
payload. Expanded 255-slot/x999 item storage also already existed; neither is
being announced as newly added to Gen 1.

### Pokédex

- **Gen 2 MOVE action:** browse level-up moves, compatible numbered TMs/HMs,
  and Crystal tutor entries when provided by the active game data.
- **Move details:** A opens source/level or machine number, type, power,
  accuracy, PP, Gen 2 physical/special/status class, applicable priority and
  ROM/mod-provided description. B returns to the list, then to the entry.
- **Compact and wide layouts:** browsing/navigation works in both; the
  entry action bar abbreviates labels when necessary to keep them readable.
- **Existing EVO remains alongside MOVE.** Evolution-family browsing and its
  conditions were already in the published Gen 2 component and are not a new
  feature in this comparison. Gen 1 Pokédex controllers are unchanged.

### Battle layout, appearance and controls

- **Normal Gen 2 widescreen layout:** a full-width 2×2 move grid now sits above
  a slim Power/PP strip. The public release used the narrow four-row/side-info
  layout at common 256-pixel logical widths. The very narrow intermediate
  layout still falls back to a readable list; side details require room.
- **Held-move visibility:** SELECT pickup leaves a hollow marker and amber
  border on the source move while ordinary focus follows the destination.
  The Power/PP strip keeps its normal border. Native placement, cancellation,
  move identity, PP Ups and Disable checks remain authoritative.
- **New Move Colors options:** TEXT POSITION (Left/Center/Right; default
  **Left**), BOX COLOR (Default/Gray/White/Black; default **Default**), and INFO
  WINDOWS (Original/Left/Right; default **Original**). Flat Mods labels are
  TEXT ALIGN and INFO SIDE. Alignment uses the complete native line so text
  does not drift as it types.
- Neutral BOX COLOR overrides apply at full opacity only. Normal Gen 2 16:9
  keeps its bottom information strip; explicit side placement requires
  sufficient logical width. Gen 1 command/dialogue appearance applies to the
  Typed Wide presenter. Native GAME, Text Only and independently owned
  third-party panels retain their layout/ownership rather than being forced
  into another presentation.
- **Gen 2 dialogue repair:** caught messages and long words wrap within their
  native pages. Yes/No choices, selected answer and typing/timing gates are
  visible for nickname and related battle prompts; A/B callbacks and native
  page progression remain intact.
- **Red battle repair:** native GAME move colouring no longer covers FIGHT or
  PKMN command labels. Move colours survive the native palette pass correctly.
  The player HUD stays below the opponent picture; the engine-wide EXP footer
  has its own border row instead of crossing the text.
- **Independent switching:** when Gen 2 Move Colors is Off but Battle HUD is
  On, the native move menu remains visible instead of leaving an empty bed.

### PC/Pokédex sprite transparency

- A complete review covered **831 Gen 2 pictures**, including Unown variants,
  and **117 menu-icon sheets**. Conservative, exact-image corrections now
  remove confirmed portrait background gaps while retaining genuine white
  details and uncertain regions. Unknown or changed replacement sprites are
  left untouched.
- **Silver and Crystal Goldeen's missing white fin is restored**, using the
  original indexed artwork to corroborate the native transparency loss.
  Gold's Goldeen is unchanged. No replacement colours or invented black
  outline are added.
- The broader masks used in the intermediate local 0.1.14 test were withdrawn
  where uncertain. The final review retains 79 conservative cut rules plus one
  exact-source native-alpha restoration rule: 128 corrected variants across
  28 species; 703 pictures remain entirely native. An earlier test agreeing
  with a mask was not, by itself, proof that its white pixels were background.
- These corrections affect PC/Pokédex portraits only—not global battle art,
  source caches, authored animation frames or every sprite supplied by mods.

### Start menu labels

- THEME/PHONE THEME becomes COLOUR/PHONE COLOUR.
- MAP is labelled **AUTO** (follow the area's palette); DMG is labelled
  **GREEN** (fixed classic green). Red/Blue choices, actual palettes, saved
  values and defaults are unchanged. This is a naming clarification, not a
  new palette system or new position layout.

### Independent Unlimited PP

- **Options → Modern UI Suite → QOL → UNLIMITED PP**, one **On/Off** toggle,
  **Off by default**. It is separate from Party, Move Colors and Battle HUD.
- On allows eligible player moves to be selected and used at zero PP without
  consuming or permanently refilling their real stored PP. The battle readout
  uses the approved hand-pixelled **∞**; ordinary out-of-battle summaries retain
  the real stored values.
- Opponent PP handling remains native; Disable and other native restrictions
  are retained. Gen 2 Encore/disobedience/Spite paths are covered. Link battles
  deliberately keep native PP rules. Off immediately restores normal rules
  using the unchanged stored PP.
- Works with Party Off, Move Colors Off, both Off or all seven UI components
  Off. The renamed **ENABLE ALL UI** and **DISABLE ALL UI** actions leave this
  gameplay option alone. Its custom Gen 2 menu toggle persists correctly.
- Do not enable standalone Unlimited PP alongside the suite: the suite now declares that conflict in addition to
  the seven existing standalone UI conflicts.

## Validation

The release retains the gameplay/source payload of the final 0.1.15 corrective
ZIP. Prior native QA used Gen1Recomp **0.2.56**, private profiles and muted,
nonactivating runs on **Red, Gold, Silver and Crystal**. Fifteen final affected
native cases passed, including 25,300 dialogue checks per Gen 2 game, live
settings and independent PP controls. Installed PC/Pokédex sprite checks passed
15,064 assertions over 831 pictures and 117 icon sheets, with zero independent
preservation violations. The preceding 28-case preflight covers the retained
Red battle matrix and PC/Bag/Pokédex regressions. These are recorded prior QA
results; they are not a claim of a new full native rerun for publication.

No native Blue/Yellow imports or physical mobile-device tests were available.
Compact/portrait coverage used desktop windows. The exact user combination of
third-party battle-art/gender mods was not reproduced natively. Native GAME
retains its original TYPE/PP box and related player-picture clipping; external
renderers retain ownership. Existing cartridge save-export limits remain.

## Release packaging fixes

- Exclude QA tests, fixtures and repository metadata from installable archives.
- Publish these detailed, versioned release notes instead of commit subjects.
- Include a SHA-256 checksum file beside the installable ZIP.



## Component versions

| Component | Published 0.1.12 | Release 0.1.15 |
| --- | --- | --- |
| Start Menu | 0.1.18 | 0.1.19 |
| Party | 0.4.9 | 0.4.9 (unchanged) |
| Bag | 0.5.0 | 0.6.1 |
| PC | 0.4.4 | 0.6.1 |
| Pokédex | 0.2.10 | 0.2.13 |
| Battle HUD | 0.9.2 | 0.9.3 |
| Typed Move Colors | 0.4.10 | 0.5.1 |
| Unlimited PP | absent | 0.1.0, default Off |
