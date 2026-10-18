# Modern UI Suite 0.1.43

- Add item illustrations for all 276 audited named item IDs across Red, Blue, Yellow, Gold, Silver and Crystal. Aliases and shared family templates are explicit; unknown mod items keep their category fallback.
- Use the approved round capture-ball designs, including distinct variants and a refined Lure Ball. TM/HM discs follow the taught move's current type; item names retain machine/move identity.
- Keep Gen II CANCEL visible before selection, including empty pockets, and show help without item artwork. Preserve native actions, inventory and navigation; Gen I retains B to exit.
- Redraw category tabs with a pouch, intact contrasting medicine cap, ball, disc and the approved native 15×9 key. Centre opaque bounds, retain identical selected/unselected geometry, and remove under-icon marks.
- Include published CC0 Openmon attribution, the CC0 text, final artwork sources, prompts and explicit coverage recipes. New AI-assisted fan art is identified separately from Openmon; no clearance of underlying Pokémon design rights is claimed.

- Fix Gen II move-replacement dialogue order when QoL Toggles appends its result behind pending battle events. “1, 2… Poof!”, forgotten move and learned move now complete before later EXP, send-out or victory dialogue. Native field/TM/HM teaching keeps its existing sequence.
- Preserve the 0.1.42 popup opacity and HUD contrast fixes by building on current public main.

## Optional Battle Art save repair

`battle_art_gen2-evolution-save-patch-1.zip` is a **separate Python source patch** for Battle Art Voxel Gen2 2.1.0 and 2.1.3. It registers evolved records that inherit temporary battle images so the existing cleanup removes them before saving. It is not automatically applied by the Suite ZIP, does not replace Battle Art, and is not an upstream Battle Art release. See the patch README for installation and rollback. It cannot recover unsaved progress.

## Verification and installation

- 276 item mappings / 333 renderer assertions; native category geometry and palette checks.
- Release candidates: 237 rendered category/layout states across Suite Gold/Crystal and standalone Red/Gold; wide, compact, portrait, selected/unselected and Pocket layouts.
- Bag regressions: 236 standalone checks, 46 Suite Gen II parity checks, 22 Suite Bag QoL checks and 4 standalone widescreen checks.
- Native Gold reproduction confirmed the original dialogue defect; the fix passed level-up replacement, field replacement, real TM teaching, cancel/decline and single-callback checks. A full Bugsy fight completed learning before later battle text, awarded the Hive Badge and saved successfully.
- Battle Art save repair: actual Croconaw → Feraligatr / Bugsy / Hive Badge / Save menu / reload passed on the installed 2.1.0 setup. The 2.1.3 cleanup functions passed focused regressions; full 2.1.3 gameplay was not tested.
- Tests used copied saves, isolated profiles, silent audio from startup and nonactivating background windows. No ROMs, saves, extracted game data or gameplay screenshots are bundled.

Install `modern_ui_suite-0.1.43.zip` through the mod importer, or replace the Suite mod folder from the ZIP. **Fully quit and restart the game.** Do not enable standalone Modern Bag UI alongside the Suite's Bag component.
