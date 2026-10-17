# 0.1.40

- Make the Gen 2 HUD readable over Voxel battle scenery with light text and a
  thin dark outline. Keep the terrain visible without large backing panels,
  and remove the cartridge frame rules during an active 3D battle.
- Restore a visible blue EXP track in Gen 2 Voxel battles. Follow the native
  animated EXP value, including filling the bar, leveling up and resetting
  for the next level. Keep ordinary 2D battles and HUD-off rendering native.
- Put Special Stat Split's selected move category in the move details strip
  instead of drawing its fixed badge over the move cards. Show physical,
  special and status categories, and keep the full SCRATCH name visible.
- Show one area label when QoL Toggles already announces the current map.
  Discard the pending Suite label so it cannot appear again after the first
  notification expires. Crystal's native entry signs retain priority.

Verified on the official Gen1recomp 0.3.89 runtime with Battle Art Voxel Gen2
2.1.0: 129 native layout/EXP checks across Gold, Silver and Crystal, 156 3D
composition/toggle checks, and 13 area-label checks with QoL Toggles 1.30.8.
The EXP checks inspect the rendered GPU pixels and run a real EXP award across
a level-up. All 1,803 headless checks pass, including scope restoration after
render errors and native fallback paths. Tests ran muted in background windows.

No ROM data, fonts or provider artwork is bundled.
