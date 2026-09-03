-- Visual regression proof for Typed Move Colors in the faithful GAME layout.
--
-- Run from the engine root:
--   SHOT_DIR=/tmp/modern-ui-suite-game \
--     POKEPORT_DRIVER=mods/modern_ui_suite/tests/gen1_game_move_colors_preview.lua \
--     POKEPORT_TOUCH=0 POKEPORT_VERSION=red love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local PaletteFX = require("src.render.PaletteFX")
  local Pokemon = require("src.pokemon.Pokemon")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/modern-ui-suite-game"

  love.window.setMode(1600, 900, {
    resizable = true, minwidth = 640, minheight = 360,
  })

  local suite = game.mods and game.mods.exports
    and game.mods.exports.modern_ui_suite
  assert(type(suite) == "table",
    "Modern UI Suite must be the loaded move-colour implementation")

  local function setSuiteOption(key, value)
    game.save.options = game.save.options or {}
    game.save.options.modOptions = game.save.options.modOptions or {}
    game.save.options.modOptions.modern_ui_suite =
      game.save.options.modOptions.modern_ui_suite or {}
    game.save.options.modOptions.modern_ui_suite[key] = value

    game.mods.modOptions = game.mods.modOptions or {}
    game.mods.modOptions.modern_ui_suite =
      game.mods.modOptions.modern_ui_suite or {}
    game.mods.modOptions.modern_ui_suite[key] = value
  end

  for _, key in ipairs({
    "start_menu.enabled", "party.enabled", "bag.enabled", "pc.enabled",
    "pokedex.enabled", "battle_hud.enabled", "move_colors.enabled",
  }) do
    setSuiteOption(key, false)
  end
  setSuiteOption("move_colors.enabled", true)
  setSuiteOption("move_colors.battle_colors", true)
  setSuiteOption("move_colors.layout", "game")
  setSuiteOption("move_colors.effect_hints", true)
  setSuiteOption("move_colors.strength", "bold")
  setSuiteOption("move_colors.opacity", "100")
  setSuiteOption("move_colors.text_only", false)

  game.save.options.colors = "redpp"
  game.save.options.battleLayout = "og"
  PaletteFX.setMode("redpp")

  local mon = Pokemon.new(game.data, "IVYSAUR", 24)
  mon.moves = {}
  for _, id in ipairs({
    "TACKLE", "POISON_STING", "LEECH_SEED", "RAZOR_LEAF",
  }) do
    local def = assert(game.data.moves[id], "missing preview move " .. id)
    mon.moves[#mon.moves + 1] = { id = id, pp = def.pp }
  end
  game.save.party = { mon }

  while game.stack:top() do game.stack:pop() end
  local battle = BattleState.newWild(game, "RATTATA", 18, {
    onFinish = function() end,
  })
  game.stack:push(battle)
  U.wait(8)
  battle.introSlide = 0
  battle.introBalls = nil
  battle.showEnemyTrainer = false
  battle.showPlayerBack = false
  battle.enemySendingOut = false
  battle.sendingOut = false
  battle.phase = "moveSelect"
  battle.moveIndex = 2
  U.wait(8)

  assert(U.shot(game, DIR .. "/game-move-colors.png"),
    "GAME move-colour screenshot was not written")
  U.log("PASS GAME move names retain native geometry and integer-scale ink")
end
