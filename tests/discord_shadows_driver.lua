-- Check Battle Art-owned lighting with and without the suite in isolated profiles.
return function(game)
  local U = dofile(assert(os.getenv("PC_REPO")) .. "/tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local Pokemon = require("src.pokemon.Pokemon")
  local api = assert(game.mods.exports.BATTLE_ART_VOXEL_FORK)
  local staged = api.lib.require("OverworldBattle")
  local lights = api.lib.require("UiBackplates")
  local shadows = api.lib.require("Shadows")
  love.window.setMode(1280, 720, { resizable = true })
  game.save.party = { Pokemon.new(game.data, "ARCANINE", 38) }
  U.teleport(game, "ROUTE_1", 5, 5, "down")
  local battle = BattleState.newWild(game, "PIDGEY", 16, { onFinish = function() end })
  game.overworld:pushBattle(battle)
  for _ = 1, 600 do
    if battle.phase == "menu" then break end
    U.tap(game, "a")
  end
  assert(battle.phase == "menu")
  for _ = 1, 120 do
    if staged.shot() and staged.shot().canvas then break end
    U.wait(1)
  end
  assert(staged.shot() and staged.shot().canvas, "Battle Art GPU arena exists")
  local function capture(name)
    U.wait(15)
    assert(not love.window.hasFocus() and love.audio.getVolume() == 0)
    assert(U.shot(game, os.getenv("SHOT_DIR") .. "/" .. name .. ".png"))
  end
  lights.spriteLight:setIndex(1, game)
  shadows.setting:setIndex(1, game)
  assert(shadows.enabled())
  capture("shaded-shadows-on")
  lights.spriteLight:setIndex(2, game)
  assert(lights.spritesUnlit())
  capture("unlit-shadows-on")
  lights.spriteLight:setIndex(1, game)
  shadows.setting:setIndex(2, game)
  assert(not shadows.enabled())
  capture("shaded-shadows-off")
  print("[DISCORD QA] PASS suite=" .. tostring(game.mods.exports.modern_ui_suite ~= nil))
end
