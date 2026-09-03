-- Type-coloured 2x2 move cards over Gen 2's native battle controller. The
-- move list, PP, disable state, swapping and choice callbacks remain native.
return function(mod)
  local Chrome = require("src.ui.gen2.Chrome")
  local Font = require("src.render.Font")
  local SummaryMenu = require("src.ui.gen2.SummaryMenu")

  -- The same flat faces used by the Gen 1 presenter. Keeping these values in
  -- lockstep is more important than preserving Gold's own type palettes: the
  -- cards are mod-owned UI, and should look like the same mod in either game.
  local COLORS = {
    normal = { 144 / 255, 152 / 255, 162 / 255 },
    fighting = { 206 / 255, 63 / 255, 107 / 255 },
    flying = { 143 / 255, 168 / 255, 222 / 255 },
    poison = { 171 / 255, 106 / 255, 200 / 255 },
    ground = { 217 / 255, 119 / 255, 70 / 255 },
    rock = { 201 / 255, 182 / 255, 139 / 255 },
    bug = { 144 / 255, 192 / 255, 44 / 255 },
    ghost = { 82 / 255, 105 / 255, 173 / 255 },
    fire = { 254 / 255, 156 / 255, 85 / 255 },
    water = { 77 / 255, 144 / 255, 214 / 255 },
    grass = { 101 / 255, 188 / 255, 94 / 255 },
    electric = { 244 / 255, 210 / 255, 59 / 255 },
    psychic = { 249 / 255, 113 / 255, 119 / 255 },
    ice = { 115 / 255, 206 / 255, 191 / 255 },
    dragon = { 9 / 255, 109 / 255, 195 / 255 },
    dark = { 91 / 255, 82 / 255, 101 / 255 },
    fairy = { 236 / 255, 144 / 255, 231 / 255 },
    steel = { 91 / 255, 142 / 255, 161 / 255 },
  }

  local function option(key, fallback)
    local value = mod.options:get(key)
    if value == nil then return fallback end
    return value
  end

  -- The Gen 2 presenter below is a two-column card grid in both saved layout
  -- modes.  Navigation must therefore follow what is actually on screen;
  -- conditioning it on the older Gen 1 WIDE/GAME preference made GAME show
  -- horizontal cards while retaining vertical-only input.
  local function gridEnabled()
    return option("battle_colors", true) ~= false
  end

  local function movePhase(screen)
    return screen and (screen.phase == "moves" or screen.phase == "moveSelect")
  end

  -- Gen 2 has shipped with both the dedicated Gold/Silver controller
  -- (`moves`) and the earlier shared battle controller (`moveSelect`).  Keep
  -- the presenter and its input adapter data-shaped so one package works on
  -- either API 2 build.
  local function playerMoves(screen)
    if type(screen and screen.playerMoves) == "function" then
      local ok, moves = pcall(screen.playerMoves, screen)
      if ok and type(moves) == "table" then return moves end
    end
    local player = screen and (screen.player
      or (screen.battle and screen.battle.player))
    return type(player and player.curMoves) == "table" and player.curMoves
      or type(player and player.moves) == "table" and player.moves or {}
  end

  local function gridTarget(index, count, direction)
    index = math.max(1, math.min(tonumber(index) or 1, math.max(1, count)))
    local col, row = (index - 1) % 2, math.floor((index - 1) / 2)
    if direction == "left" or direction == "right" then
      col = 1 - col
    elseif direction == "up" or direction == "down" then
      row = 1 - row
    end
    local target = row * 2 + col + 1
    return target <= count and target or index
  end

  local function moveDef(screen, move)
    return screen and screen.game and screen.game.data
      and screen.game.data.moves and move
      and screen.game.data.moves[move.id]
  end

  local function typeColor(def)
    return COLORS[tostring(def and def.type or "normal"):lower()]
      or COLORS.normal
  end

  local function strength(color)
    local mode = option("strength", "bold")
    local mix = mode == "soft" and 0.42 or mode == "vibrant" and 0.08 or 0.24
    return color[1] + (1 - color[1]) * mix,
      color[2] + (1 - color[2]) * mix,
      color[3] + (1 - color[3]) * mix
  end

  local function alpha()
    return math.max(0.2, math.min(1,
      (tonumber(option("opacity", "100")) or 100) / 100))
  end

  local function trim(text, length)
    text = tostring(text or "MOVE")
    if #text <= length then return text end
    return text:sub(1, math.max(1, length - 1)) .. "."
  end

  local function inkPalette(color)
    color = color or { 0, 0, 0 }
    local ink = {}
    for i = 1, 3 do
      local value = color[i] or 0
      ink[i] = math.floor((value <= 1 and value * 255 or value) + 0.5)
    end
    -- Only shade four is used by the opaque pixels in the extracted font.
    -- Supplying a complete ramp keeps antialiased/TTF fallback glyphs sane.
    return {
      { 255, 255, 255 },
      { math.floor((255 + ink[1]) / 2), math.floor((255 + ink[2]) / 2),
        math.floor((255 + ink[3]) / 2) },
      { math.floor(ink[1] * 0.5), math.floor(ink[2] * 0.5),
        math.floor(ink[3] * 0.5) },
      ink,
    }
  end

  -- Every string on a type card uses ink-only rendering. Chrome.print and
  -- Chrome.printThrough emulate a tilemap write by repainting the complete
  -- glyph cell with white paper; that is correct for cartridge text boxes but
  -- creates the white labels the Gen 1 card renderer deliberately avoids.
  local function printCardInk(text, x, y, color)
    local palette, drawGlyph, finish = Chrome.paletteGlyphs(
      inkPalette(color), false, true)
    if not palette then
      love.graphics.setColor(0, 0, 0, 1)
      return Font.draw(text, math.floor(x), math.floor(y))
    end
    local pen = math.floor(x)
    for _, code in ipairs(Font.encode(text)) do
      drawGlyph(code, pen, math.floor(y))
      pen = pen + Font.advanceOf(code)
    end
    finish()
    return pen - math.floor(x)
  end

  local function printCardInkRight(text, right, y, color)
    text = tostring(text or "")
    local width = Font.width(text)
    local palette, drawGlyph, finish = Chrome.paletteGlyphs(
      inkPalette(color), false, true)
    if not palette then
      love.graphics.setColor(0, 0, 0, 1)
      return Font.draw(text, math.floor(right) - width, math.floor(y))
    end
    local pen = math.floor(right) - width
    for _, code in ipairs(Font.encode(text)) do
      drawGlyph(code, pen, math.floor(y))
      pen = pen + Font.advanceOf(code)
    end
    finish()
    return width
  end

  local function fit(text, maxWidth)
    text = tostring(text or "")
    if Font.width(text) <= maxWidth then return text end
    while #text > 1 and Font.width(text .. ".") > maxWidth do
      text = text:sub(1, -2)
    end
    return text .. "."
  end

  local function chamfer(mode, x, y, w, h, cut)
    cut = math.max(0, math.min(cut or 0, math.floor(math.min(w, h) / 2)))
    if cut == 0 or not love.graphics.polygon then
      love.graphics.rectangle(mode, x, y, w, h)
      return
    end
    love.graphics.polygon(mode, {
      x + cut, y, x + w - cut, y, x + w, y + cut,
      x + w, y + h - cut, x + w - cut, y + h,
      x + cut, y + h, x, y + h - cut, x, y + cut,
    })
  end

  local function darken(color, amount)
    return color[1] * amount, color[2] * amount, color[3] * amount
  end

  -- Match the RBY marker vocabulary already used by this mod: one up arrow
  -- for neutral HP damage, two for super-effective, down for resisted, and a
  -- circle for status or immune moves.  Gen 2 keeps its chart in the live
  -- merged data table, so later type/content mods are included automatically.
  local DIRECT_HP_DAMAGE = {
    EFFECT_STATIC_DAMAGE = true,
    EFFECT_LEVEL_DAMAGE = true,
    EFFECT_SUPER_FANG = true,
  }

  local function effectIndicator(screen, def)
    if option("effect_hints", true) == false or not def then return nil end
    local target
    if type(screen and screen.activeMon) == "function" then
      local ok, mon = pcall(screen.activeMon, screen, "enemy")
      if ok then target = mon end
    end
    target = target or (screen and screen.battle and screen.battle.enemy)
      or (screen and screen.enemy)
    local targetTypes = target and (target.types or target.curTypes)
    if type(targetTypes) ~= "table" then return nil end
    if DIRECT_HP_DAMAGE[def.effect] then return "up" end

    local multiplier = 10
    local chart = screen and screen.game and screen.game.data
      and screen.game.data.type_chart
    for _, row in ipairs(chart and chart.matchups or {}) do
      if row.attacker == def.type then
        for _, targetType in ipairs(targetTypes) do
          if row.defender == targetType then
            multiplier = math.floor(multiplier
              * (tonumber(row.multiplier) or 10) / 10)
            break
          end
        end
      end
    end
    if multiplier == 0 then return "circle" end
    if def.effect == "EFFECT_OHKO" then return "up" end
    if type(def.power) ~= "number" or def.power <= 0 then return "circle" end
    if multiplier > 10 then return "double_up" end
    if multiplier < 10 then return "down" end
    return "up"
  end

  local function drawEffectArrow(cx, cy, direction, ink)
    love.graphics.setColor(ink[1], ink[2], ink[3], 1)
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

  local function drawEffectIndicator(kind, x, y, w, h, ink)
    if not kind then return end
    local cx, cy = x + w - 11, y + math.floor(h / 2)
    if kind == "circle" then
      love.graphics.setColor(ink[1], ink[2], ink[3], 1)
      love.graphics.setLineWidth(1)
      love.graphics.circle("line", cx, cy, 3)
    elseif kind == "double_up" then
      drawEffectArrow(cx - 4, cy, "up", ink)
      drawEffectArrow(cx + 4, cy, "up", ink)
    else
      drawEffectArrow(cx, cy, kind, ink)
    end
  end

  local function moveDetails(def, move)
    local power = tonumber(def and def.power)
    local powerText = power and power > 0 and tostring(math.floor(power))
      or "---"
    local current = math.max(0, math.floor(tonumber(move and move.pp) or 0))
    local base = tonumber(def and def.pp)
    local calculated = base and (base + (tonumber(move and move.ppUps) or 0)
      * math.floor(base / 5)) or nil
    local maximum = tonumber(move and move.maxPp)
      or calculated or current
    if move and move.ppUps ~= nil and calculated then maximum = calculated end
    maximum = math.max(0, math.floor(maximum))
    return powerText, current, maximum
  end

  local function drawCardFace(x, y, w, h, face, selected)
    local G = love.graphics
    local fx, fy, fw, fh = x + 2, y + 1, w - 4, h - 3
    if selected then fx, fy, fw, fh = fx - 1, fy - 1, fw + 2, fh + 2 end
    G.setColor(0.08, 0.09, 0.12, 1)
    chamfer("fill", fx + 2, fy + 2, fw, fh, 2)
    if selected then
      local dr, dg, db = darken(face, 0.56)
      G.setColor(dr, dg, db, alpha())
    else
      G.setColor(face[1], face[2], face[3], alpha())
    end
    chamfer("fill", fx, fy, fw, fh, 2)
    G.setColor(selected and 1 or 0.20,
      selected and 1 or 0.21, selected and 1 or 0.25, 1)
    G.setLineWidth(selected and 2 or 1)
    chamfer("line", fx + 0.5, fy + 0.5, fw - 1, fh - 1, 2)
  end

  local function drawCards(screen)
    if option("battle_colors", true) == false then return end
    local moves = playerMoves(screen)
    if #moves == 0 then return end
    local G = love.graphics
    local wasBattle = Font.useBattleExtra(true)
    local width = screen.modernBattleWideWidth or 160
    local wide = width > 160
    local top = wide and 104 or 96
    local height = 144 - top
    local detailGap = wide and 3 or 0
    local detailW = wide and math.max(80,
      math.min(104, math.floor(width * 0.29))) or width
    local gridW = wide and (width - detailW - detailGap) or width
    local gridH = wide and height or 32
    local colW = math.floor(gridW / 2)
    local rowH = math.floor(gridH / 2)
    G.push("all")
    G.setColor(0.08, 0.09, 0.12, 1)
    G.rectangle("fill", 0, top, width, 144 - top)
    screen.typedMoveColorsEffectMarkers = {}
    for i = 1, 4 do
      local move = moves[i]
      local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
      local x, y = col * colW, top + row * rowH
      local selected = i == screen.moveIndex
      local def = moveDef(screen, move)
      local color = typeColor(def)
      local r, g, b = strength(color)
      local face = { r, g, b }
      local textOnly = option("text_only", false)
      if textOnly then face = { 0.94, 0.94, 0.94 } end
      drawCardFace(x, y, colW, rowH, face, selected)
      local ink = selected and { 1, 1, 1 } or { 0, 0, 0 }
      if move then
        local indicator = effectIndicator(screen, def)
        screen.typedMoveColorsEffectMarkers[i] = indicator
        local markerReserve = indicator
          and (indicator == "double_up" and 24 or 16) or 0
        -- RBY parity: Power and PP belong to the selected-move information
        -- card, not redundantly inside every move button. Card colour already
        -- communicates type.
        printCardInk(fit((def and def.name) or move.id,
            colW - 14 - markerReserve),
          x + 7, y + math.max(2, math.floor((rowH - 8) / 2)), ink)
        drawEffectIndicator(indicator, x, y, colW, rowH, ink)
      else
        printCardInk("--", x + 7,
          y + math.max(2, math.floor((rowH - 8) / 2)), ink)
      end
    end

    local selected = moves[math.max(1,
      math.min(tonumber(screen.moveIndex) or 1, #moves))]
    if selected then
      local def = moveDef(screen, selected)
      local color = typeColor(def)
      local r, g, b = strength(color)
      local face = { r, g, b }
      if option("text_only", false) then face = { 0.94, 0.94, 0.94 } end
      local power, current, maximum = moveDetails(def, selected)
      local ix, iy, iw, ih
      if wide then
        ix, iy, iw, ih = gridW + detailGap, top, detailW, height
      else
        ix, iy, iw, ih = 0, top + gridH, width, height - gridH
      end
      drawCardFace(ix, iy, iw, ih, face, true)
      local ink = { 1, 1, 1 }
      if wide then
        printCardInk("POWER", ix + 7, iy + 9, ink)
        printCardInkRight(power, ix + iw - 7, iy + 9, ink)
        printCardInk("PP", ix + 7, iy + 23, ink)
        printCardInkRight(("%d/%d"):format(current, maximum),
          ix + iw - 7, iy + 23, ink)
        screen.typedMoveColorsInfoMode = "full"
      else
        local line = ("POWER %s PP%d/%d"):format(
          power, current, maximum)
        printCardInk(fit(line, iw - 14), ix + 7, iy + 3, ink)
        screen.typedMoveColorsInfoMode = "compact"
      end
      screen.typedMoveColorsInfoPanel = true
      screen.typedMoveColorsInfoPP = ("%d/%d"):format(current, maximum)
      screen.typedMoveColorsInfoPower = power
    end
    G.pop()
    Font.useBattleExtra(wasBattle)
    screen.typedMoveColorsGen2 = true
  end

  mod.hooks:wrap("battle.move_grid_navigation", function(next, screen)
    local downstream = next(screen)
    if gridEnabled() then return true end
    return downstream
  end, 1000)

  -- When the cards own move selection they also own its complete lower UI.
  -- This prevents the native TYPE/PP window from remaining over the player's
  -- sprite on square/classic surfaces.
  mod.hooks:wrap("battle.bottom_ui_visible", function(next, screen)
    local downstream = next(screen)
    if gridEnabled() and movePhase(screen) then
      screen.typedMoveColorsOwnsBottom = true
      return false
    end
    return downstream
  end, 1000)

  -- Prefer the public navigation seam above, but also own D-pad movement for
  -- the single frame on which it is pressed.  Some released API 2 Gen 2
  -- builds have no battle.move_grid_navigation call at all, so changing the
  -- method alone cannot affect them.  This installer is idempotent and can be
  -- called again if that build replaces the state update after screen.pushed.
  local function installGridNavigation(screen)
    if type(screen) ~= "table" or type(screen.update) ~= "function" then
      return false
    end
    if not screen.typedMoveColorsGridMethod then
      local nativeGrid = screen.moveGridNavigation
      screen.typedMoveColorsGridMethod = true
      screen.moveGridNavigation = function(self)
        if gridEnabled() then return true end
        if type(nativeGrid) == "function" then return nativeGrid(self) end
        return false
      end
    end
    if screen.update == screen.typedMoveColorsGridUpdate then return true end
    local nativeUpdate = screen.update
    screen.typedMoveColorsGridNavigation = true
    local gridUpdate = function(self, ...)
      if gridEnabled() and movePhase(self) then
        local input = self.game and self.game.input
        local direction
        if input and input:wasPressed("left") then direction = "left"
        elseif input and input:wasPressed("right") then direction = "right"
        elseif input and input:wasPressed("up") then direction = "up"
        elseif input and input:wasPressed("down") then direction = "down" end
        if direction then
          local moves = playerMoves(self)
          if #moves > 0 then
            self.moveIndex = gridTarget(self.moveIndex, #moves, direction)
          end
          -- Do not let an older controller read the same press again as a
          -- vertical-list command and undo the grid movement.
          return
        end
      end
      return nativeUpdate(self, ...)
    end
    screen.typedMoveColorsGridUpdate = gridUpdate
    screen.update = gridUpdate
    return true
  end

  mod.events:on("screen.pushed", function(event)
    local screen = type(event) == "table" and event.state or nil
    local battleScreen = type(screen) == "table"
      and (screen.screenId == "Gen2BattleState"
        or screen.screenId == "BattleState")
    if battleScreen then installGridNavigation(screen) end
  end, 1000)

  mod.hooks:wrap("battle.overlay", function(next, screen)
    -- battle.overlay is the one compatibility seam every build that can draw
    -- these cards necessarily calls.  Reattach here if an older Silver state
    -- replaced or bypassed the wrapper installed when it was pushed.
    if type(screen) == "table" then installGridNavigation(screen) end
    local result = next(screen)
    if type(screen) == "table" and movePhase(screen) then
      drawCards(screen)
    end
    return result
  end, 900)

  -- The native summary keeps its controller; coloured edge swatches make the
  -- same type mapping visible while inspecting or reordering moves.
  local inherited = mod.content.screens:get("Gen2SummaryMenu")
  local provider = inherited or SummaryMenu
  local record = { new = function(game, ...)
    local menu = provider.new(game, ...)
    if type(menu) ~= "table" or menu.typedMoveColorsGeneration == 2 then
      return menu
    end
    local nativePanel = menu.drawPanel
    menu.typedMoveColorsGeneration = 2
    menu.drawPanel = function(self)
      nativePanel(self)
      if option("menu_colors", true) == false or not self.moveDetail then return end
      local G = love.graphics
      local width = self.modernPartyWideWidth or 160
      G.push("all")
      for i, move in ipairs(self.mon and self.mon.moves or {}) do
        local def = moveDef(self, move)
        local c = typeColor(def)
        G.setColor(c[1], c[2], c[3], 1)
        G.rectangle("fill", width - 4, (3 + (i - 1) * 2) * 8, 4, 8)
      end
      G.pop()
    end
    return menu
  end }
  if inherited then mod.content.screens:override("Gen2SummaryMenu", record)
  else mod.content.screens:register("Gen2SummaryMenu", record) end

  mod.exports.generation = 2
  mod.exports.typeColors = COLORS
  mod.log:info("type-coloured Gen 2 battle and summary moves enabled")
end
