-- Native runtime comparison for the user-reported Red battle composition.
return function(game)
  local U = dofile(assert(os.getenv("PC_REPO")) .. "/tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local Pokemon = require("src.pokemon.Pokemon")
  local PaletteFX = require("src.render.PaletteFX")
  local Font = require("src.render.Font")
  local opts = game.mods.modOptions.modern_ui_suite
  local out = assert(os.getenv("SHOT_DIR"))
  love.window.setMode(1034, 788, { resizable = true })
  game.save.options = game.save.options or {}
  game.save.options.colors = "redpp"
  PaletteFX.setMode("redpp")
  local mon = Pokemon.new(game.data, "IVYSAUR", 25)
  mon.moves = { { id = "TACKLE", pp = 35 }, { id = "POISONPOWDER", pp = 35 },
    { id = "LEECH_SEED", pp = 10 }, { id = "RAZOR_LEAF", pp = 24 } }
  game.save.party = { mon, Pokemon.new(game.data, "PIDGEY", 20) }
  for _, mode in ipairs({ { "default", true, true, "wide", false },
      { "original", true, true, "game", false },
      { "text-only", true, true, "wide", true },
      { "hud-only", true, false, "wide", false },
      { "typed-only", false, true, "wide", false },
      { "native", false, false, "wide", false } }) do
    while game.stack:top() do game.stack:pop() end
    opts["battle_hud.enabled"], opts["move_colors.enabled"] = mode[2], mode[3]
    opts["move_colors.layout"], opts["move_colors.text_only"] = mode[4], mode[5]
    opts["move_colors.text_position"], opts["move_colors.box_color"] = "left", "original"
    opts["move_colors.info_position"], opts["move_colors.opacity"] = "original", "100"
    game.save.options.battleLayout = "og"
    local battle = BattleState.newWild(game, "SHELLDER", 16, { onFinish = function() end })
    game.stack:push(battle)
    battle.introSlide, battle.introBalls = 0, nil
    battle.showEnemyTrainer, battle.showPlayerBack = false, false
    battle.enemySendingOut, battle.sendingOut = false, false
    battle.phase, battle.menuIndex, battle.moveIndex = "menu", 1, 4
    U.wait(3)
    assert(U.shot(game, out .. "/" .. mode[1] .. "-commands.png"))
    battle.phase = "moveSelect"
    U.wait(3)
    assert(U.shot(game, out .. "/" .. mode[1] .. "-moves.png"))
    print("[RED BASELINE] " .. mode[1] .. " wide=" .. tostring(battle:wideLayout())
      .. " detached=" .. tostring(BattleState._typedMoveColorsInputPatch
        and BattleState._typedMoveColorsInputPatch.detached(battle)))
  end
  print("[RED BASELINE] 12 screenshots captured")
  if os.getenv("GEN1_MATRIX") == "1" then
    local checks = 0
    local function check(ok, why) assert(ok, "GEN1 BATTLE: " .. why); checks = checks + 1 end
    local pressed
    game.input.wasPressed = function(_, key) return key == pressed end
    game.input.isDown = function() return false end
    local function tap(screen, key) pressed = key; screen:update(0); pressed = nil end
    local function shot(tag)
      U.wait(2)
      check(not love.window.hasFocus(), tag .. " background focus retained")
      check(love.audio.getVolume() == 0, tag .. " master audio stays muted")
      check(U.shot(game, out .. "/" .. tag .. ".png"), tag .. " captured")
    end
    local paths = { {"game", "og", "game", false}, {"wide", "og", "wide", false},
      {"text-only", "og", "game", true}, {"engine-wide", "wide", "wide", false} }
    local settings = { {"default", "left", "original", "original", "100"},
      {"center-black", "center", "black", "left", "100"},
      {"right-white", "right", "white", "right", "100"},
      {"gray", "left", "gray", "original", "100"},
      {"opacity", "right", "black", "left", "70"} }
    local sizes = { {"reported", 1034, 788}, {"16x9", 1280, 720},
      {"compact", 320, 288}, {"portrait", 480, 900} }
    local function fresh(path, row)
      while game.stack:top() do game.stack:pop() end
      opts["battle_hud.enabled"], opts["move_colors.enabled"] = true, true
      opts["move_colors.layout"], opts["move_colors.text_only"] = path[3], path[4]
      opts["move_colors.text_position"], opts["move_colors.box_color"] = row[2], row[3]
      opts["move_colors.info_position"], opts["move_colors.opacity"] = row[4], row[5]
      game.save.options.battleLayout, game.save.options.textSpeed = path[2], 1
      game.save.options.animations = true
      local player = Pokemon.new(game.data, "IVYSAUR", 25)
      player.moves = { {id="TACKLE",pp=35}, {id="POISONPOWDER",pp=35},
        {id="LEECH_SEED",pp=10}, {id="RAZOR_LEAF",pp=24} }
      game.save.party = {player, Pokemon.new(game.data, "PIDGEY", 20)}
      local battle = BattleState.newWild(game, "SHELLDER", 16, {onFinish=function() end})
      game.stack:push(battle)
      battle.introSlide, battle.introBalls, battle.current = 0, nil, nil
      battle.showEnemyTrainer, battle.showPlayerBack = false, false
      battle.enemySendingOut, battle.sendingOut = false, false
      battle.phase, battle.menuIndex, battle.moveIndex = "menu", 1, 1
      battle.queue, battle.afterQueue = {}, "menu"
      return battle, player
    end
    for _, size in ipairs(sizes) do
      love.window.setMode(size[2], size[3], {resizable=true}); U.wait(2)
      for _, path in ipairs(paths) do
        for _, row in ipairs(settings) do
          local tag = size[1] .. "-" .. path[1] .. "-" .. row[1]
          local battle, player = fresh(path, row)
          local draws, draw, drawBox, panelRows = {}, Font.draw, Font.drawBox, {}
          local expandedFooter = false
          Font.draw = function(value, x, y, ...)
            if value == battle.player.name and x == 80 then draws[#draws+1] = y end
            return draw(value, x, y, ...)
          end
          Font.drawBox = function(tx,ty,tw,th,...)
            if tx == 23 and tw == 15 then
              panelRows[#panelRows+1] = ty
              if ty == 7 and th == 6 then expandedFooter = true end
            end
            return drawBox(tx,ty,tw,th,...)
          end
          shot(tag .. "-commands")
          Font.draw, Font.drawBox = draw, drawBox
          check(not battle.typedMoveColorsNativeRows, tag .. " command labels cannot be covered by move fills")
          if path[2] == "og" then
            check(#draws > 0, tag .. " player name is rendered")
            for _, y in ipairs(draws) do check(y >= 56, tag .. " player name stays below enemy sprite slot") end
          else
            check(#panelRows>0, tag .. " native wide player panel is drawn")
            check(expandedFooter, tag .. " wide HUD footer has a separate border row")
            for _, y in ipairs(panelRows) do check(y>=7, tag .. " wide panel stays below enemy sprite slot") end
          end
          tap(battle, "a")
          check(battle.phase == "moveSelect", tag .. " FIGHT opens native move controller")
          shot(tag .. "-moves")
          if path[1] == "game" and row[5] == "100" then
            local pixels = game.renderer.canvas:newImageData()
            local r,g,b = pixels:getPixel(150,105)
            local expected = BattleState._typedMoveColorsInputPatch.colorsFor(game,"NORMAL")[3]
            -- Focused row is darkened, so inspect the unfocused Poison row.
            r,g,b = pixels:getPixel(150,113)
            expected = BattleState._typedMoveColorsInputPatch.colorsFor(game,"POISON")[3]
            check(math.abs(r*255-expected[1])<2 and math.abs(g*255-expected[2])<2
              and math.abs(b*255-expected[3])<2, tag .. " native row RGB survives internal SGB recolour")
          end
          tap(battle,"select")
          check(battle.moveSwapIndex == 1, tag .. " native Select marks source move")
          tap(battle,"down")
          local destination = battle.moveIndex
          check(destination ~= 1, tag .. " focus moves while source remains held")
          shot(tag .. "-source-held")
          local before, target = battle.player.curMoves[1], battle.player.curMoves[destination]
          tap(battle,"a")
          check(battle.moveSwapIndex == nil and battle.player.curMoves[destination] == before
            and battle.player.curMoves[1] == target, tag .. " native reorder preserves move/PP objects")
          tap(battle,"b")
          check(battle.phase == "menu", tag .. " B returns to command menu")
          shot(tag .. "-returned")
          check(not battle.typedMoveColorsNativeRows, tag .. " move colour state is cleared on return")
          tap(battle,"right"); tap(battle,"a"); battle:update(0)
          local party = game.stack:top()
          check(party ~= battle, tag .. " PKMN opens native party controller")
          shot(tag .. "-party")
          tap(party,"b"); battle:update(0)
          check(game.stack:top() == battle, tag .. " party B returns to battle")
          check(game.save.party[1] == player, tag .. " party cancel preserves ownership")

          battle = fresh(path,row)
          battle.phase = "messages"
          battle:startMessage({text="IVYSAUR used\nTACKLE!\vThe final line\nis still readable."})
          local seen = {}
          for frame=1,600 do
            for _, line in ipairs(battle:visibleText() or {}) do seen[line]=true end
            if battle.msgWaiting or battle.msgPrompt then tap(battle,"a") else battle:update(0) end
            if frame % 12 == 0 then U.wait(1) end
            if battle.phase == "menu" then break end
          end
          check(seen["IVYSAUR used"] and seen["TACKLE!"] and seen["The final line"]
            and seen["is still readable."], tag .. " all native message pages progress")
          check(battle.phase == "menu", tag .. " dialogue returns to command menu")
          shot(tag .. "-after-dialogue")

          if row[1] == "default" then
            battle = fresh(path,row)
            battle.enemy.mon.stats.hp, battle.enemy.mon.hp = 9999, 9999
            battle.enemy.curMoves = {{id="TACKLE",pp=35}}
            tap(battle,"a"); tap(battle,"a")
            local animated, captured = false, false
            for frame=1,8000 do
              if battle.animPlaying then
                animated = true
                if not captured then shot(tag .. "-attack-animation"); captured = true end
              end
              if battle.msgWaiting or battle.msgPrompt then tap(battle,"a") else battle:update(1/60) end
              if frame % 60 == 0 then U.wait(1) end
              if battle.phase == "menu" then break end
            end
            check(animated, tag .. " a real move runs the native animation player")
            check(battle.phase == "menu" and battle.player.curMoves[1].pp == 34,
              tag .. " a complete real turn spends one PP and returns to menu")
          end

          local nickname = battle:askNicknameUI(battle.enemy.mon, "SHELLDER")
          game.stack:push(nickname)
          for _=1,300 do
            local top = game.stack:top()
            if top ~= nickname then break end
            tap(top,"a")
          end
          local choice = game.stack:top()
          check(choice ~= nickname and choice ~= battle, tag .. " native nickname Yes/No opens")
          shot(tag .. "-nickname")
          if row[1] == "center-black" then
            tap(choice,"a")
          elseif row[1] == "right-white" then
            tap(choice,"down"); check(choice.index == 2, tag .. " NO focus uses native choice cursor")
            tap(choice,"a")
          else tap(choice,"b") end
          for _=1,30 do if game.stack:top() ~= choice then break end; choice:update(0) end
          if row[1] == "center-black" then
            local naming = game.stack:top()
            check(naming ~= battle and naming ~= choice and type(naming.onDone)=="function",
              tag .. " YES opens native naming controller")
            naming.onDone("SHELL QA"); game.stack:pop()
            check(battle.enemy.mon.nickname == "SHELL QA", tag .. " native naming callback preserves selected mon")
          end
          check(game.stack:top() == battle and not battle.blankForAskName,
            tag .. " native nickname choice restores battle")
          check(opts["move_colors.layout"] == path[3] and opts["move_colors.text_position"] == row[2]
            and opts["move_colors.box_color"] == row[3] and opts["move_colors.info_position"] == row[4]
            and opts["move_colors.opacity"] == row[5], tag .. " user appearance preferences stay unchanged")
        end
      end
    end
    love.window.setMode(1034,788,{resizable=true})
    for _, colorMode in ipairs(PaletteFX.MODES) do
      game.save.options.colors = colorMode; PaletteFX.setMode(colorMode)
      for _, path in ipairs(paths) do
        local battle = fresh(path,settings[1])
        shot("palette-" .. colorMode .. "-" .. path[1] .. "-commands")
        check(not battle.typedMoveColorsNativeRows, colorMode .. " menu has no stale move paint")
        tap(battle,"a")
        shot("palette-" .. colorMode .. "-" .. path[1] .. "-moves")
        check(battle.phase=="moveSelect", colorMode .. " native moves still interactive")
      end
    end
    print("[GEN1 MATRIX] " .. checks .. " checks passed")
  end
  love.event.quit(0)
end
