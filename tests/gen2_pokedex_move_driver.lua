-- Integrated Pokédex MOVE proof, run in an isolated Gen 2 QA identity.
-- PC_REPO points to this repository. SHOT_DIR selects screenshot output.
return function(game)
  local root = assert(os.getenv("PC_REPO"), "PC_REPO must point to the checkout")
  local Screens = require("src.ui.Screens")
  local suite = assert(game.mods.exports.modern_ui_suite, "suite must be enabled")
  assert(suite.components.modern_pokedex_ui.version == "0.2.13",
    "suite must contain Pokédex 0.2.13")
  assert(suite.components.modern_pc_ui.version == "0.6.1",
    "suite must retain PC 0.6.1 alongside the Pokédex update")

  dofile(root .. "/mods/modern_pokedex_ui/tests/gen2_move_preview_driver.lua")(game)

  -- Exercise the live suite gate after the real learnset/detail proof.
  while game.stack:top() do game.stack:pop() end
  local options = game.mods.modOptions.modern_ui_suite
  options["pokedex.enabled"] = false
  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  local saved = game.save.options.modOptions.modern_ui_suite or {}
  game.save.options.modOptions.modern_ui_suite = saved
  saved["pokedex.enabled"] = false
  Screens.invalidate()
  local native = Screens.build(game, "Gen2PokedexMenu", { save = game.save })
  assert(not native.modernPokedexGeneration, "OFF must restore native Pokédex")
  assert(not native.modernGen2MoveRowsFor, "OFF must not retain modern MOVE actions")
  options["pokedex.enabled"], saved["pokedex.enabled"] = true, true
  Screens.invalidate()
  local restored = Screens.build(game, "Gen2PokedexMenu", { save = game.save })
  assert(restored.modernPokedexGeneration == 2,
    "ON must restore the integrated Gen 2 Pokédex")
  assert(type(restored.modernGen2MoveRowsFor) == "function",
    "ON must restore modern MOVE actions")
  print("[SUITE] PASS Pokédex 0.2.13 moves, PC 0.6.1 coexistence and OFF/ON fallback")
  love.event.quit(0)
end
