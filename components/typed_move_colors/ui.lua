return function(mod)
  local Font = require("src.render.Font")
  local BattleState = require("src.battle.BattleState")
  local ListMenu = require("src.ui.ListMenu")
  local MoveLearnMenu = require("src.ui.MoveLearnMenu")
  local PaletteFX = require("src.render.PaletteFX")
  local SafeArea = require("src.core.SafeArea")
  local Strings = require("src.core.Strings")
  local SummaryMenu = require("src.ui.SummaryMenu")
  local TouchControls = require("src.core.TouchControls")
  local TypeChart = require("src.battle.TypeChart")
  local WideBattle = require("src.battle.WideBattle")

  -- Exact flat fills sampled from the supplied type-colour reference. The
  -- Gen 1 set uses fifteen entries; DARK, FAIRY and STEEL are included so
  -- content mods that add later types receive the same coherent system.
  local TYPE_BASE_COLORS = {
    NORMAL = { 144, 152, 162 },
    FIGHTING = { 206, 63, 107 },
    FLYING = { 143, 168, 222 },
    POISON = { 171, 106, 200 },
    GROUND = { 217, 119, 70 },
    ROCK = { 201, 182, 139 },
    BUG = { 144, 192, 44 },
    GHOST = { 82, 105, 173 },
    FIRE = { 254, 156, 85 },
    WATER = { 77, 144, 214 },
    GRASS = { 101, 188, 94 },
    ELECTRIC = { 244, 210, 59 },
    PSYCHIC_TYPE = { 249, 113, 119 },
    ICE = { 115, 206, 191 },
    DRAGON = { 9, 109, 195 },
    DARK = { 91, 82, 101 },
    FAIRY = { 236, 144, 231 },
    STEEL = { 91, 142, 161 },
  }

  local function typeRamp(base)
    local light = {}
    for i = 1, 3 do
      light[i] = math.floor(base[i] + (255 - base[i]) * 0.30 + 0.5)
    end
    return {
      { 255, 255, 255 }, light,
      { base[1], base[2], base[3] }, { 0, 0, 0 },
    }
  end

  local TYPE_COLORS = {}
  for id, base in pairs(TYPE_BASE_COLORS) do
    TYPE_COLORS[id] = typeRamp(base)
  end

  -- Optional high-saturation fills contributed by Haseo. Bold remains the
  -- reference-derived palette, while Vibrant gives small/mobile cards and
  -- Text Only ink a stronger type association without replacing either of
  -- the existing styles.
  local VIBRANT_BASE_COLORS = {
    NORMAL = { 135, 151, 171 },
    FIGHTING = { 217, 36, 84 },
    FLYING = { 107, 147, 233 },
    POISON = { 165, 64, 211 },
    GROUND = { 228, 96, 24 },
    ROCK = { 212, 181, 111 },
    BUG = { 137, 202, 20 },
    GHOST = { 58, 82, 182 },
    FIRE = { 255, 118, 24 },
    WATER = { 32, 125, 225 },
    GRASS = { 63, 198, 52 },
    ELECTRIC = { 255, 208, 20 },
    PSYCHIC_TYPE = { 255, 67, 76 },
    ICE = { 74, 217, 193 },
    DRAGON = { 24, 105, 215 },
    DARK = { 90, 74, 108 },
    FAIRY = { 248, 103, 240 },
    STEEL = { 60, 140, 170 },
  }

  local VIBRANT_TYPE_COLORS = {}
  for id, base in pairs(VIBRANT_BASE_COLORS) do
    VIBRANT_TYPE_COLORS[id] = typeRamp(base)
  end

  -- OG RED/BLUE and OG YELLOW are hardware palettes rather than the modern
  -- type set. Keep their established named-palette mapping when that display
  -- mode is selected; monochrome, inverted and Classic transformations are
  -- handled by PaletteFX.effectiveColors below.
  local OG_TYPE_PALETTES = {
    NORMAL = "GRAYMON",
    FIGHTING = "REDMON",
    FLYING = "CYANMON",
    POISON = "PURPLEMON",
    GROUND = "BROWNMON",
    ROCK = "BROWNMON",
    BUG = "GREENMON",
    GHOST = "PURPLEMON",
    FIRE = "REDMON",
    WATER = "BLUEMON",
    GRASS = "GREENMON",
    ELECTRIC = "YELLOWMON",
    PSYCHIC_TYPE = "PINKMON",
    ICE = "CYANMON",
    DRAGON = "PURPLEMON",
  }

  local function setting(key, fallback)
    local ok, value = pcall(mod.options.get, mod.options, key)
    if not ok or value == nil then return fallback end
    return value
  end

  -- The suite keeps this component installed so it can be toggled live. Most
  -- registrations pass through the suite's gated hook/screen proxies, but the
  -- process-stable class patches below intentionally sit outside those
  -- registries. They must consult the component master switch themselves or
  -- they can keep suppressing native battle chrome and repainting native move
  -- rows after Disable All UI has turned the component off.
  local function componentEnabled()
    local enabled = mod.options and mod.options.enabled
    if type(enabled) ~= "function" then return true end
    local ok, value = pcall(enabled, mod.options)
    return not ok or value ~= false
  end

  local function textOnlyMode()
    return componentEnabled() and setting("text_only", false)
  end

  local function gen3BattleUIActive(game)
    local ok, handle = pcall(mod.find, "gen3_battle_ui")
    if not ok or not handle then return false end
    local loader = game and game.mods
    local options = loader and loader.modOptions
      and loader.modOptions.gen3_battle_ui
    return not (options and options.revampedBattleUI == false)
  end

  local function gen1ModernUIInstalled()
    local ok, handle = pcall(mod.find, "gen1_modern_ui")
    return ok and handle ~= nil
  end

  local function battleArtPresentation()
    local ok, handle = pcall(mod.find, "BATTLE_ART_VOXEL_FORK")
    local presentation = ok and handle and handle.exports
      and handle.exports.battlePresentation
    if type(presentation) ~= "table"
        or tonumber(presentation.apiVersion or 0) < 1
        or type(presentation.suppressHook) ~= "string" then
      return nil
    end
    return presentation
  end

  -- Potato Voxel and upstream Dramatic Shape predate Battle Art's public
  -- presentation contract, but both export their OverworldBattle module
  -- through the documented `lib.require` seam. Its textRects list is the
  -- source used for their frosted command/dialogue/move panels, so filtering
  -- that list lets a Typed presentation take ownership without disturbing
  -- either renderer's world or Pokemon HUDs.
  local function voxelBattleModule(modId)
    local ok, handle = pcall(mod.find, modId)
    local lib = ok and handle and handle.exports and handle.exports.lib
    if type(lib) ~= "table" or type(lib.require) ~= "function" then
      return nil
    end
    local loaded, battleModule = pcall(lib.require, "OverworldBattle")
    if loaded and type(battleModule) == "table" then return battleModule end
    return nil
  end

  local function engineWide(battle)
    if not battle then return false end
    -- Current engines expose wideLayout; earlier development builds used
    -- isWideBattleLayout directly. Text Only must follow the layout that
    -- actually drew the native labels or its colour pass lands in classic
    -- columns over a wide two-column menu.
    for _, name in ipairs({ "wideLayout", "isWideBattleLayout" }) do
      local check = battle[name]
      if type(check) == "function" then
        local ok, wide = pcall(check, battle)
        if ok then return wide and true or false end
      end
    end
    local options = battle.game and battle.game.save
      and battle.game.save.options
    return options and options.battleLayout == "wide" or false
  end

  local function windowPixelRatio()
    local unitW, unitH = love.graphics.getDimensions()
    local pixelW, pixelH = unitW, unitH
    if love.graphics.getPixelDimensions then
      pixelW, pixelH = love.graphics.getPixelDimensions()
    end
    local dpiX = unitW > 0 and pixelW / unitW or 1
    local dpiY = unitH > 0 and pixelH / unitH or 1
    if dpiX <= 0 then dpiX = 1 end
    if dpiY <= 0 then dpiY = 1 end
    return dpiX, dpiY
  end

  -- The detached selector is authored in framebuffer pixels. Retina 1x is
  -- 160x144 LOVE units but 320x288 physical pixels, which is enough for the
  -- normal 304px panel once its final transform accounts for DPI.
  local function detachedSurfaceFits(screenW, screenH, dpiX, dpiY)
    if screenW == nil or screenH == nil then
      local ok, _, _, safeW, safeH = pcall(SafeArea.rect)
      if ok then screenW, screenH = safeW, safeH end
    end
    if dpiX == nil or dpiY == nil then
      dpiX, dpiY = windowPixelRatio()
    end
    screenW = tonumber(screenW) or 0
    screenH = tonumber(screenH) or 0
    dpiX = tonumber(dpiX) or 1
    dpiY = tonumber(dpiY) or 1
    return screenW * dpiX >= 152 and screenH * dpiY >= 44
  end

  -- If the engine itself is already wide, the in-canvas overlay below
  -- decorates that grid. Otherwise a window-space presenter supplies the
  -- command, dialogue and 2x2 move phases without changing the battlefield
  -- canvas, HUDs, sprites or background. This is the seam staged voxel
  -- battles need: they keep their transparent 160px scene intact.
  local function detachedGrid(battle)
    return componentEnabled()
      and setting("layout", "wide") == "wide"
      and not textOnlyMode()
      and not engineWide(battle)
      and not gen3BattleUIActive(battle and battle.game)
      and detachedSurfaceFits()
  end

  -- The classic controller treats moves as a vertical list. When the
  -- detached panel is showing, correct only its directional result after the
  -- native update runs; A/B/SELECT, PP validation and move execution remain
  -- entirely native. The wrapper is process-stable across mod reloads.
  local inputPatch = rawget(BattleState, "_typedMoveColorsInputPatch")
  if not inputPatch then
    inputPatch = { original = BattleState.update }
    rawset(BattleState, "_typedMoveColorsInputPatch", inputPatch)
    BattleState.update = function(self, ...)
      local phase = self.phase
      local indexKey = phase == "moveSelect" and "moveIndex"
        or phase == "mimicSelect" and "mimicIndex" or nil
      local moves = phase == "moveSelect"
        and self.player and self.player.curMoves or self.mimicMoves
      local before = indexKey and self[indexKey] or nil
      local direction
      if before and type(moves) == "table" and inputPatch.detached
          and inputPatch.detached(self) then
        local input = self.game and self.game.input
        for _, key in ipairs({ "left", "right", "up", "down" }) do
          if input and input.wasPressed and input:wasPressed(key) then
            direction = key
            break
          end
        end
      end
      local result = inputPatch.original(self, ...)
      if direction and self.phase == phase and indexKey then
        self[indexKey] = inputPatch.navigate(before, #moves, direction)
      end
      if inputPatch.trackPresentationBattle then
        inputPatch.trackPresentationBattle(self)
      end
      return result
    end
  end
  inputPatch.detached = detachedGrid
  inputPatch.navigate = WideBattle.moveGridIndex
  inputPatch.engineWide = engineWide
  inputPatch.gen3BattleUIActive = gen3BattleUIActive
  inputPatch.gen1ModernUIInstalled = gen1ModernUIInstalled
  inputPatch.detachedSurfaceFits = detachedSurfaceFits
  inputPatch.textOnlyMode = textOnlyMode

  local function isTop(screen)
    local stack = screen and screen.game and screen.game.stack
    return not (stack and stack.top) or stack:top() == screen
  end

  -- A move-learning controller can be pushed over a live staged battle.
  -- Its native list is part of the 160x144 modal, while card geometry can be
  -- composited through the underlying voxel surface at a different offset.
  -- Keep that modal's native geometry and recolour only its existing ink.
  local function stagedBattleBehind(screen)
    local stack = screen and screen.game and screen.game.stack
    local states = stack and stack.states
    if type(states) ~= "table" then return false end
    for i = #states - 1, 1, -1 do
      local state = states[i]
      if type(state) == "table"
          and (rawget(state, "dramaticShapeShot") ~= nil
          or state.letterboxWhite == false) then
        return true
      end
    end
    return false
  end

  local function widePresentationOwnsPhase(battle)
    if not componentEnabled() or textOnlyMode()
        or not setting("battle_colors", true) then return false end
    local phase = battle and battle.phase
    local owned = phase == "moveSelect" or phase == "mimicSelect"
      or (phase == "menu" and not battle.safari and not battle.demo)
      or phase == "messages"
    return owned and detachedGrid(battle)
  end

  local function customBattleSurface(battle)
    return battle and (rawget(battle, "dramaticShapeShot") ~= nil
      or battle.letterboxWhite == false
      or gen1ModernUIInstalled())
  end

  -- GAME normally leaves the engine's compact move selector in charge. A
  -- transparent/custom renderer is the exception: repainting pieces of that
  -- native box with the engine's paper shade produces the white slab seen in
  -- Potato Voxel and Modern UI's edited battle composition. Own only its move
  -- and Mimic phases, then draw the same compact geometry without an opaque
  -- cleanup pass. Commands and dialogue remain renderer-owned in GAME mode.
  local function compactPresentationOwnsPhase(battle)
    if not componentEnabled() or textOnlyMode()
        or not setting("battle_colors", true)
        or setting("layout", "wide") == "wide"
        or engineWide(battle) or not customBattleSurface(battle) then
      return false
    end
    local phase = battle and battle.phase
    return phase == "moveSelect" or phase == "mimicSelect"
  end

  -- GAME is the faithful cartridge-shaped presentation in an ordinary 2D
  -- battle. The native TYPE/PP box, move-list frame, cursor and vertical input
  -- remain in charge; the overlay below only replaces the four white row
  -- interiors with type colour and redraws their native-size ink. Custom or
  -- transparent renderers still need the paper-free compact replacement.
  local function nativeGamePresentation(battle)
    return battle ~= nil
      and componentEnabled()
      and not textOnlyMode()
      and setting("battle_colors", true)
      and setting("layout", "wide") ~= "wide"
      and not engineWide(battle)
      and not customBattleSurface(battle)
  end

  local function replacementPresentationOwnsPhase(battle)
    if not componentEnabled() then return false end
    return widePresentationOwnsPhase(battle)
      or compactPresentationOwnsPhase(battle)
  end

  inputPatch.trackPresentationBattle = function(battle)
    if replacementPresentationOwnsPhase(battle) then
      inputPatch.presentationBattle = battle
    elseif inputPatch.presentationBattle == battle then
      inputPatch.presentationBattle = nil
    end
  end

  -- Battle Art 1.8.3 publishes a presentation contract for replacement UIs.
  -- Claim its native text and backing panels only while this finished-frame
  -- Wide presentation is actually visible. This prevents Battle Art from
  -- baking old command/dialogue/TYPE/PP rectangles into its world canvas, and
  -- avoids touching the transparent 160x144 canvas that Crystal Animated's
  -- sprites compose with.
  local battleArt = battleArtPresentation()
  if battleArt then
    mod.hooks:wrap(battleArt.suppressHook, function(next, request)
      local claimed = next(request)
      if claimed == true or type(request) ~= "table"
          or request.sourceModId ~= battleArt.sourceModId then
        return claimed
      end
      local battle = request.battle or inputPatch.presentationBattle
      if not replacementPresentationOwnsPhase(battle) then return claimed end
      if request.surface == battleArt.surfaces.text
          or request.surface == battleArt.surfaces.panels then
        return true
      end
      return claimed
    end, 9000)
  end

  -- Prevent the native boxes from being drawn in the first place. Erasing
  -- them after BattleState.drawTextArea had already painted opaque paper is
  -- what produced WORLD-shaped holes, retained RGB rectangles on translucent
  -- renderers, and the stray TYPE/PP slab visible with Fancy Battle/Battle
  -- Art. The wrapper is process-stable across mod reloads, like the input
  -- patch above. Ordinary GAME move selection deliberately retains its native
  -- panel; only a staged renderer's compact move phase is replaced to avoid
  -- painting paper into its transparent surface.
  local textPatch = rawget(BattleState, "_typedMoveColorsTextPatch")
  if not textPatch then
    textPatch = { original = BattleState.drawTextArea }
    rawset(BattleState, "_typedMoveColorsTextPatch", textPatch)
    BattleState.drawTextArea = function(self, ...)
      if textPatch.owns and textPatch.owns(self) then return end
      -- Faithful GAME rows are coloured while the native renderer is
      -- producing them. This lets a localization/layout mod move the native
      -- move-name and cursor columns without leaving the old ink exposed to
      -- the left of a separately positioned post-overlay.
      if textPatch.nativeRows and textPatch.nativeRows(self)
          and textPatch.drawNativeRows then
        return textPatch.drawNativeRows(self, textPatch.original, ...)
      end
      return textPatch.original(self, ...)
    end
  end
  textPatch.owns = replacementPresentationOwnsPhase
  inputPatch.widePresentationOwnsPhase = widePresentationOwnsPhase
  inputPatch.compactPresentationOwnsPhase = compactPresentationOwnsPhase
  inputPatch.nativeGamePresentation = nativeGamePresentation
  inputPatch.replacementPresentationOwnsPhase =
    replacementPresentationOwnsPhase
  inputPatch.customBattleSurface = customBattleSurface
  inputPatch.stagedBattleBehind = stagedBattleBehind

  -- These voxel renderers draw their translucent glass rectangles before
  -- BattleState.drawTextArea. Suppressing drawTextArea alone therefore leaves
  -- a white/frosted block behind. Filter only their text-surface rectangles
  -- while a Typed presentation owns the phase; enemy/player HUD rectangles
  -- stay renderer-owned, and GAME commands/dialogue retain their panels.
  local function installVoxelTextRectsPatch(modId, statusKey)
    local battleModule = voxelBattleModule(modId)
    if battleModule and type(battleModule.textRects) == "function" then
      local patch = rawget(battleModule, "_typedMoveColorsTextRectsPatch")
      if not patch then
        patch = { original = battleModule.textRects }
        rawset(battleModule, "_typedMoveColorsTextRectsPatch", patch)
        battleModule.textRects = function(battle)
          local rects = patch.original(battle)
          if patch.owns and patch.owns(battle) then return {} end
          return rects
        end
      end
      patch.owns = replacementPresentationOwnsPhase
      inputPatch[statusKey] = true
    else
      inputPatch[statusKey] = false
    end
  end
  installVoxelTextRectsPatch("potato_voxel", "potatoTextRectsPatched")
  installVoxelTextRectsPatch("DRAMATIC_SHAPE", "dramaticTextRectsPatched")

  local function moveDef(game, move)
    local id = type(move) == "table" and move.id or move
    local moves = game and game.data and game.data.moves
    return moves and moves[id] or nil
  end

  local function colorsFor(game, moveType)
    local data = game and game.data
    local colors
    if PaletteFX.mode == "ogred" then
      local named = OG_TYPE_PALETTES[moveType] or "GRAYMON"
      colors = PaletteFX.pal(data, named)
        or PaletteFX.pal(data, "GRAYMON") or PaletteFX.GRAYS
    else
      local palette = setting("strength", "bold") == "vibrant"
        and VIBRANT_TYPE_COLORS or TYPE_COLORS
      colors = palette[moveType] or palette.NORMAL
    end
    return PaletteFX.effectiveColors(colors) or colors
  end
  inputPatch.colorsFor = colorsFor

  local function darkerTypeColor(color)
    return {
      math.floor(color[1] * 0.55 + 0.5),
      math.floor(color[2] * 0.55 + 0.5),
      math.floor(color[3] * 0.55 + 0.5),
    }
  end

  local function brighterTextColor(color)
    return {
      math.floor(color[1] * 0.65 + 0.5),
      math.floor(color[2] * 0.65 + 0.5),
      math.floor(color[3] * 0.65 + 0.5),
    }
  end

  -- Text-only mode needs ink that remains readable against the native paper
  -- rather than the brighter fill used by a complete move card. Normal and
  -- unknown custom types retain the native darkest ink shade.
  local function textColorFor(game, moveType)
    local colors = colorsFor(game, moveType)
    if moveType == "NORMAL" or TYPE_COLORS[moveType] == nil then
      return colors[4]
    end
    return brighterTextColor(colors[3])
  end
  inputPatch.textColorFor = textColorFor

  local rgb

  -- Effect indicators use the same merged chart as damage calculation and
  -- the opponent's live battle types, so Conversion and type/content mods are
  -- reflected immediately. Fixed-damage and Super Fang effects deliberately
  -- skip the chart in Gen 1; because they still change HP, they receive the
  -- ordinary single-up indicator. OHKO moves consult only immunity.
  local DIRECT_HP_DAMAGE = {
    SPECIAL_DAMAGE_EFFECT = true,
    SUPER_FANG_EFFECT = true,
  }

  local function effectIndicator(battle, def)
    if not setting("effect_hints", true) or not battle or not def then
      return nil
    end
    local target = battle.enemy
    if type(target and target.curTypes) ~= "table" then return nil end
    if DIRECT_HP_DAMAGE[def.effect] then return "up" end
    if type(def.power) ~= "number" or def.power <= 0 then return "circle" end
    local ok, mult = pcall(TypeChart.effectiveness,
      def.type, target.curTypes)
    if not ok or type(mult) ~= "number" then return "circle" end
    if mult == 0 then return "circle" end
    if def.effect == "OHKO_EFFECT" then return "up" end
    if mult > 10 then return "double_up" end
    if mult < 10 then return "down" end
    return "up"
  end
  inputPatch.effectIndicator = effectIndicator

  local function drawEffectArrow(cx, cy, direction, color)
    love.graphics.setColor(rgb(color))
    if direction == "up" then
      love.graphics.polygon("fill", {
        cx, cy - 4, cx - 4, cy + 3, cx + 4, cy + 3,
      })
    else
      love.graphics.polygon("fill", {
        cx, cy + 4, cx - 4, cy - 3, cx + 4, cy - 3,
      })
    end
  end

  local function drawEffectIndicator(kind, x, y, w, h, color)
    if not kind then return end
    local cx = x + w - 10
    local cy = y + h - 9
    if kind == "circle" then
      love.graphics.push("all")
      love.graphics.setColor(rgb(color))
      if love.graphics.setLineWidth then love.graphics.setLineWidth(1) end
      love.graphics.circle("line", cx, cy, 3)
      love.graphics.pop()
    elseif kind == "double_up" then
      drawEffectArrow(cx - 4, cy, "up", color)
      drawEffectArrow(cx + 4, cy, "up", color)
    else
      drawEffectArrow(cx, cy, kind, color)
    end
  end

  local inkShader
  local function shaderForInk()
    if inkShader == nil then
      if not love.graphics.newShader then
        inkShader = false
      else
        local ok, shader = pcall(love.graphics.newShader, [[
          vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            vec4 pixel = Texel(tex, tc);
            return vec4(color.rgb, pixel.a * color.a);
          }
        ]])
        inkShader = ok and shader or false
      end
    end
    return inkShader or nil
  end

  local function fitText(text, maxWidth)
    text = tostring(text or "")
    maxWidth = math.max(0, math.floor(maxWidth or Font.width(text)))
    if Font.width(text) <= maxWidth then return text end
    local spans = Font.split and Font.split(text) or nil
    if spans and Font.spansFitting then
      local count = Font.spansFitting(spans, maxWidth)
      return count > 0 and text:sub(1, spans[count].to) or ""
    end
    while #text > 0 and Font.width(text) > maxWidth do
      text = text:sub(1, -2)
    end
    return text
  end

  rgb = function(color)
    return color[1] / 255, color[2] / 255, color[3] / 255
  end

  local function drawInk(text, x, y, maxWidth, color)
    text = fitText(text, maxWidth)
    love.graphics.push("all")
    local shader = shaderForInk()
    if shader then
      love.graphics.setShader(shader)
      love.graphics.setColor(rgb(color))
    else
      love.graphics.setColor(0, 0, 0, 1)
    end
    Font.draw(text, math.floor(x), math.floor(y))
    love.graphics.pop()
  end

  local function fitTextWithDot(text, maxWidth)
    text = tostring(text or "")
    if Font.width(text) <= maxWidth then return text end
    local dot = "."
    return fitText(text, math.max(0, maxWidth - Font.width(dot))) .. dot
  end

  -- Redraw exactly one native move-name or selected-type glyph run and
  -- protect only its ink from the four-shade palette pass. No box, cursor,
  -- PP value or input behavior is replaced in this mode.
  local function drawTypedText(game, def, label, x, y, maxWidth, dotted)
    if not def then return end
    label = tostring(label or def.name or "")
    if dotted and maxWidth then
      label = fitTextWithDot(label, maxWidth)
    end
    local width = Font.width(label)
    if maxWidth then width = math.min(width, maxWidth) end
    if width <= 0 then return end
    drawInk(label, x, y, width, textColorFor(game, def.type))
    PaletteFX.markTrueColor(x, y, width, 8)
  end

  -- Summary rows have a complete top line available now that redundant type
  -- abbreviations are gone. Preserve every translated move-name glyph and
  -- reduce only genuinely long labels instead of deleting their tail.
  local function drawFittedInk(text, x, y, maxWidth, color, minimumScale)
    text = tostring(text or "")
    local width = Font.width(text)
    local scale = width > 0 and math.min(1, maxWidth / width) or 1
    minimumScale = math.max(0.5, math.min(1,
      tonumber(minimumScale) or 0.75))
    if scale < minimumScale then
      scale = minimumScale
      text = fitText(text, maxWidth / scale)
    end
    if scale == 1 then
      drawInk(text, x, y, maxWidth, color)
      return 1
    end
    love.graphics.push("all")
    local shader = shaderForInk()
    if shader then
      love.graphics.setShader(shader)
      love.graphics.setColor(rgb(color))
    else
      love.graphics.setColor(0, 0, 0, 1)
    end
    love.graphics.translate(math.floor(x), math.floor(y))
    love.graphics.scale(scale, scale)
    Font.draw(text, 0, 0)
    love.graphics.pop()
    return scale
  end

  -- Detached cards may be deliberately smaller than the 160x144 battle
  -- surface they accompany. Grow their lettering back to the battle's own
  -- pixel scale, then reduce only long translated labels enough to fit. This
  -- keeps FIGHT and short move names at roughly the same visual size as the
  -- Pokemon names without clipping names such as SEMENTE SUGA-VIDA.
  local function detachedInkScale(text, maxWidth, preferred, minimum)
    minimum = tonumber(minimum) or 1
    preferred = math.max(minimum, tonumber(preferred) or minimum)
    local width = Font.width(tostring(text or ""))
    if width <= 0 then return preferred end
    return math.max(minimum, math.min(preferred, maxWidth / width))
  end

  -- Size the details card against a nine-cell reference. All stock Gen 1
  -- type names are eight cells or fewer, while POWER 999 and PP 99/99 fit in
  -- nine, so selection changes no longer make those rows jump in size. Only
  -- custom/translated type names beyond that reference shrink further.
  local function detailInkScales(typeText, maxWidth, preferred)
    local referenceWidth = Font.width(string.rep("M", 9))
    local fixed = detachedInkScale(string.rep("M", 9), maxWidth, preferred)
    local typeScale = fixed
    local typeWidth = Font.width(tostring(typeText or ""))
    if typeWidth > referenceWidth and typeWidth > 0 then
      typeScale = math.max(0.75, math.min(fixed, maxWidth / typeWidth))
    end
    return fixed, typeScale
  end
  inputPatch.detailInkScales = detailInkScales

  local function drawDetachedInk(text, x, y, maxWidth, color, preferred,
      minimum)
    local scale = detachedInkScale(text, maxWidth, preferred, minimum)
    text = tostring(text or "")
    -- A scale chosen as maxWidth / width already fits exactly; feeding that
    -- quotient back through fitText's integer floor can lose one final glyph
    -- to floating-point rounding (for example translated PKMN labels).
    if Font.width(text) * scale > maxWidth + 0.001 then
      text = fitText(text, maxWidth / scale)
    end
    love.graphics.push("all")
    local shader = shaderForInk()
    if shader then
      love.graphics.setShader(shader)
      love.graphics.setColor(rgb(color))
    else
      love.graphics.setColor(0, 0, 0, 1)
    end
    love.graphics.translate(math.floor(x), math.floor(y))
    love.graphics.scale(scale, scale)
    Font.draw(text, 0, 0)
    love.graphics.pop()
    return scale
  end

  local function detachedLabelLayout(text, maxWidth, height, preferred)
    text = tostring(text or "")
    local singleScale = detachedInkScale(text, maxWidth, preferred)
    local best
    for split = 1, #text do
      if text:sub(split, split) == " " then
        local first = text:sub(1, split - 1)
        local second = text:sub(split + 1)
        if first ~= "" and second ~= "" then
          local widest = math.max(Font.width(first), Font.width(second))
          local scale = math.min(preferred, maxWidth / widest,
            (height - 6) / 16)
          if scale >= 1 and (not best or scale > best.scale) then
            best = { first, second, scale = scale }
          end
        end
      end
    end
    -- Wrapping has a visual cost, so use it only when it buys at least 25%
    -- more glyph size. Short names remain on the familiar single line.
    if best and best.scale >= singleScale * 1.25 then return best end
    return { text, scale = singleScale }
  end

  local function drawCodeInk(code, x, y, color, scale)
    love.graphics.push("all")
    local shader = shaderForInk()
    if shader then
      love.graphics.setShader(shader)
      love.graphics.setColor(rgb(color))
    else
      love.graphics.setColor(0, 0, 0, 1)
    end
    scale = math.max(1, tonumber(scale) or 1)
    love.graphics.translate(math.floor(x), math.floor(y))
    love.graphics.scale(scale, scale)
    Font.drawCode(code, 0, 0)
    love.graphics.pop()
  end

  local function chamfer(mode, x, y, w, h, cut)
    cut = math.max(1, math.min(cut or 2,
      math.floor(w / 2), math.floor(h / 2)))
    if love.graphics.polygon then
      love.graphics.polygon(mode, {
        x + cut, y, x + w - cut, y,
        x + w, y + cut, x + w, y + h - cut,
        x + w - cut, y + h, x + cut, y + h,
        x, y + h - cut, x, y + cut,
      })
    else
      love.graphics.rectangle(mode, x, y, w, h)
    end
  end

  local function setInkColor(color, alpha)
    local r, g, b = rgb(color)
    love.graphics.setColor(r, g, b, alpha == nil and 1 or alpha)
  end

  local function detachedOpacity()
    local value = tonumber(setting("opacity", "100")) or 100
    return math.max(0.55, math.min(1, value / 100))
  end

  local function clearRegion(game, x, y, w, h)
    local r, g, b = PaletteFX.paperShade(game and game.data)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("fill", x, y, w, h)
  end

  -- BattleState clips the native player picture at the TYPE/PP row whenever
  -- moveSelect is active, even when drawTextArea itself is suppressed. Flat
  -- battles therefore need one player-only redraw with that menu clip
  -- disabled. Transparent/custom renderers expose their own shot or clear the
  -- white letterbox and retain sole ownership of Pokemon composition.
  local function restoreDetachedPlayerPic(battle)
    if not (battle and battle.drawPicsLayer) then return end
    if rawget(battle, "dramaticShapeShot") ~= nil
        or battle.letterboxWhite == false then
      return
    end
    local fx = battle.fx
    local sx = fx and fx.shakeX or 0
    local sy = fx and fx.shakeY or 0
    if sx == 0 and sy == 0 and fx and fx.shake and fx.shake > 0 then
      sx = (battle.frame or 0) % 4 < 2 and 2 or -2
    end
    local slide = (battle.introSlide or 0) * 4
    battle:drawPicsLayer(slide, sx, sy, "player", true)
  end

  local function drawButton(game, moveType, x, y, w, h, selected, dense,
      content, detached, transparentSurface, skipClear)
    local colors = colorsFor(game, moveType)
    local strong = setting("strength", "bold") ~= "soft"
    -- Normal cards use black text. Selection inverts that relationship with
    -- white text on a deliberately darkened type face, a thicker black frame
    -- and a white rail. This remains obvious even when two neighbouring types
    -- have similar colours or the user has reduced card opacity.
    local rim = colors[selected and 4 or 2]
    local face = selected and darkerTypeColor(colors[3])
      or colors[strong and 3 or 2]
    local foreground = colors[selected and 1 or 4]
    local inset = dense and 1 or (selected and 3 or 2)
    local shadow = dense and 1 or 2
    local cut = dense and 1 or math.min(3, math.floor(h / 3))

    -- The wide battle grid has enough breathing room to let the focused
    -- button rise one pixel on every side. Dense 8-15px menu rows retain
    -- their footprint so adjacent cards never cover one another.
    if selected and not dense then
      x, y, w, h = x - 1, y - 1, w + 2, h + 2
      cut = math.min(3, math.floor(h / 3))
    end

    -- When native geometry remains underneath this additive overlay, clear
    -- its exact footprint so text and cursors cannot peek through chamfered
    -- corners. Fully owned replacement surfaces have already suppressed that
    -- geometry and must not receive a rectangular paper-colour backing.
    if not detached and not transparentSurface and not skipClear then
      clearRegion(game, x, y, w, h)
    end
    local opacity = (detached or transparentSurface)
      and detachedOpacity() or 1
    if opacity < 1 then
      -- Nested translucent fills compound into an almost opaque centre. In
      -- adjustable-alpha mode the face is therefore one fill and the shadow
      -- and rim become outlines. The selected rail remains translucent too,
      -- while content restores full opacity for legibility.
      if love.graphics.setLineWidth then
        love.graphics.setLineWidth(selected and 2 or 1)
      end
      setInkColor(colors[4], opacity * 0.7)
      chamfer("line", x + shadow, y + shadow,
        w - shadow, h - shadow, cut)
      setInkColor(face, opacity)
      chamfer("fill", x, y, w - shadow, h - shadow, cut)
      setInkColor(rim, math.min(1, opacity + 0.15))
      chamfer("line", x, y, w - shadow, h - shadow, cut)
    else
      setInkColor(colors[4])
      chamfer("fill", x + shadow, y + shadow,
        w - shadow, h - shadow, cut)
      setInkColor(rim)
      chamfer("fill", x, y, w - shadow, h - shadow, cut)
      setInkColor(face)
      chamfer("fill", x + inset, y + inset,
        w - shadow - inset * 2, h - shadow - inset * 2,
        math.max(1, cut - 1))
    end

    if selected then
      setInkColor(colors[1], opacity)
      love.graphics.rectangle("fill", x + inset, y + inset + 1,
        dense and 1 or 2,
        math.max(1, h - shadow - inset * 2 - 2))
    end

    content(foreground)
    if not detached then
      if skipClear then
        -- A full rectangular true-colour mark re-blits the paper pixels in
        -- the chamfered corners after a WORLD/keyed composition has removed
        -- them, producing a white block even though no explicit clear ran.
        -- Two inscribed rectangles cover the card ink without ever including
        -- its four outside corners. The dark shadow may follow the display
        -- palette; the face, rim, selection rail and text remain true-colour.
        local markW, markH = w - shadow, h - shadow
        if markW > cut * 2 and markH > 0 then
          PaletteFX.markTrueColor(x + cut, y,
            markW - cut * 2, markH)
        end
        if markW > 0 and markH > cut * 2 then
          PaletteFX.markTrueColor(x, y + cut,
            markW, markH - cut * 2)
        end
      else
        PaletteFX.markTrueColor(x, y, w, h)
      end
    end
  end
  inputPatch.detachedOpacity = detachedOpacity

  local function nativeGameRowGeometry(index, textX)
    textX = math.floor(tonumber(textX) or 48)
    local x = math.max(0, math.min(144, textX - 8))
    return {
      x = x, y = 96 + index * 8, w = 152 - x, h = 8,
      textX = textX, textWidth = math.max(0, 152 - textX),
    }
  end
  inputPatch.nativeGameRowGeometry = nativeGameRowGeometry

  local function nativeRowIndex(y, count)
    y = tonumber(y)
    if not y then return nil end
    local index = (y - 96) / 8
    if index ~= math.floor(index) or index < 1 or index > count then
      return nil
    end
    return index
  end

  -- Draw each GAME row at the exact origin used by the native renderer. The
  -- stock engine prints names at x=48 and the hand at x=40; long-name mods
  -- commonly move both 32 pixels left. Intercepting those glyph calls keeps
  -- the native box, TYPE/PP panel and vertical input authoritative while the
  -- coloured fill and ink follow either geometry with no doubled prefix.
  local function drawNativeGameRows(battle, drawOriginal, ...)
    local moves = battle and battle.player and battle.player.curMoves
    if type(moves) ~= "table" then return drawOriginal(battle, ...) end

    local selected = battle.moveIndex
    local originalDraw, originalDrawCode = Font.draw, Font.drawCode
    local rows, args = {}, { ... }
    local traceback = debug and debug.traceback
      or function(err) return tostring(err) end

    local function rowStyle(index)
      local def = moveDef(battle.game, moves[index])
      if not def then return nil end
      local colors = colorsFor(battle.game, def.type)
      local strong = setting("strength", "bold") ~= "soft"
      local focused = index == selected
      return {
        face = focused and darkerTypeColor(colors[3])
          or colors[strong and 3 or 2],
        foreground = colors[focused and 1 or 4],
      }
    end

    local function ensureRow(index, textX)
      if rows[index] then return rows[index] end
      local style = rowStyle(index)
      if not style then return nil end
      local row = nativeGameRowGeometry(index, textX)
      row.foreground = style.foreground
      rows[index] = row
      love.graphics.push("all")
      setInkColor(style.face, detachedOpacity())
      love.graphics.rectangle("fill", row.x, row.y, row.w, row.h)
      love.graphics.pop()
      PaletteFX.markTrueColor(row.x, row.y, row.w, row.h)
      return row
    end

    local function withForeground(color, draw)
      love.graphics.push("all")
      local shader = shaderForInk()
      if shader then
        love.graphics.setShader(shader)
        love.graphics.setColor(rgb(color))
      else
        love.graphics.setColor(0, 0, 0, 1)
      end
      local results = { xpcall(draw, traceback) }
      love.graphics.pop()
      if not results[1] then error(results[2], 0) end
      return unpack(results, 2)
    end

    Font.draw = function(value, x, y, ...)
      local callArgs = { ... }
      local index = nativeRowIndex(y, #moves)
      local def = index and moveDef(battle.game, moves[index])
      local label = def and tostring(def.name or moves[index].id or "")
      if not (index and label == tostring(value or "")) then
        return originalDraw(value, x, y, unpack(callArgs))
      end
      local row = ensureRow(index, x)
      if not row then
        return originalDraw(value, x, y, unpack(callArgs))
      end
      return withForeground(row.foreground, function()
        return originalDraw(value, x, y, unpack(callArgs))
      end)
    end

    Font.drawCode = function(code, x, y, ...)
      local callArgs = { ... }
      local index = (code == 0xED or code == 0xEC)
        and nativeRowIndex(y, #moves) or nil
      if not index then
        return originalDrawCode(code, x, y, unpack(callArgs))
      end
      local row = ensureRow(index, (tonumber(x) or 40) + 8)
      if not row then
        return originalDrawCode(code, x, y, unpack(callArgs))
      end
      return withForeground(row.foreground, function()
        return originalDrawCode(code, x, y, unpack(callArgs))
      end)
    end

    local results = { xpcall(function()
      return drawOriginal(battle, unpack(args))
    end, traceback) }
    Font.draw, Font.drawCode = originalDraw, originalDrawCode
    if not results[1] then error(results[2], 0) end
    return unpack(results, 2)
  end
  textPatch.nativeRows = nativeGamePresentation
  textPatch.drawNativeRows = drawNativeGameRows

  local function renderBattle(battle)
    if not componentEnabled() or textOnlyMode()
        or not setting("battle_colors", true) then return end
    if gen3BattleUIActive(battle and battle.game) then return end
    local phase = battle and battle.phase
    if phase ~= "moveSelect" and phase ~= "mimicSelect" then return end
    local moves = phase == "moveSelect"
      and battle.player and battle.player.curMoves or battle.mimicMoves
    local selected = phase == "moveSelect" and battle.moveIndex
      or battle.mimicIndex
    if type(moves) ~= "table" then return end

    if detachedGrid(battle) then
      -- The class-level drawTextArea wrapper already omitted the complete
      -- native menu before it touched the UI canvas. The finished-frame Wide
      -- presenter below is now the only owner of these phases.
      if phase == "moveSelect" then restoreDetachedPlayerPic(battle) end
      return
    end

    local wide = engineWide(battle)
    local transparentSurface = not wide and customBattleSurface(battle)
    local nativeGame = nativeGamePresentation(battle)
    if nativeGame and phase == "moveSelect" then
      -- Native GAME rows were coloured in-place by the drawTextArea wrapper,
      -- using the actual name/cursor origin chosen by the active renderer.
      return
    end
    if not wide and phase == "moveSelect" and not transparentSurface
        and not nativeGame then
      -- Replace the cramped lower half of the native list with four full-
      -- width buttons. The TYPE/PP panel immediately above remains native.
      clearRegion(battle.game, 0, 104, 160, 40)
    elseif not wide and not transparentSurface then
      -- Mimic's original narrow box has the same four-row constraint but no
      -- details panel, so its modal buttons can use the complete width.
      clearRegion(battle.game, 0, 64, 160, 40)
    end

    for i, move in ipairs(moves) do
      local def = moveDef(battle.game, move)
      if def then
        local x, y, w, h, textX, textY, dense
        if wide then
          local col = (i - 1) % 2
          local row = math.floor((i - 1) / 2)
          x, y, w, h = col == 0 and 4 or 110,
            106 + row * 18, col == 0 and 104 or 110, 16
          textX, textY, dense = x + 4, y + 4, false
        else
          x, y, w, h = 4,
            (phase == "moveSelect" and 104 or 64) + (i - 1) * 10,
            152, 9
          textX, textY, dense = 12, y + 1, true
        end
        drawButton(battle.game, def.type, x, y, w, h,
          i == selected, dense,
          function(foreground)
            drawInk(def.name or move.id, textX, textY,
              w - (textX - x) - 5, foreground)
          end, false, transparentSurface,
          false)
      end
    end

    if transparentSurface and phase == "moveSelect" then
      local selectedMove = moves[selected]
      local selectedDef = selectedMove and moveDef(battle.game, selectedMove)
      if selectedDef then
        local detailText
        if battle.player and battle.player.disabledSlot == selected then
          detailText = Strings("disabled!")
        else
          local maxPP = (selectedDef.pp or 0)
            + (selectedMove.ppUps or 0)
              * math.floor((selectedDef.pp or 0) / 5)
          detailText = (Strings("PP") .. " %d/%d")
            :format(selectedMove.pp or 0, maxPP)
        end
        drawButton(battle.game, selectedDef.type, 4, 84, 76, 17,
          false, false, function(foreground)
            drawInk(detailText, 8, 89, 68, foreground)
          end, false, true)
      end
    elseif not wide and phase == "moveSelect"
        and battle.player and battle.player.disabledSlot ~= selected then
      -- Preserve the native PP row and box, but remove its repeated TYPE/
      -- lines. The card colour already communicates type, and abbreviations
      -- such as FGT are both redundant and awkward.
      clearRegion(battle.game, 8, 72, 72, 16)
    end
  end

  local function renderTextOnlyBattle(battle)
    if not componentEnabled() or not textOnlyMode()
        or not setting("battle_colors", true)
        or gen3BattleUIActive(battle and battle.game) then
      return
    end
    local phase = battle and battle.phase
    if phase ~= "moveSelect" and phase ~= "mimicSelect" then return end
    local moves = phase == "moveSelect"
      and battle.player and battle.player.curMoves or battle.mimicMoves
    if type(moves) ~= "table" then return end

    local wide = engineWide(battle)
    for i, move in ipairs(moves) do
      local def = moveDef(battle.game, move)
      if def then
        local x, y, maxWidth, dotted
        if wide then
          local col = (i - 1) % 2
          local row = math.floor((i - 1) / 2)
          x, y, maxWidth, dotted = col == 0 and 16 or 120,
            112 + row * 16, 96, true
        elseif phase == "moveSelect" then
          x, y = 48, 96 + i * 8
        else
          x, y = 16, (7 + i) * 8
        end
        drawTypedText(battle.game, def, def.name or move.id,
          x, y, maxWidth, dotted)
      end
    end

    -- The native details panel already identifies the selected move's type.
    -- Colour only that value so players learn the type-to-colour association;
    -- TYPE/, PP and disabled-state text remain native.
    if phase == "moveSelect" then
      local selected = moves[battle.moveIndex]
      local def = selected and moveDef(battle.game, selected)
      local disabled = battle.player
        and battle.player.disabledSlot == battle.moveIndex
      if def and (wide or not disabled) then
        local label = TypeChart.displayName(def.type)
        if wide then
          drawTypedText(battle.game, def, label, 232, 128, 64, true)
        else
          drawTypedText(battle.game, def, label, 16, 80)
        end
      end
    end
  end

  -- A low-priority post-link draws before higher-priority post-overlays, so
  -- another mod's HUD or modal remains on top of these move chips.
  mod.hooks:wrap("battle.overlay", function(next, battle)
    next(battle)
    renderBattle(battle)
    renderTextOnlyBattle(battle)
  end, -100)

  local function activeBattle(game)
    local stack = game and game.stack
    local top = stack and stack.top and stack:top() or nil
    local phase = top and top.phase
    if phase == "moveSelect" or phase == "mimicSelect"
        or phase == "menu" or phase == "messages" then
      return top
    end
  end

  -- Builds the detached selector in screen-space units. Width chooses the
  -- preferred integer scale, but height caps the panel at roughly the bottom
  -- third of the usable display. Faithful 1x alone uses the same geometry at
  -- half scale so presentation and grid input do not change. When a wide,
  -- short phone hits the height cap, the native card widths expand instead
  -- of stretching pixels or wasting the remaining horizontal room.
  local function detachedLayout(screenW, screenH,
      safeX, safeY, safeW, safeH, nativeMoveY, controlsTopY)
    screenW = math.max(1, math.floor(tonumber(screenW) or 304))
    screenH = math.max(1, math.floor(tonumber(screenH) or 144))
    safeX = math.max(0, math.floor(tonumber(safeX) or 0))
    safeY = math.max(0, math.floor(tonumber(safeY) or 0))
    safeW = math.max(1, math.floor(tonumber(safeW) or screenW))
    safeH = math.max(1, math.floor(tonumber(safeH) or screenH))

    local panelH = 80
    local widthScale = math.floor((safeW - 16) / 304)
    local heightScale = math.floor((safeH * 0.34) / panelH)
    local scale
    if widthScale >= 1 and heightScale >= 1 then
      scale = math.min(6, widthScale, heightScale)
    else
      -- Faithful 1x has only 160 drawable units. Retain the normal 304px
      -- two-by-two geometry at half scale instead of changing presentation
      -- or navigation. Larger surfaces remain integer-scaled pixel art.
      local widthFit = (safeW - 8) / 304
      local heightFit = (safeH * 0.34) / panelH
      scale = math.max(0.5, math.min(1, widthFit, heightFit))
    end
    local margin = scale < 1 and math.max(2, math.floor(8 * scale + 0.5))
      or math.max(8, scale * 2)
    local panelW = math.max(240,
      math.floor((safeW - margin * 2) / scale))

    local detailW = math.max(80,
      math.min(128, math.floor(panelW * 0.26)))
    local detailX = panelW - detailW - 2
    local gridX = 2
    local gridRight = detailX - 4
    local gridW = math.max(150, gridRight - gridX)
    local columnGap = 3
    local leftW = math.floor((gridW - columnGap) / 2)
    local rightX = gridX + leftW + columnGap
    local rightW = gridRight - rightX

    local bottomY = safeY + safeH - panelH * scale - margin
    local originY = bottomY
    if tonumber(nativeMoveY) then
      -- The classic battle's move box starts at row 13 (y=104), eight
      -- logical pixels below the player HUD. On tall phones, docking only to
      -- the safe-area bottom can put the controls hundreds of pixels away
      -- from the battle information. Treat that native row as a maximum
      -- distance: bottom docking still wins when it is already closer, while
      -- portrait layouts rise back underneath the player HUD.
      originY = math.min(bottomY, math.floor(nativeMoveY))
      originY = math.max(safeY, originY)
    end
    if tonumber(controlsTopY) then
      -- TouchControls is drawn after render.hud, so the move selector must
      -- reserve its visible top edge now. This uses the player's live custom
      -- portrait layout rather than guessing at a device-specific footer.
      local aboveControls = math.floor(controlsTopY
        - panelH * scale - margin)
      originY = math.max(safeY, math.min(originY, aboveControls))
    end

    return {
      scale = scale, margin = margin,
      panelW = panelW, panelH = panelH,
      originX = safeX + math.floor((safeW - panelW * scale) / 2),
      originY = originY,
      gridX = gridX, leftW = leftW,
      rightX = rightX, rightW = rightW,
      detailX = detailX, detailW = detailW,
    }
  end
  inputPatch.detachedLayout = detachedLayout

  local function portraitControlsTop(safeW, safeH, dpiY)
    if safeH <= safeW then return nil end
    local okVisible, visible = pcall(TouchControls.visible, TouchControls)
    if not okVisible or not visible then return nil end
    local okLayout, controls = pcall(TouchControls.layout, TouchControls)
    if not okLayout or type(controls) ~= "table" then return nil end
    local top
    for _, name in ipairs({ "dpad", "a", "b", "start", "select" }) do
      local zone = controls[name]
      if type(zone) == "table" and tonumber(zone.cy)
          and tonumber(zone.w) then
        -- drawIcon's backing disc has radius 0.58w and is the uppermost
        -- visible part of each control.
        local y = (zone.cy - zone.w * 0.58) * dpiY
        top = not top and y or math.min(top, y)
      end
    end
    return top
  end
  inputPatch.portraitControlsTop = portraitControlsTop

  local function drawDetachedCommandPanel(game, battle, layout)
    local labels = {
      Strings("FIGHT", "battle"), Strings("PKMN"),
      Strings("ITEM", "battle"), Strings("RUN", "battle"),
    }
    local promptX, promptW = 2, layout.detailW
    local actionX = promptX + promptW + 4
    local actionRight = layout.panelW - 2
    local actionGap = 3
    local actionLeftW = math.floor((actionRight - actionX - actionGap) / 2)
    local actionRightX = actionX + actionLeftW + actionGap
    local actionRightW = actionRight - actionRightX
    for i, label in ipairs(labels) do
      local col = (i - 1) % 2
      local row = math.floor((i - 1) / 2)
      local x = col == 0 and actionX or actionRightX
      local y = 2 + row * 38
      local w = col == 0 and actionLeftW or actionRightW
      drawButton(game, "NORMAL", x, y, w, 36,
        battle.menuIndex == i, false, function(foreground)
          local textScale = detachedInkScale(label, w - 10,
            layout.fontScale, 0.75)
          drawDetachedInk(label, x + 5,
            y + math.floor((36 - 8 * textScale) / 2),
            w - 10, foreground, textScale, 0.75)
        end, true)
    end

    -- Match the move selector's attached PP card with a neutral prompt card.
    -- The HP/name HUD remains renderer-owned; this is only the command prompt
    -- that used to live inside the old Game Boy menu box.
    local x, w = promptX, promptW
    drawButton(game, "NORMAL", x, 2, w, 74, false, false,
      function(foreground)
        local name = battle.player and battle.player.name or ""
        local textScale = math.min(
          detachedInkScale("WHAT WILL", w - 12, layout.fontScale),
          detachedInkScale(name, w - 12, layout.fontScale),
          detachedInkScale("DO", w - 12, layout.fontScale), 2)
        local lineH = 8 * textScale
        local gap = math.max(2, (74 - lineH * 3) / 4)
        local y = 2 + gap
        drawDetachedInk("WHAT WILL", x + 6, y,
          w - 12, foreground, textScale)
        drawDetachedInk(name, x + 6, y + lineH + gap,
          w - 12, foreground, textScale)
        drawDetachedInk("DO", x + 6, y + (lineH + gap) * 2,
          w - 12, foreground, textScale)
      end, true)
  end

  local function drawDetachedMessagePanel(game, battle, layout)
    drawButton(game, "NORMAL", 2, 2, layout.panelW - 4, 74,
      false, false, function(foreground)
        if battle.scrollPx and battle.scrollPx > 0 then
          battle.scrollPx = battle.scrollPx - 2
          if battle.scrollPx <= 0 then battle.scrollPx = nil end
        end
        local off = battle.scrollPx or 0
        local shown = battle.shown or {}
        local longest = 1
        for _, line in ipairs(shown) do longest = math.max(longest, #line) end
        local textScale = math.min(layout.fontScale,
          (layout.panelW - 20) / (longest * 8), 2.5)
        local lineH = 8 * textScale
        local lineGap = math.max(4, (74 - lineH * 2) / 3)
        for lineIndex, line in ipairs(shown) do
          local y = 2 + lineGap
            + (lineIndex - 1) * (lineH + lineGap) + off
          for i = 1, #line do
            drawCodeInk(line[i], 10 + (i - 1) * 8 * textScale,
              y, foreground, textScale)
          end
        end
        if (battle.msgWaiting or battle.msgPrompt)
            and (battle.frame or 0) % 60 < 30 then
          drawEffectArrow(layout.panelW - 12, 62, "down", foreground)
        end
      end, true)
  end

  -- Responsive Wide battle panel drawn after the completed world/UI composite.
  -- It never changes Renderer.uiSize or BattleState's drawing path, so staged
  -- 3D battles keep every pixel of their background. Its 80px-tall native
  -- control area scales by a height-safe integer and then expands its card
  -- widths to fill the usable display. It follows the normal move-menu row
  -- beneath the player HUD, but may dock lower when the device bottom is
  -- already closer. Only the five chamfered cards cover the world.
  local function renderDetachedBattle(game, viewport)
    if not componentEnabled() or textOnlyMode()
        or not setting("battle_colors", true) then return end
    local battle = activeBattle(game)
    if not battle or not widePresentationOwnsPhase(battle) then return end
    local phase = battle.phase
    local moves, selected
    if phase == "moveSelect" or phase == "mimicSelect" then
      moves = phase == "moveSelect"
        and battle.player and battle.player.curMoves or battle.mimicMoves
      selected = phase == "moveSelect" and battle.moveIndex
        or battle.mimicIndex
      if type(moves) ~= "table" or #moves == 0 then return end
    end

    local unitW = viewport and viewport.width
      or love.graphics.getWidth and love.graphics.getWidth() or 304
    local unitH = viewport and viewport.height
      or love.graphics.getHeight and love.graphics.getHeight() or 144
    local dpiX = viewport and tonumber(viewport.dpiX)
    local dpiY = viewport and tonumber(viewport.dpiY)
    if not dpiX or not dpiY then dpiX, dpiY = windowPixelRatio() end
    if dpiX <= 0 then dpiX = 1 end
    if dpiY <= 0 then dpiY = 1 end
    local screenW, screenH = unitW * dpiX, unitH * dpiY
    local safeX, safeY, safeW, safeH = 0, 0, screenW, screenH
    local actualW, actualH = love.graphics.getDimensions()
    -- Synthetic/headless viewports deliberately differ from the graphics
    -- stub. In the real renderer they match, so only then consult the device
    -- safe area for Android navigation bars, cutouts and iOS home indicators.
    if math.abs(actualW - unitW) < 1 and math.abs(actualH - unitH) < 1 then
      local unitX, unitY, safeUnitW, safeUnitH = SafeArea.rect()
      safeX, safeY = unitX * dpiX, unitY * dpiY
      safeW, safeH = safeUnitW * dpiX, safeUnitH * dpiY
    end
    -- Touch controls live in window space, so detect portrait before the OG
    -- panel bounds are narrowed to the landscape-shaped battle rectangle.
    local controlsTopY = portraitControlsTop(safeW, safeH, dpiY)
    local customBattleSurface = rawget(battle, "dramaticShapeShot") ~= nil
      or battle.letterboxWhite == false
    -- A flat/OG battle is still a 160x144 composition even when WORLD or an
    -- unusual phone aspect fills the rest of the window. Keep replacement
    -- controls inside that exact presented rectangle. Staged renderers such
    -- as Battle Art intentionally own the whole screen and retain the wider
    -- detached treatment that already follows their composition.
    if not customBattleSurface and viewport
        and tonumber(viewport.gameX) and tonumber(viewport.gameY)
        and tonumber(viewport.gameWidth) and tonumber(viewport.gameHeight) then
      local gameX = viewport.gameX * dpiX
      local gameY = viewport.gameY * dpiY
      local gameRight = gameX + viewport.gameWidth * dpiX
      local gameBottom = gameY + viewport.gameHeight * dpiY
      local safeRight, safeBottom = safeX + safeW, safeY + safeH
      safeX, safeY = math.max(safeX, gameX), math.max(safeY, gameY)
      safeW = math.max(1, math.min(safeRight, gameRight) - safeX)
      safeH = math.max(1, math.min(safeBottom, gameBottom) - safeY)
    end
    local nativeMoveY
    if viewport and tonumber(viewport.gameY) and tonumber(viewport.scale) then
      -- Start at the game's native control row, leaving the original eight-
      -- pixel separation below the Pokemon field. This keeps scaled panels
      -- from touching or slightly covering the player sprite.
      local nativeRow = 104
      nativeMoveY = viewport.gameY * dpiY + nativeRow * viewport.scale
    end
    local layout = detachedLayout(screenW, screenH,
      safeX, safeY, safeW, safeH, nativeMoveY, controlsTopY)
    local battleScale = viewport and tonumber(viewport.scale)
      or layout.scale
    layout.fontScale = math.max(1,
      math.min(2.5, battleScale / layout.scale))

    love.graphics.push("all")
    love.graphics.translate(layout.originX / dpiX, layout.originY / dpiY)
    love.graphics.scale(layout.scale / dpiX, layout.scale / dpiY)

    if phase == "menu" then
      drawDetachedCommandPanel(game, battle, layout)
      love.graphics.pop()
      return
    elseif phase == "messages" then
      drawDetachedMessagePanel(game, battle, layout)
      love.graphics.pop()
      return
    end

    local twoRows = #moves > 2
    local buttonH = twoRows and 36 or 74
    local rowStep = twoRows and 38 or 0
    for i, move in ipairs(moves) do
      if i > 4 then break end
      local def = moveDef(game, move)
      if def then
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local x, y = col == 0 and layout.gridX or layout.rightX,
          2 + row * rowStep
        local w, h = col == 0 and layout.leftW or layout.rightW, buttonH
        local indicator = phase == "moveSelect"
          and effectIndicator(battle, def)
        drawButton(game, def.type, x, y, w, h, i == selected, false,
          function(foreground)
            local textX = x + 4
            local label = def.name or move.id
            local labelLayout = detachedLabelLayout(label, w - 9, h,
              layout.fontScale)
            if #labelLayout == 1 then
              local textY = y
                + math.floor((h - 8 * labelLayout.scale) / 2)
              drawDetachedInk(labelLayout[1], textX, textY,
                w - 9, foreground, labelLayout.scale)
            else
              local lineH = 8 * labelLayout.scale
              local gap = 2
              local textY = y
                + math.floor((h - lineH * 2 - gap) / 2)
              drawDetachedInk(labelLayout[1], textX, textY,
                w - 9, foreground, labelLayout.scale)
              drawDetachedInk(labelLayout[2], textX,
                textY + lineH + gap, w - 9,
                foreground, labelLayout.scale)
            end
            drawEffectIndicator(indicator, x, y, w, h, foreground)
          end, true)
      end
    end

    local selectedMove = moves[selected]
    local def = selectedMove and moveDef(game, selectedMove)
    if def then
      -- Keep move cards themselves name-only, but give the attached details
      -- card the complete decision information: full type name (never the old
      -- FGT/WTR abbreviations), power and PP. Status moves use --- for power,
      -- matching the convention that they have no damage base power.
      local detailX, detailW = layout.detailX, layout.detailW
      local textX = detailX + 6
      drawButton(game, def.type, detailX, 2, detailW, 74, true, false,
        function(foreground)
          local power = type(def.power) == "number" and def.power > 0
            and tostring(math.floor(def.power)) or "---"
          local typeText = TypeChart.displayName(def.type)
          local powerText = Strings("POWER") .. " " .. power
          local ppText
          if phase == "moveSelect" then
            local maxPP = (def.pp or 0)
              + (selectedMove.ppUps or 0) * math.floor((def.pp or 0) / 5)
            ppText = (Strings("PP") .. " %d/%d")
              :format(selectedMove.pp or 0, maxPP)
          else
            ppText = Strings("COPY")
          end
          local available = detailW - 12
          local fixedScale, typeScale = detailInkScales(
            typeText, available, layout.fontScale)
          local scales = { typeScale, fixedScale, fixedScale }
          local ys = { 8, 31, 54 }
          drawDetachedInk(typeText, textX, ys[1], available,
            foreground, scales[1], 0.75)
          drawDetachedInk(powerText, textX, ys[2], available,
            foreground, scales[2])
          drawDetachedInk(ppText, textX, ys[3], available,
            foreground, scales[3])
        end, true)
    end

    love.graphics.pop()
  end

  mod.hooks:wrap("render.hud", function(next, game, viewport)
    local result = next(game, viewport)
    local ok, err = pcall(renderDetachedBattle, game, viewport)
    if not ok and not mod._typedMoveHudWarned then
      mod._typedMoveHudWarned = true
      mod.log:warn("responsive move panel skipped: %s", tostring(err))
    end
    return result
  end, -100)

  -- Gen 3 Inspired UI Overhaul owns a final-resolution move list instead of
  -- the engine's 160x144 menu. Keep its layout, typography, PP readout and
  -- selection controls intact, then multiply the type palette through its
  -- own rounded rows. Black text stays black, antialiasing is preserved and
  -- the selected dark row remains visibly selected. This post-link runs
  -- outside both of Gen 3 UI's render.hud links (10000 and 11000), so it sees
  -- the finished companion panel and never needs to replace its renderer.
  local function gen3MoveGeometry(screenW, screenH)
    local function clamp(value, low, high)
      return math.max(low, math.min(high, value))
    end
    local raw = math.min(screenW / 1280, screenH / 720)
    local unit
    if raw <= 1.5 then
      unit = clamp(raw, 0.68, 1.18)
    else
      unit = clamp(1.18 + (raw - 1.5) * 0.75, 1.18, 2.30)
    end
    local width = clamp(720 * unit, 470, 1660)
    local height = clamp(300 * unit, 205, 690)
    local margin = clamp(24 * unit, 14, 56)
    return {
      x = screenW - width - margin,
      y = screenH - height - margin,
      w = width,
      h = height,
      u = unit,
    }
  end
  inputPatch.gen3MoveGeometry = gen3MoveGeometry

  local function renderGen3BattleColors(game)
    if not componentEnabled() or textOnlyMode()
        or not setting("battle_colors", true)
        or not gen3BattleUIActive(game) then return end
    local battle = activeBattle(game)
    if not (battle and battle.phase == "moveSelect"
        and battle.player and type(battle.player.curMoves) == "table") then
      return
    end

    local moves = battle.player.curMoves
    local screenW, screenH = love.graphics.getDimensions()
    local rect = gen3MoveGeometry(screenW, screenH)
    local unit = rect.u
    local pad = 16 * unit
    local gap = 8 * unit
    local infoH = 50 * unit
    local listTop = rect.y + pad
    local listBottom = rect.y + rect.h - pad - infoH - 7 * unit
    local rowH = (listBottom - listTop - gap * 3) / 4
    local rowW = rect.w - pad * 2
    local strong = setting("strength", "bold") ~= "soft"
    local selected = battle.moveIndex
    local selectedRect
    local infoTypeMask

    love.graphics.push("all")
    local blendOK = pcall(love.graphics.setBlendMode,
      "multiply", "premultiplied")
    if not blendOK then love.graphics.setBlendMode("multiply") end

    for i = 1, 4 do
      local move = moves[i]
      local def = move and moveDef(game, move)
      if def then
        local colors = colorsFor(game, def.type)
        local focused = selected == i
        local face = colors[focused and 2 or (strong and 3 or 2)]
        local y = listTop + (i - 1) * (rowH + gap)
        local inset = focused and 0 or 2 * unit
        love.graphics.setColor(rgb(face))
        love.graphics.rectangle("fill",
          rect.x + pad + inset, y + inset,
          rowW - inset * 2, rowH - inset * 2,
          (focused and 9 or 7) * unit,
          (focused and 9 or 7) * unit)
        if focused then
          selectedRect = { x = rect.x + pad, y = y, w = rowW, h = rowH }
        end
      end
    end

    local selectedMove = selected and moves[selected]
    local selectedDef = selectedMove and moveDef(game, selectedMove)
    if selectedDef then
      local colors = colorsFor(game, selectedDef.type)
      local face = colors[strong and 3 or 2]
      local infoY = rect.y + rect.h - pad - infoH
      love.graphics.setColor(rgb(face))
      love.graphics.rectangle("fill", rect.x + pad, infoY,
        rowW, infoH, 9 * unit, 9 * unit)
      local faceR, faceG, faceB = rgb(face)
      local maskX = rect.x + pad + 8 * unit
      local ppLeft = rect.x + rect.w - pad - 190 * unit
      infoTypeMask = {
        x = maskX,
        y = infoY + 4 * unit,
        w = math.max(0, ppLeft - maskX - 6 * unit),
        h = infoH - 8 * unit,
        color = { faceR * 0.90, faceG * 0.91, faceB * 0.89 },
      }
    end

    if infoTypeMask and infoTypeMask.w > 0 then
      -- Gen 3 UI prints TYPE + name on the left and PP on the right. Cover
      -- only the repeated type text with the exact multiplied interior fill;
      -- the companion's PP typography and rounded border stay untouched.
      love.graphics.setBlendMode("alpha")
      love.graphics.setColor(infoTypeMask.color[1], infoTypeMask.color[2],
        infoTypeMask.color[3], 1)
      love.graphics.rectangle("fill", infoTypeMask.x, infoTypeMask.y,
        infoTypeMask.w, infoTypeMask.h)
    end

    if selectedRect then
      love.graphics.setBlendMode("alpha")
      love.graphics.setLineWidth(math.max(2, math.min(5, 2.25 * unit)))
      love.graphics.setColor(0, 0, 0, 0.92)
      love.graphics.rectangle("line", selectedRect.x, selectedRect.y,
        selectedRect.w, selectedRect.h, 9 * unit, 9 * unit)
    end
    love.graphics.pop()
  end

  mod.hooks:wrap("render.hud", function(next, game, viewport)
    local result = next(game, viewport)
    local ok, err = pcall(renderGen3BattleColors, game)
    if not ok and not mod._typedMoveGen3Warned then
      mod._typedMoveGen3Warned = true
      mod.log:warn("Gen 3 battle move colours skipped: %s", tostring(err))
    end
    return result
  end, 12000)

  local function renderSummary(screen)
    if not componentEnabled() or not setting("menu_colors", true)
        or screen.page ~= 2
        or not isTop(screen) then return end
    local game, mon = screen.game, screen.mon
    for i = 1, 4 do
      local move = mon and mon.moves and mon.moves[i]
      local def = move and moveDef(game, move)
      if def then
        local y = 72 + (i - 1) * 16
        if textOnlyMode() then
          drawTypedText(game, def, def.name or move.id, 16, y)
        else
          -- Native Summary PP glyphs occupy the complete 16-pixel row. The
          -- replacement card deliberately stops one pixel short to retain a
          -- gap, so clear that final scanline as well; otherwise the bottom
          -- pixel of the native slash remains visible between every card.
          clearRegion(game, 8, y + 15, 144, 1)
          drawButton(game, def.type, 8, y, 144, 15, false, true,
            function(foreground)
              drawFittedInk(def.name or move.id, 12, y, 138, foreground)
              drawInk(Strings("PP"), 88, y + 7, 16, foreground)
              local maxPP = (def.pp or 0)
                + (move.ppUps or 0) * math.floor((def.pp or 0) / 5)
              drawInk(("%2d/%2d"):format(move.pp or 0, maxPP),
                110, y + 7, 40, foreground)
            end)
        end
      end
    end
  end

  local function renderMoveLearn(screen)
    if not componentEnabled() or not setting("menu_colors", true)
        or not screen.selecting
        or not isTop(screen) then return end
    local rowBase = screen._typedMoveColorsUsefulInfo and 4 or 5
    local nativeInkOnly = textOnlyMode() or stagedBattleBehind(screen)
    for i, move in ipairs(screen.mon and screen.mon.moves or {}) do
      local def = moveDef(screen.game, move)
      if def then
        local y = (rowBase + i) * 8
        if nativeInkOnly then
          drawTypedText(screen.game, def, def.name or move.id, 48, y)
        else
          drawButton(screen.game, def.type, 46, y, 106, 8,
            i == screen.index, true, function(foreground)
              drawInk(def.name or move.id, 48, y, 102, foreground)
            end)
        end
      end
    end
    -- Useful Move Info adds an inspect-only NEW MOVE row before CANCEL and
    -- shifts the list up one tile. Its instance-level draw method bypasses
    -- MoveLearnMenu.draw, so the adapter below marks that layout and this
    -- renderer gives the added row the same live type treatment.
    if screen._typedMoveColorsUsefulInfo and screen.newMoveId then
      local index = #(screen.mon and screen.mon.moves or {}) + 1
      local def = moveDef(screen.game, screen.newMoveId)
      if def then
        local y = (rowBase + index) * 8
        local label = def.name or screen.newMoveId
        if Font.width(label) + Font.width(" NEW") <= 100 then
          label = label .. " NEW"
        end
        if nativeInkOnly then
          drawTypedText(screen.game, def,
            def.name or screen.newMoveId, 48, y)
        else
          drawButton(screen.game, def.type, 46, y, 106, 8,
            screen.index == index, true, function(foreground)
              drawInk(label, 48, y, 102, foreground)
            end)
        end
      end
    end
  end

  local function safeDrawPatch(class, key, renderer)
    local state = rawget(class, key)
    if not state then
      state = { original = class.draw, renderer = renderer }
      rawset(class, key, state)
      class.draw = function(self, ...)
        state.original(self, ...)
        if state.renderer then
          local ok, err = pcall(state.renderer, self)
          if not ok and not state.warned then
            state.warned = true
            mod.log:warn("move-colour overlay skipped: %s", tostring(err))
          end
        end
      end
    else
      state.renderer = renderer
      state.warned = nil
    end
  end

  safeDrawPatch(SummaryMenu, "_typedMoveColorsPatch", renderSummary)
  safeDrawPatch(MoveLearnMenu, "_typedMoveColorsPatch", renderMoveLearn)

  -- Useful Move Info owns MoveLearnMenu through the screen registry and
  -- installs its draw method on each instance. Compose with that factory
  -- after it has built the enhanced controller, leaving its input, NEW row,
  -- HM protection and info boxes untouched while restoring this mod's final
  -- presentation pass.
  if mod.find("useful_move_info") then
    local record = mod.content.screens:get("MoveLearnMenu")
    if type(record) == "table" and type(record.new) == "function" then
      mod.content.screens:override("MoveLearnMenu", {
        new = function(...)
          local screen = record.new(...)
          if type(screen) ~= "table" then return screen end
          screen._typedMoveColorsUsefulInfo = true
          local usefulDraw = screen.draw
          if type(usefulDraw) == "function" then
            screen.draw = function(self, ...)
              local result = usefulDraw(self, ...)
              local ok, err = pcall(renderMoveLearn, self)
              if not ok and not self._typedMoveColorsWarned then
                self._typedMoveColorsWarned = true
                mod.log:warn("Useful Move Info colours skipped: %s",
                  tostring(err))
              end
              return result
            end
          end
          return screen
        end,
      })
    else
      mod.log:warn("Useful Move Info MoveLearnMenu adapter was unavailable")
    end
  end

  local listState = rawget(ListMenu, "_typedMoveColorsPatch")
  if not listState then
    listState = { originalNew = ListMenu.new, originalDraw = ListMenu.draw }
    rawset(ListMenu, "_typedMoveColorsPatch", listState)
    ListMenu.new = function(...)
      local screen = listState.originalNew(...)
      if listState.decorate then
        local ok, err = pcall(listState.decorate, screen, ...)
        if not ok and not listState.warned then
          listState.warned = true
          mod.log:warn("move-list detection skipped: %s", tostring(err))
        end
      end
      return screen
    end
    ListMenu.draw = function(self, ...)
      listState.originalDraw(self, ...)
      if listState.renderer then
        local ok, err = pcall(listState.renderer, self)
        if not ok and not listState.warned then
          listState.warned = true
          mod.log:warn("move-list colours skipped: %s", tostring(err))
        end
      end
    end
  end

  listState.decorate = function(screen, game, title, items)
    if not componentEnabled() or title ~= "Which move?"
        or type(items) ~= "table" then return end
    local byName = {}
    for id, def in pairs(game.data and game.data.moves or {}) do
      if def.name then byName[def.name] = { id = id, type = def.type } end
    end
    local types, found = {}, 0
    for i, item in ipairs(items) do
      local hit = byName[item.label]
      if hit then types[i], found = hit.type, found + 1 end
    end
    if found > 0 then screen._typedMoveColors = types end
  end

  listState.renderer = function(screen)
    if not componentEnabled() or not setting("menu_colors", true)
        or not screen._typedMoveColors
        or not isTop(screen) then return end
    for row = 1, screen.rows do
      local i = screen.scroll + row
      local item, moveType = screen.items[i], screen._typedMoveColors[i]
      if not item then break end
      if moveType then
        local y = 8 + row * 16
        if textOnlyMode() then
          drawTypedText(screen.game, { type = moveType },
            item.label, 16, y)
        else
          drawButton(screen.game, moveType, 12, y - 2, 142, 14,
            i == screen.index, false, function(foreground)
              drawInk(item.label, 18, y + 1,
                item.right and 102 or 130, foreground)
              if item.right then
                local width = Font.width(item.right)
                drawInk(item.right, 148 - width, y + 1, width, foreground)
              end
            end)
        end
      end
    end
  end
end
