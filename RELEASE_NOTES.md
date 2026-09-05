# Modern UI Suite 0.1.18 — clearer Gen 1 battle HUD

Gen 1 battles now show compact white HP and EXP numbers inside their bars,
using the party menu's arrangement. The wide player panel has padding below
EXP, and long experience values are shortened only when needed.

The same meters work with Battle Art's 3D presentation, including its captured
HUD and native fallback. Gender Mod's icon and coloured overlay share the same
position beside the level. Status labels leave room for the icon and follow
Battle Art's text contrast.

The original HP bar is suppressed during the replacement draw, including its
separate right cap and Battle Art shadow. This fixes the old bar protruding
beyond the new one. The caught indicator remains available, and turning
**Battle HUD → HUD ENABLED** Off restores the original bars normally.

## Install

Import `modern_ui_suite-0.1.18.zip` through the Mods manager, enable Modern UI
Suite, then apply and restart. Keep overlapping standalone suite components
disabled. Battle Info HUD is now 0.10.1; other component sources, including the
Gen 2 HUD, are unchanged from 0.1.16.

## Screenshots

Standard widescreen battle:

![Gen 1 widescreen HP and EXP bars](https://raw.githubusercontent.com/piftee/gen1recomp-modern-ui-suite/v0.1.18/screenshots/gen1-wide-hud.png)

Battle Art with inverted HUD colours:

![Gen 1 Battle Art HP and EXP bars](https://raw.githubusercontent.com/piftee/gen1recomp-modern-ui-suite/v0.1.18/screenshots/gen1-battle-art-hud.png)

## Validation

Verified with Gen1Recomp 0.2.56, Battle Art 1.10.1 and Gender Mod 0.3.6 in
isolated, muted background profiles on macOS: 68 native runtime checks,
102 Battle Art checks, 896 suite checks, 17 meter checks and 1,903 frozen
component checks pass. The runtime checks cover both captured colour modes,
gender alignment, readable meter pixels, removal of the old end caps,
HUD toggles and classic/wide/portrait/compact windows.

Battle Art selects its native fallback on this Mac. Its released captured
HUD and snapped compositor were also exercised directly; physical mobile
and Windows testing was not performed for this update.
