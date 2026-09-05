-- Type-coloured move cards over Gen 2's native battle controller. The move
-- list, PP, disable state, swapping and choice callbacks remain native.
return function(mod)
  local Chrome = require("src.ui.gen2.Chrome")
  local Font = require("src.render.Font")

  -- Keep native message pages/reveal/input; only make its existing wrapping
  -- split overlong words on real glyph boundaries. The scoped Chrome override
  -- cannot affect other screens and is restored even if a provider throws.
  local function installDialogueWrapping(screen, owner, active)
    if type(screen.showPages) ~= "function" or type(screen.syncTyper) ~= "function" then return end
    screen.modernGen2DialogueOwners = screen.modernGen2DialogueOwners or {}
    screen.modernGen2DialogueOwners[owner] = active
    if screen.modernGen2DialogueWrapped then return end
    screen.modernGen2DialogueWrapped = true
    for _, method in ipairs({ "showPages", "syncTyper" }) do
      local native = screen[method]
      screen[method] = function(self, ...)
        local enabled = false
        for _, test in pairs(self.modernGen2DialogueOwners or {}) do
          if test() then enabled = true; break end
        end
        if not enabled or not Font.split or not Font.spansFitting then
          return native(self, ...)
        end
        local wrap = Chrome.wrap
        Chrome.wrap = function(text, tiles)
          local out, budget = {}, math.max(8, (tiles or 20) * 8)
          for _, line in ipairs(wrap(text, tiles)) do
            while Font.width(line) > budget do
              local spans = Font.split(line)
              local count = math.max(1, Font.spansFitting(spans, budget))
              -- A macro may expand several glyphs from one byte; keep every
              -- span of that source token together instead of duplicating it.
              local last = spans[count] and spans[count].to
              if not last then break end
              while spans[count + 1] and spans[count + 1].to == last do count = count + 1 end
              out[#out + 1] = line:sub(1, last)
              line = line:sub(last + 1)
              if line == "" then break end
            end
            if line ~= "" then out[#out + 1] = line end
          end
          return out
        end
        local result = { pcall(native, self, ...) }
        Chrome.wrap = wrap
        if not result[1] then error(result[2], 0) end
        return unpack(result, 2)
      end
    end
  end
  local GbcPalette = require("src.render.GbcPalette")
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

  local function componentEnabled()
    local enabled = mod.options and mod.options.enabled
    if type(enabled) ~= "function" then return true end
    local ok, value = pcall(enabled, mod.options)
    return not ok or value ~= false
  end

  -- Gen 2 uses a full-width 2x2 grid and a slim bottom details strip.
  -- Explicit side panels are reserved for widths that fit the same 2x2 grid.
  local function gridEnabled()
    return componentEnabled() and option("battle_colors", true) ~= false
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

  local function layoutColumns(screen)
    local width = tonumber(screen and (screen.modernBattleWideWidth
      or screen.modernBattleLastWideWidth)) or 160
    -- Very narrow non-cartridge canvases retain the readable list fallback.
    -- Ordinary 16:9 is 256px and always gets the full-width 2x2 default.
    if width > 160 and width < 224 then return 1 end
    return 2
  end

  local function gridTarget(index, count, direction, columns)
    index = math.max(1, math.min(tonumber(index) or 1, math.max(1, count)))
    if columns == 1 then
      if direction == "up" then
        return index > 1 and index - 1 or count
      elseif direction == "down" then
        return index < count and index + 1 or 1
      end
      return index
    end
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
    -- Infinity is authored here, not sent to the cartridge font encoder.
    if text:sub(-3) == "∞" then
      local prefix = text:sub(1, -4)
      if prefix ~= "" then printCardInk(prefix, x, y, color) end
      local G, px, py = love.graphics, math.floor(x + Font.width(prefix)), math.floor(y) + 1
      G.push("all"); G.setShader(); G.setColor(color[1], color[2], color[3], 1)
      for row, line in ipairs({".##...##.","#..#.#..#","#...#...#","#..#.#..#",".##...##."}) do
        for col=1,#line do if line:sub(col,col)=="#" then G.rectangle("fill",px+col-1,py+row-1,1,1) end end
      end
      G.pop()
      return Font.width(prefix) + 9
    end
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
    if text:sub(-3) == "∞" then
      return printCardInk(text, right - Font.width(text:sub(1,-4)) - 9, y, color)
    end
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

  local function moveNameBudget(width, indicator)
    -- Text starts seven pixels into the card. Keep two clear pixels before
    -- the left edge of the marker: x+w-15 for a single arrow/circle and
    -- x+w-19 for the two-arrow form. The previous blanket reserves counted
    -- both the marker and the card margins twice, needlessly dropping one or
    -- two more characters even on layouts that had room.
    if indicator == "double_up" then return width - 28 end
    if indicator then return width - 25 end
    return width - 14
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

  local function drawCardFace(x, y, w, h, face, selected, held)
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
    if held then
      -- Pickup belongs to the SOURCE MOVE, not the Power/PP readout.
      G.setColor(1, 0.82, 0.35, 1)
    else
      G.setColor(selected and 1 or 0.20,
        selected and 1 or 0.21, selected and 1 or 0.25, 1)
    end
    G.setLineWidth((selected or held) and 2 or 1)
    chamfer("line", fx + 0.5, fy + 0.5, fw - 1, fh - 1, 2)
  end

  local function drawListRowFace(x, y, w, h, face, selected, held)
    -- A ten-pixel row has exactly one pixel above and below Gen 2's 8px
    -- battle font. The regular card's chamfer, drop shadow and expanded
    -- selected outline all need a taller face and cut through these compact
    -- rows, so use a crisp flat cell with its border on the outer half-pixel.
    local G = love.graphics
    local r, g, b = face[1], face[2], face[3]
    if selected then r, g, b = darken(face, 0.56) end
    G.setColor(r, g, b, alpha())
    G.rectangle("fill", x + 2, y + 1, w - 4, h - 2)
    G.setColor(selected and 1 or 0.10,
      selected and 1 or 0.11, selected and 1 or 0.14, 1)
    if held then G.setColor(1, 0.82, 0.35, 1) end
    G.setLineWidth(1)
    G.rectangle("line", x + 1.5, y + 0.5, w - 3, h - 1)
  end

  local function heldSource(screen, moves)
    -- Read the controller's mark each frame; a second local pick-up state
    -- could survive native placement, cancellation, or a refused move.
    local index = screen.moveSwapIndex
    if type(index) == "number" and index % 1 == 0
        and index >= 1 and index <= 4 and moves[index] then
      return index
    end
  end

  local function drawHeldMarker(x, y, h)
    -- An opaque hollow arrow stays at the SOURCE, including on the initial
    -- selected row. The white focus frame still follows the destination.
    -- Use the existing seven-pixel gutter so names and mobile rows keep
    -- their full width, and never rely on type colour or blinking alone.
    local G, cy = love.graphics, y + math.floor(h / 2)
    G.setColor(0, 0, 0, 1)
    G.rectangle("fill", x + 1, cy - 4, 6, 8)
    G.setColor(1, 1, 1, 1)
    G.setLineWidth(1)
    G.polygon("line", { x + 2, cy - 3, x + 5, cy, x + 2, cy + 3 })
  end

  local function drawCards(screen)
    if not gridEnabled() then return end
    local moves = playerMoves(screen)
    if #moves == 0 then return end
    local source = heldSource(screen, moves)
    screen.typedMoveColorsHeldSource = source
    local G = love.graphics
    local wasBattle = Font.useBattleExtra(true)
    local width = screen.modernBattleWideWidth or 160
    local wide = width > 160
    local top = wide and 104 or 96
    local height = 144 - top
    local infoPosition = option("info_position", "original")
    local columns = layoutColumns(screen)
    local sidePanel = columns == 1 or (width >= 360 and infoPosition ~= "original")
    local detailGap = sidePanel and 3 or 0
    local detailW = sidePanel and math.max(80,
      math.min(104, math.floor(width * 0.29))) or width
    local gridW = sidePanel and (width - detailW - detailGap) or width
    local gridX = sidePanel and infoPosition == "left" and detailW + detailGap or 0
    local gridH = sidePanel and height or height - (wide and 12 or 16)
    local colW = math.floor(gridW / columns)
    local rowH = math.floor(gridH / (columns == 1 and 4 or 2))
    G.push("all")
    G.setColor(0.08, 0.09, 0.12, 1)
    G.rectangle("fill", 0, top, width, 144 - top)
    screen.typedMoveColorsEffectMarkers = {}
    screen.typedMoveColorsColumns = columns
    screen.typedMoveColorsLayout = columns == 1 and "list" or "grid"
    for i = 1, 4 do
      local move = moves[i]
      local col, row = (i - 1) % columns,
        math.floor((i - 1) / columns)
      local x, y = gridX + col * colW, top + row * rowH
      local selected = i == screen.moveIndex
      local def = moveDef(screen, move)
      local color = typeColor(def)
      local r, g, b = strength(color)
      local face = { r, g, b }
      local textOnly = option("text_only", false)
      if textOnly then face = { 0.94, 0.94, 0.94 } end
      if columns == 1 then
        drawListRowFace(x, y, colW, rowH, face, selected, i == source)
      else
        drawCardFace(x, y, colW, rowH, face, selected, i == source)
      end
      local ink = selected and { 1, 1, 1 } or { 0, 0, 0 }
      local textY = columns == 1 and (y + 1)
        or (y + math.max(2, math.floor((rowH - 8) / 2)))
      if move then
        local indicator = effectIndicator(screen, def)
        screen.typedMoveColorsEffectMarkers[i] = indicator
        -- RBY parity: Power and PP belong to the selected-move information
        -- card, not redundantly inside every move button. Card colour already
        -- communicates type.
        printCardInk(fit((def and def.name) or move.id,
            moveNameBudget(colW, indicator)),
          x + 7, textY, ink)
        drawEffectIndicator(indicator, x, y, colW, rowH, ink)
      else
        printCardInk("--", x + 7, textY, ink)
      end
      if i == source then drawHeldMarker(x, y, rowH) end
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
      local battle = screen.battle
      local ppText = battle and type(battle.modUnlimitedPP) == "function"
          and battle:modUnlimitedPP(battle.player) and "∞"
        or ("%d/%d"):format(current, maximum)
      local ix, iy, iw, ih
      if sidePanel then
        ix = infoPosition == "left" and 0 or gridW + detailGap
        iy, iw, ih = top, detailW, height
      else
        ix, iy, iw, ih = 0, top + gridH, width, height - gridH
      end
      drawCardFace(ix, iy, iw, ih, face, true, false)
      local ink = { 1, 1, 1 }
      -- Details follow the destination normally; amber remains on the source.
      if sidePanel then
        printCardInk("POWER", ix + 7, iy + 9, ink)
        printCardInkRight(power, ix + iw - 7, iy + 9, ink)
        printCardInk("PP", ix + 7, iy + 23, ink)
        printCardInkRight(ppText,
          ix + iw - 7, iy + 23, ink)
        screen.typedMoveColorsInfoMode = "full"
      else
        local line = ("POWER %s  PP %s"):format(power, ppText)
        local lineWidth
        if ppText == "∞" then
          local prefix = line:sub(1,-4)
          if Font.width(prefix) + 9 > iw - 14 then prefix = fit(prefix, iw - 23) end
          line, lineWidth = prefix .. "∞", Font.width(prefix) + 9
        else
          line = fit(line, iw - 14); lineWidth = Font.width(line)
        end
        local tx = ix + 7
        if infoPosition == "right" then tx = ix + iw - 7 - lineWidth end
        printCardInk(line, tx, iy + math.floor((ih - 8) / 2), ink)
        screen.typedMoveColorsInfoMode = "compact"
      end
      screen.typedMoveColorsInfoSide = sidePanel
        and (infoPosition == "left" and "left" or "right") or "bottom"
      screen.typedMoveColorsInfoBounds = { x = ix, y = iy, w = iw, h = ih }
      screen.typedMoveColorsInfoPanel = true
      screen.typedMoveColorsInfoPP = ppText
      screen.typedMoveColorsInfinityVisible = ppText == "∞"
      screen.typedMoveColorsInfoPower = power
    end
    G.pop()
    Font.useBattleExtra(wasBattle)
    screen.typedMoveColorsGen2 = true
  end

  -- The suite's responsive HUD owns a pixel-space (not native tile-space)
  -- bottom panel. Adapt that surface too, without touching its scene or HUD.
  local function drawWideOptions(screen)
    local width = screen.modernBattleWideWidth
    if not width or width < 160 or not gridEnabled()
        or option("text_only", false) or movePhase(screen) then return end
    local align, side = option("text_position", "left"), option("info_position", "original")
    local style = alpha() == 1 and option("box_color", "original") or "original"
    if align == "left" and side == "original" and style == "original" then return end
    local G, y = love.graphics, 104
    local face = style == "black" and {0,0,0}
      or style == "gray" and {170/255,170/255,170/255} or {1,1,1}
    local ink = style == "black" and {1,1,1} or {0,0,0}
    screen.typedMoveColorsNeutralPanel = { style = style, width = width, y = y }
    G.push("all")
    G.setColor(face[1], face[2], face[3], 1); G.rectangle("fill", 0, y, width, 40)
    G.setColor(ink[1], ink[2], ink[3], 1); G.setLineWidth(2)
    G.rectangle("line", 1, y + 1, width - 2, 38)
    local function line(value, full, x, available, atY)
      local fullWidth = math.min(available, Font.width(full or value))
      if align == "center" then x = x + math.floor((available - fullWidth) / 2)
      elseif align == "right" then x = x + available - fullWidth end
      printCardInk(fit(value, available), x, atY, ink)
      return x
    end
    if screen.phase == "menu" then
      local menuWidth = math.max(88, math.min(112, math.floor(width * 0.44)))
      local promptWidth = width - menuWidth
      local right = side == "right" and width >= 200 and not screen.contest
      local promptX, menuX = right and menuWidth or 0, right and 0 or promptWidth
      local maxTiles = math.max(6, math.floor((promptWidth - 16) / 8))
      local lines = Chrome.wrap(screen.message or "What will you do?", maxTiles)
      if #lines > 2 then lines = Chrome.wrap("What will you do?", maxTiles) end
      if #lines > 2 then lines = { "What", "now?" } end
      for i = 1, math.min(2, #lines) do
        line(lines[i], lines[i], promptX + 8, promptWidth - 16, y + 4 + (i - 1) * 16)
      end
      local labels = screen:menuLabels()
      for i, label in ipairs(labels) do
        local x = menuX + 8 + ((i - 1) % 2) * math.floor(menuWidth / 2)
        local ty = y + 8 + math.floor((i - 1) / 2) * 16
        if i == screen.menuIndex then printCardInk("▶", x - 9, ty, ink) end
        printCardInk(label, x, ty, ink)
      end
      screen.typedMoveColorsPromptSide = right and "right" or "left"
    else
      screen:syncTyper()
      local shown = screen:messageLines()
      local full = screen.typer and screen.typer.page or shown
      screen.typedMoveColorsMessageOrigins = {}
      for i = 1, math.min(2, #shown) do
        screen.typedMoveColorsMessageOrigins[i] = line(shown[i], full[i],
          8, width - 16, y + 4 + (i - 1) * 16)
      end
      if screen:messageArrowVisible() then
        printCardInk("▼", width - 14, 132, ink)
      end
    end
    if type(screen.modernBattleDrawChoices) == "function" then
      local paper, foreground = {}, {}
      for i = 1, 3 do paper[i], foreground[i] = face[i] * 255, ink[i] * 255 end
      screen:modernBattleDrawChoices({ paper, paper, paper, foreground })
    end
    G.pop()
  end

  mod.hooks:wrap("battle.move_grid_navigation", function(next, screen)
    local downstream = next(screen)
    if gridEnabled() then return layoutColumns(screen) > 1 end
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

  -- Adapt only native drawing: keep message pages, reveal counts, prompts and
  -- menu callbacks in the engine. Wrappers are scoped to this single draw and
  -- restored even if another renderer raises an error.
  local function installBottomOptions(screen)
    if type(screen.drawBottom) ~= "function"
        or screen.drawBottom == screen.typedMoveColorsBottomDraw then return end
    local native = screen.drawBottom
    local draw = function(self, ox)
      if not gridEnabled() or option("text_only", false) then return native(self, ox) end
      ox = tonumber(ox) or 0
      local width = (20 + ox) * 8
      local style = alpha() == 1 and option("box_color", "original") or "original"
      local palette
      if style == "black" then
        palette = { {0,0,0}, {0,0,0}, {0,0,0}, {255,255,255} }
      elseif style == "white" then
        palette = { {255,255,255}, {255,255,255}, {255,255,255}, {0,0,0} }
      elseif style == "gray" then
        palette = { {170,170,170}, {170,170,170}, {170,170,170}, {0,0,0} }
      end
      local align = option("text_position", "left")
      local mirrored = self.phase == "menu" and not self.contest
        and width >= 200 and option("info_position", "original") == "right"
      self.typedMoveColorsPromptSide = mirrored and "right" or "left"
      if not palette and align == "left" and not mirrored then return native(self, ox) end
      local box, printThrough, cursor = Chrome.box, Chrome.printThrough, Chrome.cursorThrough
      local printMessage = self.printMessage
      local inMessage = false
      local menuX = 8 + ox
      Chrome.box = function(x, y, w, h)
        if mirrored and y == 12 and x == menuX then x = 0 end
        if palette then return Chrome.paletteBox(x, y, w, h, palette) end
        return box(x, y, w, h)
      end
      Chrome.printThrough = function(value, x, y, pal, ...)
        if mirrored and not inMessage and (y == 14 or y == 16) then x = x - menuX end
        return printThrough(value, x, y, palette or pal, ...)
      end
      Chrome.cursorThrough = function(x, y, pal, ...)
        if mirrored and (y == 14 or y == 16) then x = x - menuX end
        return cursor(x, y, palette or pal, ...)
      end
      self.printMessage = function(active, offset)
        inMessage = true
        if (align == "left" and not mirrored)
            or (active.phase == "menu" and (width < 200 or active.contest)) then
          printMessage(active, offset)
        else
          active:syncTyper()
          local shown = active:messageLines()
          local full = active.typer and active.typer.page
            or Chrome.wrap(active.message or "", 18)
          local left, available = 8, width - 16
          if active.phase == "menu" then
            if mirrored then left = 104 end
            available = width - 112
          end
          active.typedMoveColorsMessageOrigins = {}
          for i = 1, math.min(2, #shown) do
            local value = shown[i]
            local fullWidth = math.min(available, Font.width(full[i] or value))
            local x = left
            if align == "center" then x = left + math.floor((available - fullWidth) / 2)
            elseif align == "right" then x = left + available - fullWidth end
            -- Native command prompts can be covered by the menu. Clip only
            -- their visible prefix, without modifying the native reveal page.
            if Font.width(value) > available then
              local spans = Font.split(value)
              local count = Font.spansFitting(spans, available)
              value = count > 0 and value:sub(1, spans[count].to) or ""
            end
            active.typedMoveColorsMessageOrigins[i] = x
            printThrough(value, x / 8, 14 + (i - 1) * 2,
              palette or Chrome.DEFAULT_BOX_PALETTE)
          end
          if active:messageArrowVisible() then
            printThrough("▼", 18 + ox, 16, palette or Chrome.DEFAULT_BOX_PALETTE)
          end
        end
        inMessage = false
      end
      local previousBgp = GbcPalette.bgp
      local results = { pcall(native, self, ox) }
      Chrome.box, Chrome.printThrough, Chrome.cursorThrough = box, printThrough, cursor
      self.printMessage = printMessage
      if not results[1] then
        GbcPalette.setBgp(previousBgp)
        error(results[2], 0)
      end
      return unpack(results, 2)
    end
    screen.typedMoveColorsBottomDraw = draw
    screen.drawBottom = draw
  end

  -- Prefer the public navigation seam above, but also own D-pad movement for
  -- the single frame on which it is pressed.  Some released API 2 Gen 2
  -- builds have no battle.move_grid_navigation call at all, so changing the
  -- method alone cannot affect them.  This installer is idempotent and can be
  -- called again if that build replaces the state update after screen.pushed.
  local function installGridNavigation(screen)
    installDialogueWrapping(screen, "typed_move_colors", gridEnabled)
    if type(screen) ~= "table" or type(screen.update) ~= "function" then
      return false
    end
    installBottomOptions(screen)
    if not screen.typedMoveColorsGridMethod then
      local nativeGrid = screen.moveGridNavigation
      screen.typedMoveColorsGridMethod = true
      screen.moveGridNavigation = function(self)
        if gridEnabled() then return layoutColumns(self) > 1 end
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
            self.moveIndex = gridTarget(self.moveIndex, #moves, direction,
              layoutColumns(self))
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
    if type(screen) == "table" then
      installGridNavigation(screen)
      screen.typedMoveColorsHeldSource = nil
    end
    local result = next(screen)
    if type(screen) == "table" and movePhase(screen) then
      drawCards(screen)
    elseif type(screen) == "table" then
      drawWideOptions(screen)
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
      if not componentEnabled() or option("menu_colors", true) == false
          or not self.moveDetail then return end
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
