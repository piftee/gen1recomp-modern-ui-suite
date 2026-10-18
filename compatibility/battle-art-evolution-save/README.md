# Battle Art Gen 2 evolution/save repair — patch 1

Optional companion patch for **BATTLE_ART_VOXEL_GEN2 2.1.0 or 2.1.3**. This is a
source patch, not a replacement mod or an upstream Battle Art release.

When evolution creates a new party record, it can inherit a temporary battle
image. Battle Art cleaned up the old record but missed the evolved copy, so a
later save failed with unsupported Image userdata. This patch registers only
records that inherited this battle session's sprite or animation, then uses
Battle Art's existing cleanup. It does not change the save serializer, delete
unknown fields, edit saves, or recover progress that was never saved.

Fully close the game. With Python 3 installed, run:

```sh
python3 apply.py "/path/to/mods/BATTLE_ART_VOXEL_GEN2" --receipt "/path/to/new-backup-directory"
```

Both patch anchors are checked before either file is changed. Full copies of
the two original files and readable diffs are saved in the new backup directory.
For rollback, restore `main.lua.before` to `main.lua` and
`OverworldBattle.lua.before` to `lib/OverworldBattle.lua`. Restart the game fully.
An upstream mod update may replace the patched files; check after updating.

Validation: the installed 2.1.0 configuration completed the actual Bugsy fight,
Croconaw → Feraligatr evolution, Hive Badge dialogue, Save menu write and reload.
Both 2.1.0 and the public 2.1.3 ownership/cleanup functions passed focused Lua
regressions. The complete 2.1.3 mod was not gameplay-tested. Tests used copied
saves and isolated profiles with audio disabled from startup and nonactivating
windows. The player's original save and backup were unchanged.

Upstream: https://github.com/absol89/Gen2Recomped-DramaticShapes
The patch is distributed under MIT; upstream attribution is retained in LICENSE.
