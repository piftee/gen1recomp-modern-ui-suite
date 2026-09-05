# Modern UI Suite 0.1.16 — Battle Art compatibility

Battle Art 2.1.0's 3D battles now remain visible with Modern UI Suite enabled
on Gold, Silver and Crystal. The suite previously covered the active voxel
arena with its flat battle layout because it recognized only the older mod
identity and queried the scene with the wrong battle object.

The update recognizes the Gen 2 port, preserves Battle Art's complete scene
renderer, and keeps the suite's coloured move cards available. Battle HUD and
Move Colors remain independently switchable. Battle HUD OFF now takes effect
immediately even in an already-open battle. Normal suite presentation resumes
when a battle has no active 3D scene.

Import `modern_ui_suite-0.1.16.zip` through the Mods manager, enable it with
Battle Art, and apply/restart. Leave Battle Art's **3D-BTL** option On for
staged battles. Continue to disable overlapping standalone versions of the
suite's components.

Battle Info HUD is now 0.9.4; other embedded components retain their 0.1.15
versions and source. No Battle Art files are modified or bundled.

The compatibility fixture uses the unmodified
[Battle Art 2.1.0 release](https://github.com/absol89/Gen2Recomped-DramaticShapes/releases/tag/2.1.0)
and a generated native game cache in a separate test profile. It covers
command and move menus, component toggles, wide/classic/portrait layouts,
move pickup and cancellation, Ember animation, and 3D OFF/ON transitions.
