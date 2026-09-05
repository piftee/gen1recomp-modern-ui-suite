-- Exact combined-ZIP proof; use only a private, muted background QA profile.
return function(game)
  local U = dofile(assert(os.getenv("PC_REPO")) .. "/tests/drivers/util.lua")
  local Font = require("src.render.Font")
  local SaveData = require("src.core.SaveData")
  local GameVersion = require("src.core.GameVersion")
  local Screens = require("src.ui.Screens")
  local edition, generation = GameVersion.get(), GameVersion.generation()
  local suite = assert(game.mods.exports.modern_ui_suite)
  local options = game.mods.modOptions.modern_ui_suite
  local out, checks = assert(os.getenv("SHOT_DIR")), 0
  local function check(ok, why) assert(ok, "SUITE PP: " .. why); checks = checks + 1 end
  local function clear() while game.stack:top() do game.stack:pop() end end
  local pressed
  game.input.wasPressed = function(_, key) return key == pressed end
  game.input.isDown = function() return false end
  local function tap(screen, key) pressed = key; screen:update(0); pressed = nil end
  local function capture(tag)
    U.wait(2)
    check(not love.window.hasFocus() and love.audio.getVolume() == 0, "quiet background " .. tag)
    check(U.shot(game, out .. "/" .. tag .. ".png"), "captured " .. tag)
  end
  check(suite.components.unlimited_pp.version == "0.1.0", "independent QoL component is installed")
  check(not suite.isEnabled("unlimited_pp"), "fresh combined install defaults OFF")
  clear(); suite.settings.open(game)
  local hub = game.stack:top()
  local item
  for _, candidate in ipairs(hub.items) do if candidate.id == "unlimited_pp" then item = candidate end end
  check(item and item.label == "QOL", "independent QOL entry is selectable")
  hub.onChoose(item, hub)
  local page = game.stack:top()
  check(#page.rows == 1 and page.rows[1].label == "UNLIMITED PP", "one named On/Off control")
  capture("qol-default-off")
  tap(page, "right")
  check(suite.isEnabled("unlimited_pp"), "real Options input enables QoL")
  check(SaveData.loadOptions().modOptions.modern_ui_suite["qol.enabled"] == true, "On persisted to private options")
  capture("qol-enabled")
  for _, index in ipairs({2, 1}) do
    hub.onChoose(hub.items[index], hub)
    check(suite.isEnabled("unlimited_pp"), "bulk UI action preserves explicit On")
  end
  tap(page, "right")
  for _, index in ipairs({1, 2}) do
    hub.onChoose(hub.items[index], hub)
    check(not suite.isEnabled("unlimited_pp"), "bulk UI action never enables QoL")
  end

  local modes = {
    {"all-on", true, true, true}, {"party-off", false, true, true},
    {"typed-off", true, false, true}, {"both-off", false, false, true},
    {"all-ui-off", false, false, false},
  }
  if generation == 1 then modes[#modes+1] = {"engine-wide", true, true, true, "wide"} end
  local uiKeys = {"start_menu", "party", "bag", "pc", "pokedex", "battle_hud", "move_colors"}
  local function toggle(value)
    if suite.isEnabled("unlimited_pp") ~= value then tap(page, "right") end
    check(suite.isEnabled("unlimited_pp") == value, "QoL independently switches " .. tostring(value))
  end
  local function fresh(mode)
    clear(); Screens.invalidate()
    for _, key in ipairs(uiKeys) do options[key .. ".enabled"] = mode[4] end
    options["party.enabled"], options["move_colors.enabled"] = mode[2], mode[3]
    options["move_colors.layout"], options["move_colors.text_only"] = "wide", false
    options["move_colors.opacity"], options["move_colors.info_position"] = "100", "original"
    game.save.options.battleLayout = mode[5] or "og"
    if generation == 1 then
      local Pokemon = require("src.pokemon.Pokemon")
      local BattleState = require("src.battle.BattleState")
      local player = Pokemon.new(game.data, "RATTATA", 12)
      player.moves = {{id="TACKLE", pp=0}}
      game.save.party = {player}
      local screen = BattleState.newWild(game, "RATTATA", 10, {onFinish=function() end})
      game.stack:push(screen)
      screen.enemy.curMoves = {{id="GROWL",pp=35}}
      screen.enemy.mon.stats.hp, screen.enemy.mon.hp = 9999, 9999
      screen.introSlide, screen.introBalls = 0, nil
      screen.showEnemyTrainer, screen.showPlayerBack = false, false
      screen.enemySendingOut, screen.sendingOut = false, false
      screen.phase, screen.menuIndex, screen.moveIndex = "menu", 1, 1
      return screen, screen, screen.player.curMoves[1]
    end
    local Mon, Battle = require("src.battle.gen2.Mon"), require("src.battle.gen2.Battle")
    local View = require("src.ui.gen2.BattleAnimView")
    local player, enemy = Mon.new(game.data,"RATTATA",12), Mon.new(game.data,"RATTATA",10)
    player.moves = {{id="TACKLE",pp=0,maxPp=35}}
    enemy.moves = {{id="GROWL",pp=35,maxPp=40}}
    enemy.hp, enemy.maxHp, enemy.stats.hp = 9999, 9999, 9999
    game.save.party = {player}
    local battle = Battle.new({data=game.data, save=game.save, party=game.save.party,
      wild=enemy, random=function() return 0 end})
    local screen = Screens.push(game,"Gen2BattleState",{save=game.save,battle=battle,onDone=function() end})
    screen.slideFrame = View.SLIDE_FRAMES
    screen.showPlayerTrainer, screen.showEnemyTrainer = false, false
    screen.showEnemyHud, screen.showPlayerHud = true, true
    screen.ballRows, screen.queue = {}, {}
    screen.anim, screen.message, screen.typer = nil, nil, nil
    screen.messageTimer, screen.phase, screen.menuIndex, screen.moveIndex = 0, "menu", 1, 1
    return screen, battle, player.moves[1]
  end
  local function shotPP(screen, tag, active)
    local sawUnsupported = false
    local nativeClass = require(generation == 1 and "src.battle.BattleState" or "src.battle.gen2.Battle")
    local nativePatch = assert(rawget(nativeClass,"_unlimitedPPPatch"))
    local typedPatch = generation == 1 and require("src.battle.BattleState")._typedMoveColorsInputPatch or {}
    local before = (nativePatch.infinityDrawCount or 0) + (typedPatch.infinityDrawCount or 0)
    screen.typedMoveColorsInfinityVisible = false
    local draw, encode = Font.draw, Font.encode
    local function record(value)
      value = tostring(value)
      if value:find("INF",1,true) or value:find("∞",1,true) then sawUnsupported = true end
    end
    Font.draw = function(value,...) record(value); return draw(value,...) end
    Font.encode = function(value,...) record(value); return encode(value,...) end
    capture(tag)
    Font.draw, Font.encode = draw, encode
    local after = (nativePatch.infinityDrawCount or 0) + (typedPatch.infinityDrawCount or 0)
    local visible = screen.typedMoveColorsInfinityVisible or after > before
    check(visible == active, tag .. " truthful infinity PP display")
    check(not sawUnsupported, tag .. " infinity never depends on unsupported font text")
  end
  for _, size in ipairs({{"compact",320,288},{"wide",1280,720}}) do
    love.window.setMode(size[2],size[3],{resizable=true})
    for _, mode in ipairs(modes) do
      local tag = edition .. "-" .. size[1] .. "-" .. mode[1]
      toggle(true)
      local screen,battle,move = fresh(mode)
      tap(screen,"a")
      check(screen.phase == (generation == 1 and "moveSelect" or "moves"), tag .. " FIGHT allows an all-zero moveset")
      shotPP(screen,tag .. "-on",true)
      check(move.pp == 0, tag .. " rendering preserves zero PP")
      tap(screen,"a")
      if generation == 1 then
        for frame=1,8000 do
          if screen.msgWaiting or screen.msgPrompt then tap(screen,"a") else screen:update(1/60) end
          if frame%60==0 then U.wait(1) end
          if screen.phase == "menu" then break end
        end
        check(screen.phase == "menu" and screen.enemy.mon.hp < 9999, tag .. " real zero-PP attack completes a native turn")
      else
        check(battle.enemy.hp < 9999, tag .. " real zero-PP choice executes the attack")
        check(battle.enemy.moves[1].pp == 34, tag .. " opponent still spends PP")
      end
      check(move.pp == 0, tag .. " complete native use preserves exact stored PP")
      -- Off in the same battle restores the actual zero count immediately.
      toggle(false)
      screen.phase,screen.moveIndex = generation == 1 and "moveSelect" or "moves",1
      screen.queue,screen.message,screen.typer,screen.anim = {},nil,nil,nil
      screen.messageTimer = 0
      shotPP(screen,tag .. "-off",false)
      local usable = generation == 1 and screen:playerHasPP()
        or generation == 2 and battle:hasUsableMoves(battle.player)
      check(not usable, tag .. " Off restores real zero-PP exhaustion")
      toggle(true)
      if generation == 1 then battle.player.disabledSlot = 1
      else battle:volatile(battle.player).disabled = "TACKLE" end
      usable = generation == 1 and screen:playerHasPP()
        or generation == 2 and battle:hasUsableMoves(battle.player)
      check(not usable, tag .. " Disable remains authoritative")
      toggle(false)
      if generation == 1 then
        battle.player.disabledSlot = nil; move.pp = 3
        battle:performMove(battle.player,battle.enemy,move)
      else
        battle:volatile(battle.player).disabled = nil; move.pp = 3
        battle:useMove(battle.player,battle.enemy,"TACKLE")
      end
      check(move.pp == 2, tag .. " Off resumes native PP drain")
    end
  end
  check(SaveData.loadOptions().modOptions.modern_ui_suite["qol.enabled"] == false, "final Off persists")
  print(("[SUITE PP] %s %d checks passed"):format(edition,checks))
end
