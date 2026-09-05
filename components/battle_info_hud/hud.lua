return function(mod)
  local Font = require("src.render.Font")
  local Meters = mod:load("meters.lua")()
  local HudTiles = require("src.render.HudTiles")
  local PaletteFX = require("src.render.PaletteFX")
  local BattleState = require("src.battle.BattleState")
  local WideBattle = require("src.battle.WideBattle")

  local exposedStatuses = setmetatable({}, { __mode = "k" })
  local CAUGHT_ROW = { { hp = 1 } }
  local GENDER_MOD_ID = "gender_mod"
  local CRYSTAL_251_MOD_ID = "CRYSTAL_251"
  local STAGED_GENDER_SCRATCH_X = 0
  local STAGED_GENDER_SCRATCH_Y = 87
  local STAGED_GENDER_CAPTURE_SIZE = 9
  local stagedGenderCaptureDepth = 0
  local nativeStagedHudDepth = 0
  local nativeStagedOverlayDepth = 0
  local genderBattleDrawDepth = 0
  local genderBattleContext
  local nativeStagedHudOwner = false
  local nativeStagedInk
  local nativeStagedTextPass
  local nativeStagedSuppressed
  local nativeStagedSnapped = setmetatable({}, { __mode = "k" })
  local STAGED_COMPANIONS = {
    "DRAMATIC_SHAPE",
    "BATTLE_ART_VOXEL_FORK",
    "DRAMALESS_SHAPE",
  }

  -- Packaged mobile builds intentionally omit Lua's optional debug library.
  -- Keep protected cleanup useful in development without making battle entry
  -- depend on an API that is unavailable on iOS and other release targets.
  local function traceback(err)
    local library = rawget(_G, "debug")
    if type(library) == "table"
        and type(library.traceback) == "function" then
      return library.traceback(err, 2)
    end
    return tostring(err)
  end

  local function setting()
    local ok, value = pcall(mod.options.get, mod.options, "enabled")
    return not ok or value == nil or value == true
  end

  local function wideLayout(battle)
    if not (battle and type(battle.wideLayout) == "function") then
      return false
    end
    local ok, wide = pcall(battle.wideLayout, battle)
    return ok and wide == true
  end

  -- Dramatic Shape pins its staged renderer to the original 160x144 battle
  -- surface. These are the compatibility signals exposed by its live shot.
  local function stagedLayout(battle)
    return battle and (rawget(battle, "dramaticShapeShot") ~= nil
      or battle.letterboxWhite == false) or false
  end

  local function fitName(value, pixels)
    local text = tostring(value or "")
    if Font.width(text) <= pixels then return text end
    while #text > 0 and Font.width(text .. ".") > pixels do
      text = text:sub(1, -2)
    end
    return text .. "."
  end

  local function statusText(battle, battler)
    local status = battler
      and (battler.shownStatus or exposedStatuses[battler])
    if not status then return nil end
    if type(battle.statusLabel) == "function" then
      local ok, label = pcall(battle.statusLabel, battle, { status = status })
      if ok and label then return tostring(label) end
    end
    return tostring(status)
  end

  local function isCaught(battle, battler)
    if battle.kind ~= "wild" then return false end
    local owned = battle.game and battle.game.save
      and battle.game.save.pokedex and battle.game.save.pokedex.owned
    local species = battler and battler.mon and battler.mon.species
    return species ~= nil and owned and owned[species] == true or false
  end

  local function drawCaughtBall(battle, x, y)
    if type(battle.drawBallRow) ~= "function" then return end
    local g = love.graphics
    local sx, sy, sw, sh = g.getScissor()
    g.setScissor(x, y, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
    battle:drawBallRow(CAUGHT_ROW, x, y, 8)
    if sx then g.setScissor(sx, sy, sw, sh) else g.setScissor() end
  end

  local function drawPlayerMeters(battle, ink, markColor, dx, dy)
    dx, dy = dx or 0, dy or 0
    Meters.draw(battle.data, battle.player, "HP", 96 + dx, 73 + dy, 48, true, ink, markColor)
    Meters.draw(battle.data, battle.player, "XP", 96 + dx, 81 + dy, 48, true, ink, markColor)
  end

  local function drawEnemyMeter(battle, ink, markColor, dx, dy)
    Meters.draw(battle.data, battle.enemy, "HP", 32 + (dx or 0), 17 + (dy or 0), 48, false, ink, markColor)
  end

  local function hudVisible(battle)
    if not battle or battle.blankForAskName or battle.result == "caught" then return false end
    return type(battle.statusHUDVisible) ~= "function" or battle:statusHUDVisible() ~= false
  end

  local function enemyVisible(battle)
    if not hudVisible(battle) then return false end
    local enemy = battle.enemy
    if not enemy or battle.showEnemyTrainer or battle.enemySendingOut
        or battle.introBalls or enemy.fainted then return false end
    if type(battle.growInScale) == "function" then
      local ok, scale = pcall(battle.growInScale, battle, enemy)
      if ok and scale then return false end
    end
    return true
  end

  local function playerVisible(battle)
    return hudVisible(battle) and battle.player ~= nil and not battle.safari and not battle.demo
      and not battle.showPlayerBack
  end

  -- The native HP bar includes a separate right-cap tile beyond its six
  -- fill tiles. Omit the whole bar while building a replacement HUD, before
  -- Battle Art can also give that cap a shadow. This scope leaves the level,
  -- bracket, other screens and the HUD-disabled presentation untouched.
  local function withoutNativeHPBars(battle, slide, draw)
    if not setting() or slide ~= 0 or battle.introBalls
        or (battle.introSlide or 0) > 0 then return draw() end
    local tile = HudTiles.tile
    HudTiles.tile = function(code, x, y, ...)
      local barTile = code == 0x71 or (code >= 0x62 and code <= 0x6D)
      if barTile and ((playerVisible(battle) and y == 72 and x >= 80 and x < 152)
          or (enemyVisible(battle) and y == 16 and x >= 16 and x < 88)) then
        return
      end
      return tile(code, x, y, ...)
    end
    local result
    local ok, err = xpcall(function() result = draw() end, traceback)
    HudTiles.tile = tile
    if not ok then error(err, 0) end
    return result
  end

  -- The internal SGB zone pass recolors the native HUD before sprites and
  -- dialogue are drawn. Restore the complete meters here, including the white
  -- readout, so palette conversion cannot turn the EXP fill gray or erase text.
  local function drawClassicMeters(battle, sx, sy)
    local g = love.graphics
    g.push("all")
    sx, sy = sx or 0, sy or 0
    local ink = stagedLayout(battle) and nativeStagedInk and nativeStagedInk() or nil
    if enemyVisible(battle) then
      drawEnemyMeter(battle, ink, nil, sx + (battle.fx and battle.fx.hudShakeX or 0), sy)
    end
    if playerVisible(battle) then drawPlayerMeters(battle, ink, nil, sx, sy) end
    g.pop()
  end

  local function layoutFor(battle)
    if not setting() or not battle or battle.blankForAskName
        or (battle.introSlide or 0) > 0 then return nil end
    if wideLayout(battle) then return "wide" end
    if stagedLayout(battle) then return "staged" end
    return nil
  end

  local function drawStatusAt(battle, battler, x, y, ink)
    local text = statusText(battle, battler)
    if not text then return end
    love.graphics.setColor(unpack(ink or {0, 0, 0, 1}))
    Font.draw(text, x, y)
  end

  local function drawStatusAfterLevel(battle, battler, levelValueX, y,
      rightEdge, ink)
    local text = statusText(battle, battler)
    if not text then return end
    local x = levelValueX + Font.width(tostring(battler.mon.level)) + 4
    if rightEdge then x = math.min(x, rightEdge - Font.width(text)) end
    love.graphics.setColor(unpack(ink or {0, 0, 0, 1}))
    Font.draw(text, x, y)
  end

  local function drawLevel(battler, x, y)
    HudTiles.tile(0x6E, x, y)
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(tostring(battler.mon.level), x + 8, y)
  end

  local function nameX(tx, name)
    local count = #Font.split(name or "")
    return tx * 8 + (count <= 2 and 16 or count <= 4 and 8 or 0)
  end

  local function caughtBallX(name, x, maxNamePixels)
    local label = maxNamePixels and fitName(name, maxNamePixels)
      or tostring(name or "")
    return x + Font.width(label) + 2
  end

  local function drawPlayerUnderline(y)
    HudTiles.tile(0x73, 144, y - 8)
    HudTiles.tile(0x77, 144, y)
    for i = 10, 17 do HudTiles.tile(0x76, i * 8, y) end
    HudTiles.tile(0x6F, 72, y)
  end

  -- Both meters fit in the stock HP and numeric rows. Names, levels and the
  -- lower bracket keep the original coordinates in classic and staged battles.
  local function drawStagedPlayerHud(battle, markColor)
    local battler = battle.player
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(fitName(battler.name, 64), 80, 56)
    drawStatusAt(battle, battler, 80, 64)
    drawLevel(battler, 112, 64)
    drawPlayerUnderline(88)
    drawPlayerMeters(battle, nil, markColor)
  end

  local function clearStagedPlayerHud()
    local g = love.graphics
    if type(g.setBlendMode) == "function" then
      g.setBlendMode("replace", "premultiplied")
    end
    g.setColor(0, 0, 0, 0)
    g.rectangle("fill", 56, 48, 104, 48)
    if type(g.setBlendMode) == "function" then g.setBlendMode("alpha") end
  end

  -- These coordinates are the engine's original 160x144 HUD coordinates.
  -- This function is called while Dramatic Shape's native HUD texture is the
  -- active canvas, before that texture is snapped to the window edges.
  local function drawStagedHudContent(battle, alreadyCleared, markColor,
      preserveNative)
    local ink = preserveNative and stagedLayout(battle)
      and nativeStagedInk and nativeStagedInk() or nil
    if enemyVisible(battle) then
      love.graphics.push()
      love.graphics.translate(battle.fx and battle.fx.hudShakeX or 0, 0)
      local g = love.graphics
      g.push("all")
      g.setBlendMode("replace", "premultiplied")
      g.setColor(0, 0, 0, 0)
      g.rectangle("fill", 16, 16, 72, 8)
      g.pop()
      drawEnemyMeter(battle, ink, markColor)
      love.graphics.pop()
    end
    if playerVisible(battle) then
      if preserveNative then
        -- Keep the provider's name, level, gender stamp and bracket intact.
        -- Repainting them after Battle Art's ink pass loses its contrast and
        -- leaves the coloured gender overlay misaligned with its ink stamp.
        local g = love.graphics
        g.push("all")
        g.setBlendMode("replace", "premultiplied")
        g.setColor(0, 0, 0, 0)
        g.rectangle("fill", 80, 72, 64, 17)
        g.pop()
        drawPlayerMeters(battle, ink, markColor)
      else
        if not alreadyCleared then clearStagedPlayerHud() end
        drawStagedPlayerHud(battle, markColor)
      end
    end
    local function extras()
      if enemyVisible(battle) then
        love.graphics.push()
        love.graphics.translate(battle.fx and battle.fx.hudShakeX or 0, 0)
        drawStatusAfterLevel(battle, battle.enemy, 40, 8, 88)
        if isCaught(battle, battle.enemy) then
          local x = nameX(1, battle.enemy.name)
          drawCaughtBall(battle, caughtBallX(battle.enemy.name, x), 0)
        end
        love.graphics.pop()
      end
      if preserveNative and playerVisible(battle) then
        drawStatusAt(battle, battle.player, 80, 64)
      end
    end
    if preserveNative and stagedLayout(battle) and nativeStagedTextPass then
      nativeStagedTextPass(extras)
    else extras() end
  end

  local function renderWide(battle)
    local fx = battle.fx
    if fx and fx.flash and fx.flash > 0
        and (battle.frame or 0) % 4 < 2 then return end

    local sx = (fx and fx.shakeX) or 0
    local sy = (fx and fx.shakeY) or 0
    if sx == 0 and sy == 0 and fx and fx.shake and fx.shake > 0 then
      sx = (battle.frame or 0) % 4 < 2 and 2 or -2
    end
    love.graphics.push("all")
    if sx ~= 0 or sy ~= 0 then love.graphics.translate(sx, sy) end

    if enemyVisible(battle) then
      local hudShake = (fx and fx.hudShakeX) or 0
      if hudShake ~= 0 then
        love.graphics.push()
        love.graphics.translate(hudShake, 0)
      end
      local battler = battle.enemy
      local enemyName = fitName(battler.name, 48)
      love.graphics.setColor(0, 0, 0, 1)
      Font.drawBox(0, 0, 18, 4)
      Font.draw(enemyName, 8, 8)
      drawLevel(battler, 88, 8)
      drawStatusAfterLevel(battle, battler, 96, 8, 144)
      Meters.draw(battle.data, battle.enemy, "HP", 24, 17, 104, false)
      if isCaught(battle, battle.enemy) then
        drawCaughtBall(battle, caughtBallX(enemyName, 8), 8)
      end
      if hudShake ~= 0 then love.graphics.pop() end
    end

    if playerVisible(battle) then
      local battler = battle.player
      love.graphics.setColor(0, 0, 0, 1)
      Font.drawBox(23, 7, 15, 5)
      Font.draw(fitName(battler.name, statusText(battle, battler) and 32 or 40), 192, 64)
      drawStatusAt(battle, battler, 232, 64)
      drawLevel(battler, 264, 64)
      Meters.draw(battle.data, battler, "HP", 208, 73, 80, true)
      Meters.draw(battle.data, battler, "XP", 208, 81, 80, true)
    end
    love.graphics.pop()
  end

  -- Draw-time presentation shim: while the engine paints its own HUD, expose
  -- the native level instead of the mutually-exclusive status label. The
  -- matching renderer then adds that saved status just to the left. No panel
  -- pixels are cleared or replaced, preserving the frosted background.
  local function withNativeLevels(battle, shortenNames, draw)
    local restores = {}
    local result
    local function expose(battler, nameWidth)
      if not (battler and battler.shownStatus) then return end
      restores[#restores + 1] = {
        battler = battler,
        status = battler.shownStatus,
        name = battler.name,
      }
      exposedStatuses[battler] = battler.shownStatus
      battler.shownStatus = nil
      if nameWidth then battler.name = fitName(battler.name, nameWidth) end
    end

    expose(battle.enemy, shortenNames and 48 or nil)
    expose(battle.player, shortenNames and 40 or nil)

    local ok, err = xpcall(function() result = draw() end, traceback)
    for i = #restores, 1, -1 do
      local item = restores[i]
      item.battler.shownStatus = item.status
      item.battler.name = item.name
      exposedStatuses[item.battler] = nil
    end
    if not ok then error(err, 0) end
    return result
  end

  local originalWideDraw = WideBattle.draw
  WideBattle.draw = function(battle, ...)
    local args = { ... }
    if not setting() then return originalWideDraw(battle, unpack(args)) end
    return withNativeLevels(battle, true, function()
      return originalWideDraw(battle, unpack(args))
    end)
  end

  -- In the normal 160x144 renderer the battle sprites and native HUD share
  -- one canvas. Render the native HUD into a transparent 160x144 layer first,
  -- edit that layer in place, then composite it where the original draw would
  -- have happened. This keeps the game's own tiles and drawing order without
  -- clearing holes through the battlefield underneath the player panel.
  local originalClassicDrawHUDs = BattleState.drawHUDs
  local classicHudLayer

  local function getClassicHudLayer()
    local g = love.graphics
    if classicHudLayer then return classicHudLayer end
    if type(g.newCanvas) ~= "function" then return nil end
    local ok, layer = pcall(g.newCanvas, 160, 144)
    if not ok or not layer then return nil end
    if type(layer.setFilter) == "function" then
      layer:setFilter("nearest", "nearest")
    end
    classicHudLayer = layer
    return classicHudLayer
  end

  local function classicEnhancementActive(battle, slide)
    return setting() and battle and slide == 0
      and not battle.blankForAskName
      and (battle.introSlide or 0) <= 0
      and not battle.introBalls
      and not wideLayout(battle)
      and (not stagedLayout(battle) or (nativeStagedHudOwner
        and not nativeStagedSnapped[battle]
        and not (nativeStagedSuppressed and nativeStagedSuppressed(battle))
        and nativeStagedHudDepth == 0 and stagedGenderCaptureDepth == 0))
  end

  local function drawClassicHud(battle, slide, args)
    local g = love.graphics
    if type(g.getCanvas) ~= "function" or type(g.setCanvas) ~= "function"
        or type(g.clear) ~= "function" or type(g.draw) ~= "function" then
      return originalClassicDrawHUDs(battle, slide, unpack(args))
    end
    local layer = getClassicHudLayer()
    if not layer then
      return originalClassicDrawHUDs(battle, slide, unpack(args))
    end

    local previous = g.getCanvas()
    local result
    local pushed = false
    local ok, err = xpcall(function()
      g.push("all")
      pushed = true
      g.setCanvas(layer)
      g.clear(0, 0, 0, 0)
      result = withNativeLevels(battle, false, function()
        local nativeResult = withoutNativeHPBars(battle, slide, function()
          return originalClassicDrawHUDs(battle, slide, unpack(args))
        end)
        drawStagedHudContent(battle, false, true, true)
        return nativeResult
      end)
      g.pop()
      pushed = false
      if previous then g.setCanvas(previous) else g.setCanvas() end

      g.push("all")
      pushed = true
      g.setColor(1, 1, 1, 1)
      g.draw(layer, 0, 0)
      g.pop()
      pushed = false
    end, traceback)

    if pushed then pcall(g.pop) end
    if previous then g.setCanvas(previous) else g.setCanvas() end
    if not ok then error(err, 0) end
    return result
  end

  BattleState.drawHUDs = function(battle, slide, ...)
    local args = { ... }
    if not classicEnhancementActive(battle, slide) then
      return originalClassicDrawHUDs(battle, slide, unpack(args))
    end
    return drawClassicHud(battle, slide, args)
  end

  local originalClassicZonePass = BattleState.drawZonePass
  BattleState.drawZonePass = function(battle, src, sx, sy, ...)
    local result = originalClassicZonePass(battle, src, sx, sy, ...)
    if classicEnhancementActive(battle, 0) and not stagedLayout(battle) then
      drawClassicMeters(battle, sx, sy)
    end
    return result
  end

  local function genderCompatibility(game)
    local exports = game and game.mods and game.mods.exports
    local api = exports and exports[GENDER_MOD_ID]
    local hud = api and api.BattleHUD
    if type(hud) ~= "table" then return nil, nil end
    return api, hud
  end

  local function crystalGenderCompatibility(game)
    local exports = game and game.mods and game.mods.exports
    local api = exports and exports[CRYSTAL_251_MOD_ID]
    local gender = api and api.crystalGender
    if type(gender) ~= "table"
        or type(gender.forMon) ~= "function" then
      return nil
    end
    return gender
  end

  -- Crystal 251 already knows the gender ratios of all Johto species and
  -- publishes the resolved M/F value on its compatibility API. Gender Mod
  -- 0.3.5 only ships Kanto ratios, however, so it paints its black unknown
  -- tile for SENTRET while Crystal independently appends another monochrome
  -- sign after the level. When both providers are present, let Gender Mod
  -- retain ownership of its Kanto cells and use its same authored artwork for
  -- Crystal-only species. Crystal's text-tracking renderer is then redundant.
  local function installCrystalGenderBridge(game, genderApi, hud)
    local crystal = crystalGenderCompatibility(game)
    local ratios = genderApi and genderApi.ratios
    if not (crystal and type(ratios) == "table" and hud) then return end

    local function crystalOnlyGender(battler)
      local mon = battler and battler.mon
      if type(mon) ~= "table" or ratios[mon.species] ~= nil then return nil end
      local ok, value = pcall(crystal.forMon, mon)
      if not ok or (value ~= "M" and value ~= "F") then return nil end
      return value
    end

    if not crystal.battleInfoHudTrackingBridgeV1
        and type(crystal.withBattleHudTracking) == "function" then
      local originalTracking = crystal.withBattleHudTracking
      crystal.withBattleHudTracking = function(battle, draw, ...)
        local activeGenderApi = genderCompatibility(battle and battle.game)
        -- Gender Mod and Crystal 251 are alternative presentation providers.
        -- Let Gender Mod remain the single owner even when this component's
        -- own HUD decoration is disabled; returning Crystal's text marker in
        -- that state produces the overlapping before/after-level pair.
        if activeGenderApi and type(draw) == "function" then
          return draw(...)
        end
        return originalTracking(battle, draw, ...)
      end
      crystal.battleInfoHudTrackingBridgeV1 = true
    end

    if hud.battleInfoHudCrystal251GenderV1 then return end

    local originalClassic = hud.drawClassicIntoHUDs
    if type(originalClassic) == "function"
        and type(hud.drawHudGlyph) == "function" then
      hud.drawClassicIntoHUDs = function(battle, slide, Gender, _, imageSlot)
        local result = originalClassic(battle, slide, Gender, ratios,
          imageSlot)
        local images = type(imageSlot) == "table"
          and (imageSlot.images or imageSlot) or nil
        local function drawSide(side, visible)
          local battler = battle and battle[side]
          local value = visible and crystalOnlyGender(battler) or nil
          if not value then return end
          local level = battler.mon and battler.mon.level or 1
          local x, y = hud.classicGenderXY(side, level)
          hud.drawHudGlyph(Gender, value, x, y, images, imageSlot, battle)
        end
        drawSide("enemy", type(hud.enemyHudVisible) ~= "function"
          or hud.enemyHudVisible(battle, slide))
        drawSide("player", type(hud.playerHudVisible) ~= "function"
          or hud.playerHudVisible(battle, slide))
        return result
      end
    end

    local originalOverlay = hud.drawOverlay
    if type(originalOverlay) == "function"
        and type(hud.drawGlyph) == "function" then
      hud.drawOverlay = function(battle, Gender, _, imageSlot)
        local result = originalOverlay(battle, Gender, ratios, imageSlot)
        if battle and battle.dramaticShapeShot
            and type(hud.hudDrawnInFrame) == "function"
            and not hud.hudDrawnInFrame(battle) then
          return result
        end

        local wide = wideLayout(battle)
        local images = type(imageSlot) == "table"
          and (imageSlot.images or imageSlot) or nil
        local tint = type(imageSlot) == "table" and imageSlot.tint == true
        local shakeX, shakeY = 0, 0
        if type(hud.screenShakeXY) == "function" then
          shakeX, shakeY = hud.screenShakeXY(battle)
        end
        local g = love and love.graphics
        local renderer = battle and battle.game and battle.game.renderer
        local uiCanvas = renderer and renderer.canvas
        local previousCanvas = g and g.getCanvas and g.getCanvas() or nil
        local pushedCanvas = false
        if g and uiCanvas and g.setCanvas then
          local ok = pcall(g.push, "all")
          if not ok then g.push() end
          pushedCanvas = true
          g.setCanvas(uiCanvas)
          if g.origin then g.origin() end
        end

        local function drawSide(side, visible)
          local battler = battle and battle[side]
          local value = visible and crystalOnlyGender(battler) or nil
          if not value then return end
          local level = battler.mon and battler.mon.level or 1
          local x, y
          if wide and type(hud.wideGenderXY) == "function" then
            x, y = hud.wideGenderXY(side, level)
          else
            x, y = hud.classicGenderXY(side, level)
          end
          local extraX = side == "enemy"
            and battle.fx and battle.fx.hudShakeX or 0
          local dx, dy = shakeX + (extraX or 0), shakeY
          if dx ~= 0 or dy ~= 0 then
            g.push()
            g.translate(dx, dy)
          end
          hud.drawGlyph(Gender, value, x, y, images, true, tint)
          if dx ~= 0 or dy ~= 0 then g.pop() end
        end
        local slide = 0
        if battle then
          local ok, Timing = pcall(require, "src.core.Timing")
          slide = (battle.introSlide or 0)
            * (ok and Timing.BATTLE_SLIDE_PX_PER_FRAME or 2)
        end
        drawSide("enemy", type(hud.enemyHudVisible) ~= "function"
          or hud.enemyHudVisible(battle, slide))
        drawSide("player", type(hud.playerHudVisible) ~= "function"
          or hud.playerHudVisible(battle, slide))

        if g then g.setColor(1, 1, 1, 1) end
        if pushedCanvas then
          g.pop()
          if previousCanvas then g.setCanvas(previousCanvas)
          else g.setCanvas() end
        end
        return result
      end
    end

    hud.battleInfoHudCrystal251GenderV1 = true
    mod.log:info("unified Crystal 251 and Gender Mod battle markers")
  end

  -- Keep Gender Mod on the stock y=64 player level row in every layout. Its
  -- overlay also normally hides the glyph whenever a status is present;
  -- expose the level slot just for that draw because our layout shows both.
  local function installNeutralGenderGuard(hud)
    if hud.battleInfoHudSuppressNeutralBattleGlyphV1 then return end

    local function wrapGlyph(name)
      local original = hud[name]
      if type(original) ~= "function" then return end
      hud[name] = function(Gender, gender, ...)
        -- Gender Mod uses nil/N for both genuinely genderless Pokémon and
        -- species it does not know. Its neutral symbol is visually identical
        -- in both cases and reads as an unexplained extra HUD marker. Keep
        -- male/female battle markers, but leave the neutral cell empty.
        if setting() and genderBattleDrawDepth > 0
            and (gender == nil or gender == "N") then
          return false
        end
        return original(Gender, gender, ...)
      end
    end

    local function wrapBattlePass(name)
      local original = hud[name]
      if type(original) ~= "function" then return end
      hud[name] = function(...)
        local args = { ... }
        local previousBattle = genderBattleContext
        genderBattleContext = args[1]
        genderBattleDrawDepth = genderBattleDrawDepth + 1
        local result
        local ok, err = xpcall(function()
          result = original(unpack(args))
        end, traceback)
        genderBattleDrawDepth = math.max(0, genderBattleDrawDepth - 1)
        genderBattleContext = previousBattle
        if not ok then error(err, 0) end
        return result
      end
    end

    wrapGlyph("drawGlyph")
    wrapGlyph("drawGlyphInk")
    wrapBattlePass("drawClassicIntoHUDs")
    wrapBattlePass("drawOverlay")
    hud.battleInfoHudSuppressNeutralBattleGlyphV1 = true
    mod.log:info("removed neutral Gender Mod marker from battle HUD")
  end

  local function installGenderVisibilityGuard(hud)
    if hud.battleInfoHudResolvedVisibilityV1 then return end

    local function wrap(name)
      local original = hud[name]
      if type(original) ~= "function" then return end
      hud[name] = function(battle, ...)
        -- A successful catch clears the battle HUD before the nickname and
        -- PC-transfer messages. Voxel renderers still ask Gender Mod to build
        -- their offscreen HUD texture during those modal frames, so its looser
        -- visibility predicate otherwise leaves two isolated glyphs behind.
        if battle and (battle.blankForAskName or battle.result == "caught") then
          return false
        end
        return original(battle, ...)
      end
    end

    wrap("enemyHudVisible")
    wrap("playerHudVisible")
    hud.battleInfoHudResolvedVisibilityV1 = true
    mod.log:info("matched Gender Mod visibility to resolved battle HUDs")
  end

  local function installGenderBridge(game)
    local genderApi, hud = genderCompatibility(game)
    if not hud then return end
    installGenderVisibilityGuard(hud)
    if hud.battleInfoHudCoordinatesV10 then
      installNeutralGenderGuard(hud)
      installCrystalGenderBridge(game, genderApi, hud)
      return
    end

    if type(hud.classicGenderXY) == "function" then
      local originalClassicXY = hud.classicGenderXY
      hud.classicGenderXY = function(side, level)
        local x, y = originalClassicXY(side, level)
        if setting() and (nativeStagedHudDepth > 0
            or nativeStagedOverlayDepth > 0) then
          -- Use the same cell for the captured art, native ink stamp and
          -- coloured overlay. Even a one-pixel nudge produces a second edge
          -- at Battle Art's large integer scale.
          if side == "player" then
            -- Force the stock level row even if this bridge was hot-reloaded
            -- on top of an older Battle Info HUD coordinate wrapper.
            y = 64
          end
          return x, y
        end
        if setting() and side == "player" then
          -- Keep the marker beside the level. Legacy texture editing uses
          -- a scratch cell so clearing the player block cannot erase it.
          if stagedGenderCaptureDepth > 0 then
            return STAGED_GENDER_SCRATCH_X, STAGED_GENDER_SCRATCH_Y
          end
          y = 64
        end
        return x, y
      end
    end

    if type(hud.wideGenderXY) == "function" then
      local originalWideXY = hud.wideGenderXY
      hud.wideGenderXY = function(side, level)
        local x, y = originalWideXY(side, level)
        if setting() and side == "player" then y = 64 end
        return x, y
      end
    end

    if type(hud.drawOverlay) == "function" then
      local originalOverlay = hud.drawOverlay
      hud.drawOverlay = function(battle, ...)
        if not setting() then return originalOverlay(battle, ...) end
        local args = { ... }
        local saved = {}
        local nativeStagedOverlay = nativeStagedHudOwner
          and stagedLayout(battle)
        for _, battler in pairs({ battle and battle.enemy,
            battle and battle.player }) do
          if battler and battler.shownStatus then
            saved[#saved + 1] = {
              battler = battler, status = battler.shownStatus,
            }
            battler.shownStatus = nil
          end
        end
        local result
        if nativeStagedOverlay then
          -- Gender Mod draws a second coloured glyph after Battle Art has
          -- captured the HUD. Keep that pass on the same stock level row as
          -- the captured glyph instead of repainting it through the name.
          nativeStagedOverlayDepth = nativeStagedOverlayDepth + 1
        end
        local ok, err = xpcall(function()
          result = originalOverlay(battle, unpack(args))
        end, traceback)
        if nativeStagedOverlay then
          nativeStagedOverlayDepth = math.max(0,
            nativeStagedOverlayDepth - 1)
        end
        for i = #saved, 1, -1 do
          saved[i].battler.shownStatus = saved[i].status
        end
        if not ok then error(err, 0) end
        return result
      end
    end

    hud.battleInfoHudCoordinatesV10 = true
    mod.log:info("attached HUD coordinates to Gender Mod")
    installNeutralGenderGuard(hud)
    installCrystalGenderBridge(game, genderApi, hud)
  end

  local genderCellLayer

  local function withStagedGenderCapture(draw)
    stagedGenderCaptureDepth = stagedGenderCaptureDepth + 1
    local result
    local ok, err = xpcall(function() result = draw() end, traceback)
    stagedGenderCaptureDepth = math.max(0, stagedGenderCaptureDepth - 1)
    if not ok then error(err, 0) end
    return result
  end

  local function captureStagedGenderCell(battle, layer)
    local _, hud = genderCompatibility(battle and battle.game)
    if not (hud and type(hud.classicGenderXY) == "function"
        and hud.battleInfoHudCoordinatesV10
        and playerVisible(battle)) then return nil end
    local level = battle.player.mon and battle.player.mon.level or 1
    local okXY, targetX, targetY = pcall(hud.classicGenderXY,
      "player", level)
    if not okXY or type(targetX) ~= "number"
        or type(targetY) ~= "number" then
      return nil
    end

    local g = love.graphics
    if type(g.newCanvas) ~= "function" or type(g.clear) ~= "function"
        or type(g.draw) ~= "function" or type(g.getCanvas) ~= "function"
        or type(g.setCanvas) ~= "function" then return nil end
    if not genderCellLayer then
      -- The authored icon is 8x8. Dramatic Shape can add a one-pixel shadow
      -- down/right while baking the HUD, so retain that ninth edge too.
      local okCanvas, canvas = pcall(g.newCanvas,
        STAGED_GENDER_CAPTURE_SIZE, STAGED_GENDER_CAPTURE_SIZE)
      if not okCanvas or not canvas then return nil end
      if type(canvas.setFilter) == "function" then
        canvas:setFilter("nearest", "nearest")
      end
      genderCellLayer = canvas
    end

    local previous = g.getCanvas()
    g.push("all")
    g.setCanvas(genderCellLayer)
    g.clear(0, 0, 0, 0)
    g.setColor(1, 1, 1, 1)
    g.draw(layer, -STAGED_GENDER_SCRATCH_X,
      -STAGED_GENDER_SCRATCH_Y)
    g.pop()
    if previous then g.setCanvas(previous) else g.setCanvas() end
    return genderCellLayer, targetX, targetY
  end

  local function composeStagedTexture(battle, layer, inkPass)
    if not layer then return end
    local g = love.graphics
    if type(g.getCanvas) ~= "function" or type(g.setCanvas) ~= "function" then
      return
    end
    local previous = g.getCanvas()
    local genderCell, genderX, genderY =
      captureStagedGenderCell(battle, layer)
    g.push("all")
    g.setCanvas(layer)
    if genderCell then
      -- Gender Mod originally paints into a clean scratch cell so rebuilding
      -- the player HUD cannot copy name, underline or panel pixels along with
      -- its authored icon. Remove that staging cell before the band is moved.
      if type(g.setBlendMode) == "function" then
        g.setBlendMode("replace", "premultiplied")
      end
      g.setColor(0, 0, 0, 0)
      g.rectangle("fill", STAGED_GENDER_SCRATCH_X,
        STAGED_GENDER_SCRATCH_Y, STAGED_GENDER_CAPTURE_SIZE,
        STAGED_GENDER_CAPTURE_SIZE)
    end
    if type(g.setBlendMode) == "function" then g.setBlendMode("alpha") end
    if inkPass then
      -- Some Dramatic Shape forks bake white-on-dark HUD ink through a
      -- shader while creating the texture. Clear the original player block
      -- on the finished layer, then send our replacement glyphs through that
      -- same pass so they inherit the fork's current contrast treatment.
      if playerVisible(battle) then clearStagedPlayerHud() end
      inkPass(function() drawStagedHudContent(battle, true, false) end)
      drawClassicMeters(battle)
    else
      drawStagedHudContent(battle, false, false)
    end
    if genderCell then
      g.setColor(1, 1, 1, 1)
      g.draw(genderCell, genderX, genderY)
    end
    g.pop()
    if previous then g.setCanvas(previous) else g.setCanvas() end
  end

  -- Dramatic Shape snapshots the original classic HUD into a 160x144 texture
  -- and then moves that texture to the window edges. Edit that texture before
  -- it is placed; staged battles never draw these additions afterward.
  local function installDramaticBridge(game, companionId)
    local exports = game and game.mods and game.mods.exports
    local api = exports and exports[companionId]
    local lib = api and api.lib
    if not (lib and type(lib.require) == "function") then return end
    local ok, overworld = pcall(lib.require, "OverworldBattle")
    if not ok or type(overworld) ~= "table"
        or type(overworld.hudTexture) ~= "function" then return end
    local innerHudTexture = overworld.hudTexture
    local companionApi = exports and exports[companionId]
    local companionVersion = tostring(companionApi and companionApi.version
      or "0")
    local companionMajor, companionMinor = companionVersion:match(
      "^(%d+)%.(%d+)")
    local usesNativeStagedHud = companionId == "BATTLE_ART_VOXEL_FORK"
      and ((tonumber(companionMajor) or 0) > 1
        or ((tonumber(companionMajor) or 0) == 1
          and (tonumber(companionMinor) or 0) >= 8))
    if usesNativeStagedHud then nativeStagedHudOwner = true end
    if overworld.battleInfoHudTextureEditorV6 then return end

    if usesNativeStagedHud then
      local okPresentation, presentation = pcall(lib.require, "BattlePresentation")
      if okPresentation and type(presentation.suppressed) == "function" then
        nativeStagedSuppressed = function(battle)
          return presentation.suppressed("hud", battle)
        end
      end
      -- Follow the public compositor's result rather than inspecting its
      -- private session or guessing from the platform. A successfully snapped
      -- HUD must not acquire a second pair of meters at classic coordinates.
      if type(overworld.update) == "function" then
        local update = overworld.update
        overworld.update = function(...)
          local battle = type(overworld.battle) == "function" and overworld.battle()
          if battle then nativeStagedSnapped[battle] = nil end
          return update(...)
        end
      end
      if type(overworld.snapHUDs) == "function" then
        local snapHUDs = overworld.snapHUDs
        overworld.snapHUDs = function(battle, ...)
          nativeStagedSnapped[battle] = nil
          local result = snapHUDs(battle, ...)
          nativeStagedSnapped[battle] = result == true
          return result
        end
      end
      local okBackplates, backplates = pcall(lib.require, "UiBackplates")
      if okBackplates and type(backplates.hudUsesColor) == "function" then
        nativeStagedInk = function()
          return backplates.hudUsesColor() and {0, 0, 0, 1} or {1, 1, 1, 1}
        end
        local okHud, companionHud = pcall(lib.require, "BattleHud")
        if okHud and type(companionHud.flipGlyphs) == "function" then
          nativeStagedTextPass = function(draw)
            return companionHud.flipGlyphs(160, 144, draw,
              backplates.hudUsesColor(), nil,
              type(backplates.hudUsesColorShadow) == "function"
                and backplates.hudUsesColorShadow())
          end
        end
      end
      overworld.hudTexture = function(liveBattle, slide, dark, inverted, colorShadow)
        nativeStagedHudDepth = nativeStagedHudDepth + 1
        local layer
        local okLayer, layerErr = xpcall(function()
          local function capture()
            return innerHudTexture(liveBattle, slide, dark, inverted, colorShadow)
          end
          if setting() then
            layer = withNativeLevels(liveBattle, false, function()
              return withoutNativeHPBars(liveBattle, slide, capture)
            end)
          else
            layer = capture()
          end
        end, traceback)
        nativeStagedHudDepth = math.max(0, nativeStagedHudDepth - 1)
        if not okLayer then error(layerErr, 0) end
        if not (setting() and layer and liveBattle and slide == 0
            and not liveBattle.blankForAskName and liveBattle.result ~= "caught"
            and not liveBattle.introBalls) then return layer end
        local okPresentation, presentation = pcall(lib.require, "BattlePresentation")
        if okPresentation and type(presentation.suppressed) == "function"
            and presentation.suppressed("hud", liveBattle) then return layer end
        local g = love.graphics
        local previous = g.getCanvas()
        local okDraw, drawErr = xpcall(function()
          g.push("all")
          g.setCanvas(layer)
          g.origin()
          g.setShader()
          g.setScissor()
          g.setBlendMode("replace", "premultiplied")
          g.setColor(0, 0, 0, 0)
          if enemyVisible(liveBattle) then g.rectangle("fill", 16, 16, 72, 8) end
          if playerVisible(liveBattle) then g.rectangle("fill", 80, 72, 64, 17) end
          g.setBlendMode("alpha")
          local ink = dark and not inverted and {1, 1, 1, 1} or {0, 0, 0, 1}
          -- Status/caught artwork follows the provider's own ink treatment.
          local function extras()
            if enemyVisible(liveBattle) then
              drawStatusAfterLevel(liveBattle, liveBattle.enemy, 40, 8, 88)
              if isCaught(liveBattle, liveBattle.enemy) then
                drawCaughtBall(liveBattle, caughtBallX(liveBattle.enemy.name,
                  nameX(1, liveBattle.enemy.name)), 0)
              end
            end
            if playerVisible(liveBattle) then drawStatusAt(liveBattle, liveBattle.player, 80, 64) end
          end
          local okHud, companionHud = pcall(lib.require, "BattleHud")
          if dark and okHud and type(companionHud.flipGlyphs) == "function" then
            companionHud.flipGlyphs(160, 144, extras, inverted, nil, colorShadow)
          else extras() end
          g.setShader()
          if enemyVisible(liveBattle) then drawEnemyMeter(liveBattle, ink, false) end
          if playerVisible(liveBattle) then drawPlayerMeters(liveBattle, ink, false) end
        end, traceback)
        g.pop()
        if previous then g.setCanvas(previous) else g.setCanvas() end
        if not okDraw then error(drawErr, 0) end
        return layer
      end
      overworld.battleInfoHudTextureEditorV6 = true
      mod.log:info("attached compact meters to %s %s native HUD capture", companionId, companionVersion)
      return
    end


    overworld.hudTexture = function(liveBattle, ...)
      local args = { ... }
      if not setting() then
        return innerHudTexture(liveBattle, unpack(args))
      end
      installGenderBridge(liveBattle.game)
      local layer = withStagedGenderCapture(function()
        return withNativeLevels(liveBattle, false, function()
          return withoutNativeHPBars(liveBattle, args[1], function()
            return innerHudTexture(liveBattle, unpack(args))
          end)
        end)
      end)
      local inkPass
      if args[2] == true then
        local okHud, battleHud = pcall(lib.require, "BattleHud")
        if okHud and battleHud
            and type(battleHud.flipGlyphs) == "function" then
          inkPass = function(draw)
            return battleHud.flipGlyphs(160, 144, draw, args[3], nil,
              args[4])
          end
        end
      end
      composeStagedTexture(liveBattle, layer, inkPass)
      return layer
    end
    overworld.battleInfoHudTextureEditorV6 = true
    mod.log:info("attached staged HUD to %s", companionId)
  end

  local function installDramaticBridges(game)
    for _, companionId in ipairs(STAGED_COMPANIONS) do
      installDramaticBridge(game, companionId)
    end
  end

  local onReady = type(mod.events.always) == "function"
    and mod.events.always or mod.events.on
  onReady(mod.events, "game.ready", function(ev)
    installGenderBridge(ev and ev.game)
    installDramaticBridges(ev and ev.game)
  end)

  mod.hooks:wrap("battle.overlay", function(next, battle)
    installGenderBridge(battle and battle.game)
    local layout = layoutFor(battle)
    if not layout then return next(battle) end
    if layout == "staged" then
      installDramaticBridges(battle.game)
      local result = next(battle)
      if classicEnhancementActive(battle, 0) then
        -- Battle Art suppresses fill rectangles while its internal zone pass
        -- runs. Paint semantic meter pixels after that scope has ended, with
        -- the same screen shake as the native HUD and Gender Mod's overlay.
        local fx = battle.fx or {}
        local flashing = (fx.flash or 0) > 0 and (battle.frame or 0) % 4 < 2
        if not flashing then
          local sx, sy = fx.shakeX or 0, fx.shakeY or 0
          if sx == 0 and sy == 0 and (fx.shake or 0) > 0 then
            sx = (battle.frame or 0) % 4 < 2 and 2 or -2
          end
          drawClassicMeters(battle, sx, sy)
        end
      end
      return result
    end
    next(battle)
    renderWide(battle)
  end, 50)
end
