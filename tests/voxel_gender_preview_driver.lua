-- Visual regression proof for Gender Mod + Crystal 251 + Battle Art Voxel.
-- Captures the ordinary battle HUD and the full-party transfer message with
-- Modern UI Suite's Battle HUD both disabled and enabled.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or
    "artifacts/modern-ui-suite-voxel-gender"
  local BattleState = require("src.battle.BattleState")
  local ChoiceBox = require("src.ui.ChoiceBox")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local SaveData = require("src.core.SaveData")

  love.window.setMode(1280, 720, {
    resizable = true, minwidth = 480, minheight = 360,
  })

  local function check(ok, message)
    if not ok then error("VOXEL GENDER PROOF FAILED: " .. message, 0) end
    U.log("PASS", message)
  end

  local exports = game.mods and game.mods.exports or {}
  check(type(exports.modern_ui_suite) == "table",
    "Modern UI Suite is loaded")
  check(type(exports.gender_mod) == "table",
    "Gender Mod is loaded")
  check(type(exports.CRYSTAL_251) == "table",
    "Crystal 251 is loaded")
  check(type(exports.BATTLE_ART_VOXEL_FORK) == "table",
    "Battle Art Voxel Fork is loaded")

  -- Scripted boots use an intentionally temporary save, while Crystal 251's
  -- generated raster bundle is scoped to the selected playthrough. Borrow
  -- only that durable identity so this proof reads the same asset bundle as
  -- the real game without mutating the player's loaded save data.
  local selected = SaveData.load(GameVersion.get())
  check(type(selected) == "table" and type(selected.meta) == "table"
      and type(selected.meta.playthroughId) == "string",
    "the selected playthrough exposes Crystal 251's asset scope")
  game.save.version = GameVersion.get()
  game.save.meta = game.save.meta or {}
  game.save.meta.playthroughId = selected.meta.playthroughId

  local function setBattleHud(value)
    game.mods.modOptions = game.mods.modOptions or {}
    game.mods.modOptions.modern_ui_suite =
      game.mods.modOptions.modern_ui_suite or {}
    game.mods.modOptions.modern_ui_suite["battle_hud.enabled"] = value
    game.save.options = game.save.options or {}
    game.save.options.modOptions = game.save.options.modOptions or {}
    game.save.options.modOptions.modern_ui_suite =
      game.save.options.modOptions.modern_ui_suite or {}
    game.save.options.modOptions.modern_ui_suite["battle_hud.enabled"] = value
  end

  local function topIs(class)
    return getmetatable(game.stack:top()) == class
  end

  local function waitFor(condition, frames, tap)
    for _ = 1, frames do
      if condition() then return true end
      if tap then U.tap(game, tap) else U.wait(1) end
    end
    return false
  end

  local function unwind(overworld)
    for _ = 1, 30 do U.tap(game, "a"); U.wait(3) end
    while game.stack:top() ~= overworld do game.stack:pop() end
    U.wait(8)
  end

  local function runCase(tag, enabled)
    setBattleHud(enabled)
    game.save.party = {}
    for _ = 1, 6 do
      table.insert(game.save.party,
        Pokemon.new(game.data, "IVYSAUR", 24))
    end
    game.save.pokedex = game.save.pokedex or { owned = {}, seen = {} }
    game.save.pokedex.owned = game.save.pokedex.owned or {}
    game.save.pokedex.seen = game.save.pokedex.seen or {}
    game.save.pokedex.owned.SPEAROW = true
    game.save.pokedex.seen.SPEAROW = true
    game.save.flags = game.save.flags or {}
    game.save.flags.EVENT_MET_BILL = true

    U.teleport(game, "ROUTE_1", 5, 5, "down")
    local overworld = game.overworld
    local battle = BattleState.newWild(game, "SPEAROW", 10)
    battle.onFinish = function() end
    battle.rng = function(a) return a end
    overworld:pushBattle(battle)

    check(waitFor(function()
      return game.stack:top() == battle and battle.phase == "menu"
    end, 500, "a"), tag .. " battle reached the command menu")
    U.wait(12)
    check(U.shot(game, DIR .. "/" .. tag .. "-battle.png"),
      tag .. " ordinary Voxel battle captured")

    battle.phase = "messages"
    battle.afterQueue = "menu"
    battle:throwBall("POKE_BALL")
    check(waitFor(function() return topIs(ChoiceBox) end, 900, "a"),
      tag .. " catch reached the nickname choice")
    U.tap(game, "b")
    U.wait(8)

    local sawTransfer = waitFor(function()
      return game.stack:top() == battle and battle.current
        and type(battle.current.text) == "string"
        and battle.current.text:find("transferred", 1, true)
        and (battle.charIndex or 0) >= math.floor((battle.total or 0) * 0.7)
    end, 600)
    check(sawTransfer, tag .. " catch reached the PC-transfer message")
    check(U.shot(game, DIR .. "/" .. tag .. "-transfer.png"),
      tag .. " Voxel transfer screen captured")
    unwind(overworld)
  end

  local requested = os.getenv("VOXEL_GENDER_CASE")
  if not requested or requested == "disabled" then
    runCase("disabled", false)
  end
  if not requested or requested == "enabled" then
    runCase("enabled", true)
  end
  check(requested == nil or requested == "disabled" or requested == "enabled",
    "VOXEL_GENDER_CASE is disabled, enabled, or unset")
  U.log("PASS", "Voxel gender visual proof complete")
end
