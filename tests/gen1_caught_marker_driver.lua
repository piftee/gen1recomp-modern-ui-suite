-- Real Red encounter regression, including Crystal's deferred party-ball overlay.
return function(game)
  local U = dofile(assert(os.getenv("PC_REPO")) .. "/tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local Pokemon = require("src.pokemon.Pokemon")
  local PaletteFX = require("src.render.PaletteFX")
  local Assets = require("src.render.Assets")
  local Font = require("src.render.Font")
  local out = assert(os.getenv("SHOT_DIR"))
  local baseline = os.getenv("EXPECT_BASELINE") == "1"
  local previous = os.getenv("EXPECT_PALETTE_BUG") == "1"
  local checks = 0
  local function check(ok, label)
    assert(ok, label)
    checks = checks + 1
  end
  if not baseline then
    local owner = game.mods.exports.modern_ui_suite and "modern_ui_suite" or "battle_info_hud"
    local marker = love.image.newImageData("save/mod-derived/" .. owner .. "/battle/caught_ball.png")
    local sheet = love.image.newImageData("assets/generated/battle/balls.png")
    check(marker:getWidth() == 8 and marker:getHeight() == 8, "derived marker is exactly one tile")
    for y=0,7 do for x=0,7 do
      local r,g,b,a = marker:getPixel(x,y)
      local sr,sg,sb,sa = sheet:getPixel(x,y)
      check(a==sa and (sr>0.17 or (r==sr and g==sg and b==sb)),
        "marker preserves native outline and transparency")
    end end
  end
  love.window.setMode(1120, 1008, {resizable=true})
  game.save.options.colors, game.save.options.battleLayout = "redpp", "og"
  PaletteFX.setMode("redpp")
  local suiteOptions = game.mods.modOptions.modern_ui_suite
  if suiteOptions then suiteOptions["move_colors.enabled"] = false end
  local mon = Pokemon.new(game.data, "IVYSAUR", 28)
  mon.hp, mon.stats.hp = 54, 83
  game.save.party = {mon, Pokemon.new(game.data, "PIDGEY", 12)}
  game.save.pokedex = {owned={SANDSHREW=true},seen={SANDSHREW=true}}
  while game.stack:top() do game.stack:pop() end
  local battle = BattleState.newWild(game, "SANDSHREW", 6, {onFinish=function() end})
  game.stack:push(battle)
  battle.introSlide, battle.introBalls, battle.current = 0, nil, nil
  battle.showEnemyTrainer, battle.showPlayerBack = false, false
  battle.enemySendingOut, battle.sendingOut = false, false
  battle.phase, battle.menuIndex = "menu", 1
  battle.queue, battle.afterQueue = {}, "menu"
  local rowCalls = 0
  local drawRow = battle.drawBallRow
  battle.drawBallRow = function(self, ...)
    rowCalls = rowCalls + 1
    return drawRow(self, ...)
  end
  local nativeCalls, markerCalls = 0, 0
  local nativeMarker = battle.drawCaughtBall
  if nativeMarker then
    battle.drawCaughtBall = function(self, ...)
      nativeCalls = nativeCalls + 1
      return nativeMarker(self, ...)
    end
  end
  local restoredMarker = battle.drawCaughtBall
  local markerOwner = suiteOptions and "modern_ui_suite" or "battle_info_hud"
  local markerImage = Assets.image("save/mod-derived/" .. markerOwner .. "/battle/caught_ball.png")
  local graphicsDraw, battleDraw = love.graphics.draw, battle.draw
  love.graphics.draw = function(image, ...)
    if image == markerImage then markerCalls = markerCalls + 1 end
    return graphicsDraw(image, ...)
  end
  battle.draw = function(self, ...)
    nativeCalls, markerCalls = 0, 0
    return battleDraw(self, ...)
  end
  local function shot(label, expectedRows)
    rowCalls = 0
    U.wait(3)
    check(not love.window.hasFocus(), label .. " background")
    check(love.audio.getVolume() == 0, label .. " muted")
    check(U.shot(game, out .. "/" .. label .. ".png"), label .. " captured")
    check((rowCalls > 0) == expectedRows, label .. " party-row calls: " .. rowCalls)
  end
  shot("wild-owned-classic", baseline)
  if not baseline then
    local kanto = game.mods.exports.kanto_gear ~= nil
    if kanto then check(battle:caughtMarkerVisible(), "Kanto Gear enables the native caught marker") end
    local function markerPixels()
      local canvas = game.renderer.canvas
      local pixels = canvas:newImageData()
      local x = math.floor((canvas:getWidth()-160)/2) + 8 + Font.width(battle.enemy.name)
      local values = {}
      for y=0,7 do for px=x,x+11 do
        local r,g,b,a = pixels:getPixel(px,y)
        values[#values+1] = ("%d,%d,%d,%d"):format(
          math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5),math.floor(a*255+.5))
      end end
      return table.concat(values,";")
    end
    for _, species in ipairs({"MANKEY","SANDSHREW"}) do
      -- Keep the live battler so this exercises the whole renderer/companion chain.
      battle.enemy.name, battle.enemy.mon.species = species, species
      game.save.pokedex.owned[species] = true
      local fullPixels
      for _, hp in ipairs({{"full",100},{"medium",35},{"low",10}}) do
        battle.enemy.mon.stats.hp = 100
        battle.enemy.mon.hp, battle.enemy.shownHP, battle.enemy.shownPx = hp[2],hp[2],nil
        shot(species:lower() .. "-" .. hp[1], false)
        check(markerCalls == 1, "exactly one HUD marker draw per frame")
        check(nativeCalls == (previous and kanto and 1 or 0), "no overlapping native marker")
        check(battle.drawCaughtBall == restoredMarker, "native marker method restored after drawing")
        local pixels = markerPixels()
        if fullPixels then
          check((pixels == fullPixels) ~= previous, "marker pixels independent of enemy HP")
        else fullPixels = pixels end
      end
    end
    battle.enemy.mon.hp, battle.enemy.shownHP = 100,100
  end
  game.save.pokedex.owned.SANDSHREW = nil
  shot("wild-unowned-classic", false)
  game.save.pokedex.owned.SANDSHREW = true
  game.save.options.battleLayout = "wide"
  shot("wild-owned-wide", baseline)
  game.save.options.battleLayout = "og"
  battle.fx = {hudShakeX=2}
  shot("wild-owned-shaking", baseline)
  battle.fx = nil
  -- Draw both trainer intro rows with healthy, status, fainted and empty slots.
  battle.kind, battle.introBalls = "trainer", true
  battle.enemyParty = {Pokemon.new(game.data, "SANDSHREW", 6),
    Pokemon.new(game.data, "RATTATA", 6), Pokemon.new(game.data, "PIDGEY", 6)}
  battle.enemyParty[2].status, battle.enemyParty[3].hp = "PSN", 0
  battle.showPlayerBack = true
  shot("trainer-intro", true)
  battle.introBalls, battle.showPlayerBack = nil, false
  shot("trainer-active", false)
  love.graphics.draw = graphicsDraw
  print("[CAUGHT MARKER] PASS " .. checks .. " checks; baseline=" .. tostring(baseline))
end
