-- Real Gen 2 menu, glyph and input checks; run through the isolated quiet runner.
return function(game)
  local U = dofile(assert(os.getenv("PC_REPO")) .. "/tests/drivers/util.lua")
  local Save = require("src.core.gen2.Save")
  local Mon = require("src.battle.gen2.Mon")
  local Battle = require("src.battle.gen2.Battle")
  local View = require("src.ui.gen2.BattleAnimView")
  local Screens = require("src.ui.Screens")
  local Chrome = require("src.ui.gen2.Chrome")
  local opts = game.mods.modOptions.modern_ui_suite
  local checks = 0
  local function check(ok, why) assert(ok, why); checks = checks + 1 end
  while game.stack:top() do game.stack:pop() end
  game.save = Save.newGame({ playerName = "TEXT QA", trainerId = 4321 })
  local player = Mon.new(game.data, "TYPHLOSION", 48)
  player.moves = {
    { id = "FLAMETHROWER", pp = 12, maxPp = 15 },
    { id = "THUNDERPUNCH", pp = 14, maxPp = 15 },
    { id = "EARTHQUAKE", pp = 10, maxPp = 10 },
    { id = "SWIFT", pp = 18, maxPp = 20 },
  }
  game.save.party = { player }
  game.save.options = { battleLayout = "og" }
  local battle = Battle.new({ data = game.data, save = game.save,
    party = game.save.party, wild = Mon.new(game.data, "PIDGEOT", 45) })
  local screen = Screens.push(game, "Gen2BattleState", {
    save = game.save, battle = battle, onDone = function() end })
  screen.slideFrame = View.SLIDE_FRAMES
  screen.showPlayerTrainer, screen.showEnemyTrainer = false, false
  screen.showEnemyHud, screen.showPlayerHud = true, true
  screen.ballRows, screen.queue = {}, {}
  screen.anim, screen.message, screen.typer = nil, nil, nil
  screen.messageTimer, screen.phase, screen.moveIndex = 0, "moves", 1
  opts["move_colors.enabled"], opts["move_colors.battle_colors"] = true, true
  local nativePrint, writes = Chrome.printThrough, {}
  local observe = function(text, x, y, palette, ...)
    writes[text] = { x = x, y = y, palette = palette }
    return nativePrint(text, x, y, palette, ...)
  end
  Chrome.printThrough = observe
  local function capture(name)
    writes = {}; U.wait(3)
    check(not love.window.hasFocus() and love.audio.getVolume() == 0, "silent background test")
    check(U.shot(game, os.getenv("SHOT_DIR") .. "/" .. name .. ".png"), "capture " .. name)
    check(Chrome.printThrough == observe, "native print restored")
  end
  local pressed
  game.input.wasPressed = function(_, key) return key == pressed end
  game.input.isDown = function() return false end
  local function tap(key) pressed = key; screen:update(0); pressed = nil end
  local function colored(write)
    local ink = write and write.palette and write.palette[4]
    return ink and math.max(unpack(ink)) - math.min(unpack(ink)) > 10
  end

  for _, hud in ipairs({ true, false }) do
    opts["battle_hud.enabled"] = hud
    for _, size in ipairs({ { "wide", 1280, 720 }, { "portrait", 480, 900 } }) do
      love.window.setMode(size[2], size[3], { resizable = true })
      local tag = (hud and "hud-" or "native-") .. size[1]
      opts["move_colors.text_only"] = true
      capture("text-only-" .. tag)
      check(screen.typedMoveColorsLayout == "native", "native list is visible")
      check(not screen.typedMoveColorsOwnsBottom, "cards do not hide native bottom")
      check(screen.typedMoveColorsTextRuns >= 5, "native names and type are tinted")
      for i, move in ipairs(screen:playerMoves()) do
        local write = writes[game.data.moves[move.id].name]
        check(write and write.x == 6 and write.y == 12 + i, "native move position " .. move.id)
        check(not not colored(write) == (i < 4), "type ink " .. move.id)
      end
      check(writes["12/15"] and not colored(writes["12/15"]), "native PP remains neutral")
      screen.moveIndex = 1; tap("right")
      check(screen.moveIndex == 1, "native list ignores RIGHT")
      tap("down"); check(screen.moveIndex == 2, "native DOWN advances one row")
      tap("up"); check(screen.moveIndex == 1, "native UP returns one row")
    end
  end
  tap("select"); check(screen.moveSwapIndex == 1, "native Select picks up move")
  tap("down"); capture("text-only-held")
  check(writes["▷"] ~= nil, "native held marker remains visible")
  tap("select")
  check(screen:playerMoves()[1].id == "THUNDERPUNCH"
    and screen:playerMoves()[2].id == "FLAMETHROWER", "native swap changes actual move order")
  check(screen:playerMoves()[1].pp == 14 and screen:playerMoves()[2].pp == 12,
    "native swap preserves move PP")
  tap("b"); check(screen.phase == "menu", "native B returns to commands")
  screen.phase, screen.moveIndex = "moves", 1
  opts["move_colors.text_only"] = false
  capture("cards-restored")
  check(screen.typedMoveColorsLayout == "grid", "live toggle restores cards")
  tap("right"); check(screen.moveIndex == 2, "live toggle restores grid input")
  opts["move_colors.text_only"] = true
  opts["move_colors.battle_colors"] = false
  capture("colours-disabled")
  check(not colored(writes.THUNDERPUNCH), "battle colours OFF removes tint")
  opts["move_colors.battle_colors"] = true
  opts["move_colors.enabled"] = false
  capture("component-disabled")
  check(not colored(writes.THUNDERPUNCH), "component OFF removes tint")
  Chrome.printThrough = nativePrint
  print("[DISCORD QA] PASS", checks, "Gen 2 Text Only checks")
end
