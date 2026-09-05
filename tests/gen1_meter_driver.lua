-- Real Gen 1 battle, native renderer or unmodified Battle Art release.
return function(game)
  local U = dofile(assert(os.getenv("PC_REPO")) .. "/tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local Pokemon = require("src.pokemon.Pokemon")
  local Growth = require("src.pokemon.Growth")
  local PaletteFX = require("src.render.PaletteFX")
  local out = assert(os.getenv("SHOT_DIR"))
  local voxel = os.getenv("METER_VOXEL") == "1"
  local options = game.mods.modOptions.modern_ui_suite
  local genderHud = assert(game.mods.exports.gender_mod.BattleHUD)
  local genderCells = { ink = {}, color = {} }
  for method, pass in pairs({ drawGlyphInk = "ink", drawGlyph = "color" }) do
    local original = genderHud[method]
    genderHud[method] = function(Gender, gender, x, y, ...)
      genderCells[pass][x .. "," .. y] = true
      return original(Gender, gender, x, y, ...)
    end
  end
  local checks = 0
  local function check(ok, message)
    assert(ok, "METER QA: " .. message)
    checks = checks + 1
  end
  local function shot(name)
    U.wait(3)
    check(not love.window.hasFocus(), name .. " background")
    check(love.audio.getVolume() == 0, name .. " muted")
    check(U.shot(game, out .. "/" .. name .. ".png"), name .. " screenshot")
  end
  local function saveCanvas(canvas, name)
    local data = canvas:newImageData()
    local bytes = data:encode("png")
    local file = assert(io.open(out .. "/" .. name .. ".png", "wb"))
    file:write(bytes:getString()); file:close()
    return data
  end
  local function captureHUD(battle, draw)
    local g = love.graphics
    local previous = g.getCanvas()
    local canvas = g.newCanvas(160,144)
    g.push("all"); g.setCanvas(canvas); g.origin(); g.setShader(); g.setScissor()
    g.clear(0,0,0,0)
    if draw then draw() else battle:drawHUDs(0) end
    g.pop(); g.setCanvas(previous)
    return canvas:newImageData()
  end
  local function regionHasInk(pixels, left, top, width, height)
    for y=top,top+height-1 do for x=left,left+width-1 do
      local _,_,_,a = pixels:getPixel(x,y)
      if a > 0.01 then return true end
    end end
    return false
  end
  local function checkNoOldCaps(pixels, label)
    check(not regionHasInk(pixels,144,73,9,7), label .. " has no old player HP cap or shadow")
    check(not regionHasInk(pixels,80,17,9,7), label .. " has no old enemy HP cap or shadow")
    check(regionHasInk(pixels,144,81,9,14), label .. " retains the player's lower bracket")
  end
  love.window.setMode(1280, 960, {resizable=true})
  print("[METER QA] renderer", love.graphics.getRendererInfo())
  game.save.options.colors, game.save.options.battleLayout = "redpp", "og"
  PaletteFX.setMode("redpp")
  options["battle_hud.enabled"], options["move_colors.enabled"] = true, false
  local mon = Pokemon.new(game.data, "IVYSAUR", 28)
  mon.dvs.attack = 15
  mon.stats.hp, mon.hp = 83, 69
  mon.exp = Growth.expForLevel(game.data.pokemon.IVYSAUR.growthRate, 28, game.data.growth_rates) + 188
  mon.moves = {{id="TACKLE", pp=35}, {id="POISONPOWDER", pp=35},
    {id="LEECH_SEED", pp=10}, {id="RAZOR_LEAF", pp=24}}
  game.save.party = {mon, Pokemon.new(game.data, "PIDGEY", 12)}
  game.save.pokedex = {owned={SANDSHREW=true},seen={SANDSHREW=true}}
  U.teleport(game, "ROUTE_1", 5, 5, "down")
  local battle = BattleState.newWild(game, "SANDSHREW", 6, {onFinish=function() end})
  game.overworld:pushBattle(battle)
  for _ = 1, 600 do
    if battle.phase == "menu" then break end
    U.tap(game, "a")
  end
  check(battle.phase == "menu", "real battle reaches command menu")
  local api, staged
  if voxel then
    api = assert(game.mods.exports.BATTLE_ART_VOXEL_FORK)
    check(api.version == "1.10.1", "actual release loaded")
    staged = api.lib.require("OverworldBattle")
    for _ = 1, 120 do
      if staged.shot() and staged.shot().canvas then break end
      U.wait(1)
    end
    check(staged.shot() and staged.shot().canvas, "real 3D scene ready")
  end
  shot("classic-commands")
  checkNoOldCaps(captureHUD(battle), "in-frame HUD")
  local HudTiles = require("src.render.HudTiles")
  local outsideBattle = captureHUD(battle, function()
    HudTiles.drawHPBar(game.data,10,9,mon,1,false)
  end)
  check(regionHasInk(outsideBattle,144,73,8,7), "other native HP bars still draw outside the replacement pass")
  for _, cell in ipairs({"24,8", "104,64"}) do
    check(genderCells.ink[cell] and genderCells.color[cell],
      "gender ink and colour use the same native cell " .. cell)
  end
  check(not genderCells.color["25,8"] and not genderCells.color["105,64"],
    "gender overlay leaves no one-pixel duplicate edge")
  battle.phase = "moveSelect"
  shot("classic-moves")
  options["move_colors.enabled"] = true
  shot("suite-moves")
  battle.phase = "menu"
  for _, size in ipairs({{"wide",1280,720}, {"portrait",480,900}, {"compact",320,288}}) do
    love.window.setMode(size[2],size[3],{resizable=true})
    shot(size[1] .. "-commands")
    battle.phase = "moveSelect"
    shot(size[1] .. "-moves")
    battle.phase = "menu"
  end
  love.window.setMode(1280,720,{resizable=true})
  for _, hp in ipairs({40,12,1,0,69}) do
    battle.player.shownHP = hp
    shot("hp-" .. hp)
    check(mon.hp == 69 and mon.stats.hp == 83, "displayed HP does not mutate real HP")
  end
  options["battle_hud.enabled"] = false
  shot("hud-off")
  check(regionHasInk(captureHUD(battle),144,73,9,7), "HUD OFF restores the native HP end cap")
  options["battle_hud.enabled"] = true
  shot("hud-restored")
  if not voxel then
    game.save.options.battleLayout = "wide"
    shot("engine-wide")
    battle.player.shownStatus, battle.enemy.shownStatus = "PSN", "PAR"
    battle.player.mon.status, battle.enemy.mon.status = "PSN", "PAR"
    shot("engine-wide-status")
    battle.player.shownStatus, battle.enemy.shownStatus = nil,nil
    battle.player.mon.status, battle.enemy.mon.status = nil,nil
  else
    check(staged.shot() and staged.shot().canvas, "3D scene remains active")
    check(staged.HUD_RECT.player[1] == 72 and staged.HUD_RECT.player[2] == 56
      and staged.HUD_RECT.player[3] == 88 and staged.HUD_RECT.player[4] == 40,
      "native player HUD rectangle preserved")
    local backplates = api.lib.require("UiBackplates")
    for _, mode in ipairs({1,2}) do
      backplates.hudColor:setIndex(mode, game)
      shot(mode == 1 and "color-hud" or "inverted-hud")
      if mode == 2 then
        local canvas = game.renderer.canvas
        local pixels = canvas:newImageData()
        local ox = math.floor((canvas:getWidth() - 160) / 2)
        for _, y in ipairs({74,82}) do
          local r,g,b,a = pixels:getPixel(81+ox,y)
          check(r > 0.95 and g > 0.95 and b > 0.95 and a > 0.95,
            "native fallback HP/XP labels retain white ink after the zone pass")
        end
      end
      -- Exercise the actual snapped texture/compositor even on a host where
      -- Battle Art selects its in-frame fallback (Apple OpenGL ES / Metal).
      local layer = assert(staged.hudTexture(battle,0,true,mode == 1,true))
      local pixels = saveCanvas(layer, "captured-hud-" .. mode)
      checkNoOldCaps(pixels, "captured HUD ink mode " .. mode)
      local blueGender = 0
      for y=64,71 do for x=104,111 do
        local r,g,b,a = pixels:getPixel(x,y)
        if b > 0.8 and r < 0.4 and a > 0.9 then blueGender = blueGender + 1 end
      end end
      -- Force male fixture below, so the captured colour must occupy the
      -- exact same cell that received the in-frame ink stamp.
      check(blueGender > 10, "captured gender artwork remains in its native cell")
      local r,g,b,a = pixels:getPixel(97,82)
      check(b > 0.7 and r < 0.3 and a > 0.9, "captured EXP pixels stay blue in either ink mode")
      local white = 0
      for y=82,86 do for x=110,141 do
        local r,g,b,a = pixels:getPixel(x,y)
        if r > 0.95 and g > 0.95 and b > 0.95 and a > 0.95 then white=white+1 end
      end end
      check(white > 25, "white EXP readout is inside the captured bar")
      for _, scale in ipairs({1,2}) do
        staged.hudScaleSetting:setIndex(scale,game)
        check(staged.snapHUDs(battle,staged.shot()), "real released compositor accepts compact HUD")
        saveCanvas(staged.shot().canvas, "snapped-scene-" .. mode .. "-" .. scale)
        -- Once the provider has placed both HUDs in the world, the UI draw
        -- must stay empty instead of adding a second pair of compact bars.
        local g = love.graphics
        local previous = g.getCanvas()
        local ui = g.newCanvas(160,144)
        g.push("all"); g.setCanvas(ui); g.origin(); g.clear(0,0,0,0)
        battle:drawHUDs(0)
        g.pop(); g.setCanvas(previous)
        local r,g,b,a = ui:newImageData():getPixel(97,82)
        check(not (b > 0.7 and r < 0.3 and a > 0.9), "snapped HUD leaves no duplicate in-frame EXP")
      end
    end
    options["battle_hud.enabled"] = false
    local off = assert(staged.hudTexture(battle,0,true,true,true)):newImageData()
    local r,g,b,a = off:getPixel(97,82)
    check(not (b > 0.7 and r < 0.3 and a > 0.9), "turning HUD off removes captured EXP too")
    options["battle_hud.enabled"] = true
    battle.blankForAskName, battle.result = true, "caught"
    local hidden = assert(staged.hudTexture(battle,0,true,true,true)):newImageData()
    local r,g,b,a = hidden:getPixel(97,82)
    check(not (b > 0.7 and r < 0.3 and a > 0.9), "catch/nickname phase draws no stray meter")
    battle.blankForAskName, battle.result = nil,nil
    battle.player.shownStatus, battle.enemy.shownStatus = "PSN", "PAR"
    battle.player.mon.status, battle.enemy.mon.status = "PSN", "PAR"
    shot("inverted-status")
    battle.player.shownStatus, battle.enemy.shownStatus = nil,nil
    battle.player.mon.status, battle.enemy.mon.status = nil,nil
    shot("final-3d")
  end
  print("[METER QA] PASS " .. checks .. " checks")
end
