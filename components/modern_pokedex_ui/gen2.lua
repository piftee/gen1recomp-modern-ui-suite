-- Gen 2's Pokedex owns the 251-species list, search, area and Unown views.
-- This wrapper keeps those controllers intact and adds the Modern Pokedex
-- theme/status treatment to every native view.
return function(mod)
  local cutoutSource = assert(mod:read("gen2_portrait_cutouts.lua"))
  local PortraitCutouts = assert(load(cutoutSource, "@" .. mod.path
    .. "/gen2_portrait_cutouts.lua"))()
  local PokedexMenu = require("src.ui.gen2.PokedexMenu")
  local Chrome = require("src.ui.gen2.Chrome")
  local Font = require("src.render.Font")
  local GbcPalette = require("src.render.GbcPalette")
  local Assets = require("src.render.Assets")
  local Palettes = require("src.world.gen2.Palettes")
  local TypeChart = require("src.battle.TypeChart")

  local INK_BLACK = { 0, 0, 0 }
  local INK_WHITE = { 1, 1, 1 }
  local INK_LIGHT = { 0.48, 0.90, 0.94 }
  local RED = { 0.98, 0.10, 0.08 }
  local ORANGE = { 1.00, 0.48, 0.06 }
  local BLUE = { 0.17, 0.43, 0.91 }
  local BLUE_DARK = { 0.05, 0.15, 0.54 }
  local PAPER = { 0.96, 0.97, 0.98 }
  local PAPER_ALT = { 0.82, 0.84, 0.87 }
  local SELECTED = { 0.18, 0.20, 0.24 }

  local function setColor(color, alpha)
    love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
  end

  local function inkPalette(color)
    color = color or INK_BLACK
    local ink = {}
    for i = 1, 3 do
      local value = color[i] or 0
      ink[i] = math.floor((value <= 1 and value * 255 or value) + 0.5)
    end
    return {
      { 255, 255, 255 },
      { math.floor((255 + ink[1]) / 2), math.floor((255 + ink[2]) / 2),
        math.floor((255 + ink[3]) / 2) },
      { math.floor(ink[1] / 2), math.floor(ink[2] / 2),
        math.floor(ink[3] / 2) }, ink,
    }
  end

  local function fitText(text, maxWidth)
    text = tostring(text or "")
    if not maxWidth or Font.width(text) <= maxWidth then return text end
    local budget = math.max(0, maxWidth - Font.width("."))
    if Font.split and Font.spansFitting then
      local spans = Font.split(text)
      local count = Font.spansFitting(spans, budget)
      return count > 0 and text:sub(1, spans[count].to) .. "." or ""
    end
    while #text > 0 and Font.width(text) > budget do text = text:sub(1, -2) end
    return text .. "."
  end

  local function drawInk(text, x, y, maxWidth, color)
    text = fitText(text, maxWidth)
    local palette, drawGlyph, finish = Chrome.paletteGlyphs(
      inkPalette(color), false, true)
    if not palette then
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(text, math.floor(x), math.floor(y))
      return Font.width(text)
    end
    local pen = math.floor(x)
    for _, code in ipairs(Font.encode(text)) do
      drawGlyph(code, pen, math.floor(y))
      pen = pen + Font.advanceOf(code)
    end
    finish()
    return pen - math.floor(x)
  end

  local function drawInkRight(text, right, y, maxWidth, color)
    text = fitText(text, maxWidth)
    local width = Font.width(text)
    drawInk(text, right - width, y, width, color)
  end

  local function drawInkCentered(text, x, y, width, color)
    text = fitText(text, width)
    drawInk(text, x + math.floor((width - Font.width(text)) / 2), y,
      width, color)
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

  local function typeName(menu, typeId)
    local types = menu.data and menu.data.type_chart
      and menu.data.type_chart.types or {}
    local record = types[typeId]
    local name = record and record.name
    if not name and type(TypeChart.displayName) == "function" then
      local ok, value = pcall(TypeChart.displayName, typeId, menu.data)
      if ok then name = value end
    end
    return tostring(name or typeId or "---"):upper()
  end

  local function screenWidth(menu)
    return menu.modernPokedexWideWidth or 160
  end

  local function installWideDraw(menu, drawPanel)
    menu.drawWidescreen = function(self, winW, winH)
      local G = love.graphics
      local scale = math.max(1, math.floor(math.min(winH / 144, winW / 160)))
      local width = math.max(160, math.min(640, math.floor(winW / scale)))
      if mod.suite and mod.suite.uiGeometry then
        local height
        width, height, scale = mod.suite.uiGeometry(self, winW, winH, width, 144, scale)
      end
      local ox = math.floor((winW - width * scale) / 2)
      local oy = math.floor((winH - 144 * scale) / 2)
      setColor({ 0, 0, 0 })
      G.rectangle("fill", 0, 0, winW, winH)
      G.push("all")
      G.setScissor(ox, oy, width * scale, 144 * scale)
      G.translate(ox, oy)
      G.scale(scale, scale)
      self.modernPokedexLastWideWidth = width
      self.modernPokedexWideWidth = width
      drawPanel(self)
      self.modernPokedexWideWidth = nil
      G.pop()
      G.setColor(1, 1, 1, 1)
    end
  end

  local function drawHeader(menu, title, showCount)
    local G = love.graphics
    local width = screenWidth(menu)
    setColor(RED)
    G.rectangle("fill", 0, 0, width, 18)
    setColor(ORANGE)
    G.rectangle("fill", 0, 16, width, 2)
    title = title or "POKéDEX"
    local _, caught = menu:totals()
    if title == "POKéDEX" then
      drawInk(title, 4, 5, 74, INK_WHITE)
      drawInkRight(("C %03d/%03d"):format(caught,
        menu.modernDexCount or #(menu.rows or {})), width - 4, 5, 76, INK_WHITE)
    else
      drawInk(title, 4, 5, 112, INK_WHITE)
      if showCount ~= false then
        drawInkRight(("C%d"):format(caught), width - 4, 5, 40, INK_WHITE)
      end
    end
  end

  local function drawFooter(menu, left, right)
    local G = love.graphics
    local width = screenWidth(menu)
    setColor(BLUE)
    G.rectangle("fill", 0, 132, width, 12)
    drawInk(left or "A ACTIONS", 4, 134, math.floor(width / 2) - 6,
      INK_WHITE)
    drawInkRight(right or "B BACK", width - 4, 134,
      math.floor(width / 2) - 6, INK_LIGHT)
  end

  local function drawBackdrop(menu)
    local G = love.graphics
    local width = screenWidth(menu)
    setColor({ 0, 0, 0 })
    G.rectangle("fill", 0, 0, width, 144)
    setColor({ 0.75, 0.78, 0.95 })
    for x = -144, width, 16 do
      G.line(x, 18, x + 112, 132)
      G.line(x + 112, 18, x, 132)
    end
  end


  -- Crystal supplies both coloured and pre-baked monochrome frames. Its
  -- image predicate also recognizes animated frames without a filename;
  -- a species flag alone could exempt an unrelated/native replacement.
  local function drawPortrait(image, colors, body, def)
    local provider = mod.find and mod.find("crystal_animated_sprites_with_shiny_visuals")
    local api = provider and provider.exports
    local authored = api and type(api.isCrystalImage) == "function" and api.isCrystalImage(image)
    -- Assets loads static pictures through ImageData, so those Images have
    -- no filename for Crystal's predicate. Match the exact registered source.
    if not authored and def and def.trueColor and def.spriteFront then
      local ok, source = pcall(Assets.image, def.spriteFront)
      authored = ok and source == image
    end
    if authored then
      local shader = love.graphics.getShader()
      love.graphics.setShader()
      body()
      love.graphics.setShader(shader)
    elseif colors and GbcPalette.available() then
      GbcPalette.with(colors, body)
    else
      body()
    end
  end

  local function drawFittedPanelPic(menu, row, rect)
    local image = mod.suite and mod.suite.battlePortrait
      and mod.suite.battlePortrait(menu.game, row.species)
    local authored = image ~= nil
    image = image or menu:picFor(row.species)
    if not image then return end
    local w, h = image:getDimensions()
    local scale = math.min(1, rect.w / w, rect.h / h)
    local x = math.floor(rect.x + (rect.w - w * scale) / 2 + 0.5)
    local y = math.floor(rect.y + (rect.h - h * scale) / 2 + 0.5)
    local colors = menu.palettes and Palettes.monColors(menu.palettes, row.species)
    local G = love.graphics
    G.push("all"); G.setColor(1, 1, 1, 1)
    local function body() G.draw(image, x, y, 0, scale, scale) end
    if authored then G.setShader(); body()
    else drawPortrait(image, colors, body, menu.pokemon[row.species]) end
    G.pop()
  end

  local function evolutionTarget(edge)
    if type(edge) ~= "table" then return nil end
    -- Gen 2's extractor calls the destination `into`; Gen 1 content and a
    -- handful of cross-generation mods use `species`. Supporting both keeps
    -- the family view attached to the merged data rather than to a hard-coded
    -- table of the original 251.
    return edge.into or edge.species
  end

  local function speciesId(key, def)
    return type(def) == "table" and (def.id or key) or key
  end

  local function evolutionFamily(menu, species)
    if not species then return {} end
    menu.modernGen2FamilyCache = menu.modernGen2FamilyCache or {}
    local cached = menu.modernGen2FamilyCache[species]
    if cached then return cached end

    local pokemon = menu.pokemon or (menu.data and menu.data.pokemon) or {}
    local parents = {}
    for key, def in pairs(pokemon) do
      local parentSpecies = speciesId(key, def)
      for _, edge in ipairs(type(def) == "table" and def.evolutions or {}) do
        local child = evolutionTarget(edge)
        if child and pokemon[child] then
          parents[child] = parents[child] or {}
          parents[child][#parents[child] + 1] = {
            species = parentSpecies, def = def, edge = edge,
          }
        end
      end
    end
    -- A mod can technically make two species converge on one evolution.
    -- Prefer the lowest Pokédex number so the chosen root is deterministic.
    for _, choices in pairs(parents) do
      table.sort(choices, function(a, b)
        local ad = type(a.def) == "table" and a.def.dex or math.huge
        local bd = type(b.def) == "table" and b.def.dex or math.huge
        if ad ~= bd then return ad < bd end
        return tostring(a.species) < tostring(b.species)
      end)
    end

    local root, walked = species, {}
    while parents[root] and parents[root][1] and not walked[root] do
      walked[root] = true
      root = parents[root][1].species
    end

    local family, queue, seen = {}, {
      { species = root, depth = 0, parent = nil },
    }, {}
    while #queue > 0 do
      local member = table.remove(queue, 1)
      local def = pokemon[member.species]
      if def and not seen[member.species] then
        seen[member.species] = true
        member.def = def
        family[#family + 1] = member
        for _, edge in ipairs(def.evolutions or {}) do
          local child = evolutionTarget(edge)
          if child and pokemon[child] and not seen[child] then
            queue[#queue + 1] = {
              species = child, depth = member.depth + 1,
              parent = { species = member.species, def = def, edge = edge },
            }
          end
        end
      end
    end
    -- Bad or partial mod data should still leave the selected species usable.
    if #family == 0 and pokemon[species] then
      family[1] = { species = species, def = pokemon[species], depth = 0 }
    end
    -- Keep generations in evolution order while making branches predictable.
    -- This puts Pichu ahead of Pikachu despite its later National Dex number,
    -- but orders Eevee's five same-stage branches by their familiar dex order.
    table.sort(family, function(a, b)
      if a.depth ~= b.depth then return a.depth < b.depth end
      local ad = type(a.def) == "table" and a.def.dex or math.huge
      local bd = type(b.def) == "table" and b.def.dex or math.huge
      if ad ~= bd then return ad < bd end
      return tostring(a.species) < tostring(b.species)
    end)
    for _, member in ipairs(family) do
      menu.modernGen2FamilyCache[member.species] = family
    end
    return family
  end

  local function itemName(menu, id)
    local item = id and menu.data and menu.data.items and menu.data.items[id]
    return tostring(item and item.name or id or "ITEM"):gsub("_", " ")
  end

  local function evolutionLabel(menu, parent)
    if not parent then return "BASIC SPECIES" end
    local edge = parent.edge or {}
    local method = tostring(edge.method or "")
    if method == "EVOLVE_LEVEL" or method == "LEVEL" then
      return ("EVOLVES AT LV%d"):format(tonumber(edge.level) or 1)
    elseif method == "EVOLVE_ITEM" or method == "ITEM" then
      return "USE " .. itemName(menu, edge.item)
    elseif method == "EVOLVE_TRADE" or method == "TRADE" then
      if edge.item then return "TRADE: " .. itemName(menu, edge.item) end
      return "EVOLVES BY TRADE"
    elseif method == "EVOLVE_HAPPINESS" or method == "HAPPINESS" then
      local time = tostring(edge.time or "ANYTIME"):upper()
      if time == "MORNDAY" or time == "DAY" then
        return "HAPPINESS, DAY"
      elseif time == "NITE" or time == "NIGHT" then
        return "HAPPINESS, NIGHT"
      end
      return "HIGH HAPPINESS"
    elseif method == "EVOLVE_STAT" or method == "STAT" then
      local comparison = ({
        ATK_GT_DEF = "ATTACK HIGHER", ATK_LT_DEF = "DEFENSE HIGHER",
        ATK_EQ_DEF = "ATK = DEF",
      })[edge.comparison] or tostring(edge.comparison or "STATS")
          :gsub("_", " ")
      return ("LV%d: %s"):format(tonumber(edge.level) or 1, comparison)
    end
    local readable = method:gsub("^EVOLVE_", ""):gsub("_", " ")
    if readable == "" then readable = "EVOLUTION" end
    if edge.level then
      return ("LV%d: %s"):format(tonumber(edge.level) or 1, readable)
    end
    return readable
  end

  local function familyKnown(menu, species)
    local dex = menu.save and menu.save.pokedex or {}
    if type(dex.seen) == "table" and dex.seen[species] then return true end
    if type(dex.caught) == "table" and dex.caught[species] then return true end
    if type(dex.owned) == "table" and dex.owned[species] then return true end
    for _, row in ipairs(menu.rows or {}) do
      if row.species == species then
        return row.seen == true or row.caught == true or row.owned == true
      end
    end
    return false
  end

  local function machineSources(menu)
    if menu.modernGen2MachineSources then
      return menu.modernGen2MachineSources
    end
    local sources = {}
    for id, item in pairs(menu.data and menu.data.items or {}) do
      if type(item) == "table" then
        local move, kind, number
        if type(item.machine) == "table" then
          move = item.machine.move
          kind = tostring(item.machine.kind or "TM"):upper()
          number = tonumber(item.machine.number)
        elseif item.teaches then
          move = item.teaches
          local label = tostring(item.tmLabel or item.name or id or ""):upper()
          kind, number = label:match("^(TM)(%d+)$")
          if not kind then kind, number = label:match("^(HM)(%d+)$") end
          number = tonumber(number)
        end
        if move then
          kind = kind == "HM" and "HM" or "TM"
          local full = number and ("%s%02d"):format(kind, number)
            or tostring(item.tmLabel or item.name or id or kind):upper()
          sources[move] = {
            short = kind, full = full,
            kind = kind == "HM" and "hm" or "machine",
          }
        end
      end
    end

    -- Generated Gen 2 data also publishes its machine order. It is a useful
    -- fallback for mods that merge the compatibility list but omit item
    -- records: 50 TMs, seven HMs, then Crystal's three move tutors.
    local machineOrder = menu.pokemon and menu.pokemon.tmhmMoves
      or (menu.data and menu.data.pokemon and menu.data.pokemon.tmhmMoves)
      or (menu.data and menu.data.tmhmMoves)
    for index, move in ipairs(type(machineOrder) == "table"
        and machineOrder or {}) do
      if not sources[move] then
        if index <= 50 then
          sources[move] = { short = "TM", full = ("TM%02d"):format(index),
            kind = "machine" }
        elseif index <= 57 then
          sources[move] = { short = "HM",
            full = ("HM%02d"):format(index - 50), kind = "hm" }
        else
          sources[move] = { short = "TUTOR", full = "TUTOR",
            kind = "tutor" }
        end
      end
    end
    menu.modernGen2MachineSources = sources
    return sources
  end

  local function resetMoveSelection(menu)
    menu.modernGen2MoveSpecies = nil
    menu.modernGen2MoveRows = nil
    menu.modernGen2MoveCursor = 1
    menu.modernGen2MoveScroll = 0
    menu.modernGen2MoveDetail = false
  end

  local function moveRows(menu, species)
    species = species or (menu:current() and menu:current().species)
    if menu.modernGen2MoveSpecies == species
        and type(menu.modernGen2MoveRows) == "table" then
      return menu.modernGen2MoveRows
    end
    local pokemon = menu.pokemon or (menu.data and menu.data.pokemon) or {}
    local def = species and pokemon[species] or nil
    local moves = menu.data and menu.data.moves or {}
    local levelRows, rows, added = {}, {}, {}
    local ordinal = 0
    local function addLevel(level, move)
      if not move then return end
      level = tonumber(level) or 1
      local key = tostring(level) .. ":" .. tostring(move)
      if added[key] then return end
      ordinal = ordinal + 1
      levelRows[#levelRows + 1] = {
        source = tostring(level), sourceDetail = "LEVEL " .. tostring(level),
        level = level, id = move, kind = "level", ordinal = ordinal,
        move = moves[move],
      }
      added[key] = true
    end
    for _, move in ipairs(def and def.level1Moves or {}) do addLevel(1, move) end
    for _, learned in ipairs(def and def.levelMoves or {}) do
      if type(learned) == "table" then addLevel(learned.level, learned.move) end
    end
    -- A few cross-generation content mods retain the Gen 1 field name while
    -- running on Gen 2. Treat it as another source without duplicating rows.
    for _, learned in ipairs(def and def.learnset or {}) do
      if type(learned) == "table" then addLevel(learned.level, learned.move) end
    end
    table.sort(levelRows, function(a, b)
      if a.level ~= b.level then return a.level < b.level end
      return a.ordinal < b.ordinal
    end)
    for _, row in ipairs(levelRows) do rows[#rows + 1] = row end

    local sources = machineSources(menu)
    menu.modernGen2MoveMachineStart = #rows + 1
    for _, move in ipairs(def and def.tmhm or {}) do
      local source = sources[move] or {
        short = "TM/HM", full = "TM/HM", kind = "compatibility",
      }
      rows[#rows + 1] = {
        source = source.short, sourceDetail = source.full,
        id = move, kind = source.kind, move = moves[move],
      }
    end
    for _, move in ipairs(def and def.tutorMoves or {}) do
      rows[#rows + 1] = {
        source = "TUTOR", sourceDetail = "TUTOR", id = move,
        kind = "tutor", move = moves[move],
      }
    end

    menu.modernGen2MoveSpecies = species
    menu.modernGen2MoveRows = rows
    menu.modernGen2MoveCursor = math.max(1,
      math.min(math.floor(menu.modernGen2MoveCursor or 1),
        math.max(1, #rows)))
    menu.modernGen2MoveScroll = math.max(0,
      math.floor(menu.modernGen2MoveScroll or 0))
    menu.modernGen2MoveDetail = false
    return rows
  end

  local function moveCategory(menu, move)
    if type(move) ~= "table" then return nil end
    local category = move.category
    if category == nil and move.power ~= nil then
      if tonumber(move.power) == 0 then
        category = "status"
      else
        local types = menu.data and menu.data.type_chart
          and menu.data.type_chart.types or {}
        local record = types[move.type]
        category = record and record.category
        if category == nil and type(TypeChart.category) == "function" then
          local ok, value = pcall(TypeChart.category, move.type)
          if ok then category = value end
        end
      end
    end
    category = category and tostring(category):upper() or nil
    if category == "PHYSICAL" then return "PHYS" end
    if category == "SPECIAL" then return "SPEC" end
    return category
  end

  local function focusFamilyMember(menu, member)
    if not member or not familyKnown(menu, member.species) then return false end
    local function findRow()
      for index, row in ipairs(menu.rows or {}) do
        if row.species == member.species then return index end
      end
    end
    local index = findRow()
    -- Search results replace the native row list. Rebuilding restores the
    -- selected NEW/OLD/A-Z order so a relative outside the active search can
    -- still be opened and remain selected when the player returns to the list.
    if not index and type(menu.rebuild) == "function" then
      menu.searchResults = nil
      menu:rebuild()
      menu.modernDexEntries = menu.rows
      index = findRow()
    end
    if not index then return false end
    menu.index = index
    if type(menu.ensureVisible) == "function" then menu:ensureVisible() end
    menu.view = "entry"
    menu.page = 1
    menu.entryAction = 1
    menu.modernGen2FamilySpecies = nil
    menu.modernGen2Family = nil
    menu.modernGen2FamilyCursor = nil
    menu.modernGen2FamilyScroll = 0
    resetMoveSelection(menu)
    if type(menu.playCry) == "function" then menu:playCry(member.species) end
    return true
  end

  local function drawOption(menu)
    local G = love.graphics
    local width = screenWidth(menu)
    local wide = width >= 240
    drawBackdrop(menu)
    drawHeader(menu, "OPTIONS")
    local rows = menu:optionRows()
    local shortLabel = {
      NEW = "NEW DEX MODE", OLD = "OLD DEX MODE", ["A-Z"] = "A-Z MODE",
      UNOWN = "UNOWN MODE",
    }
    for i, row in ipairs(rows) do
      local col = wide and (i - 1) % 2 or 0
      local rowIndex = wide and math.floor((i - 1) / 2) or (i - 1)
      local cardW = wide and math.floor((width - 17) / 2) or width - 14
      local x = 7 + col * (cardW + 3)
      local y = 23 + rowIndex * (wide and 36 or 21)
      local selected = i == menu.optionIndex
      setColor(selected and BLUE_DARK or (i % 2 == 0 and PAPER_ALT or PAPER))
      chamfer("fill", x, y, cardW, wide and 31 or 18, 3)
      if selected then
        setColor(INK_WHITE)
        G.rectangle("fill", x + 5, y + 5, 3, wide and 21 or 8)
      end
      drawInk(shortLabel[row.mode] or row.label, x + 13, y + 5, cardW - 20,
        selected and INK_WHITE or INK_BLACK)
    end
    local current = rows[menu.optionIndex]
    if current then
      drawInk(current.lines[1], 8, 111, width - 16, BLUE_DARK)
      drawInk(current.lines[2], 8, 121, width - 16, INK_BLACK)
    end
    drawFooter(menu, "A CHOOSE", "B BACK")
  end

  local function drawSearch(menu)
    local G = love.graphics
    local width = screenWidth(menu)
    local wide = width >= 240
    drawBackdrop(menu)
    drawHeader(menu, "SEARCH")
    local entries = {
      { "TYPE 1", menu:searchTypeName(1) },
      { "TYPE 2", menu:searchTypeName(2) },
      { "BEGIN SEARCH", "" }, { "CANCEL", "" },
    }
    for i, entry in ipairs(entries) do
      local col = wide and (i - 1) % 2 or 0
      local rowIndex = wide and math.floor((i - 1) / 2) or (i - 1)
      local cardW = wide and math.floor((width - 21) / 2) or width - 18
      local x = 9 + col * (cardW + 3)
      local y = 25 + rowIndex * (wide and 43 or 24)
      local selected = i == menu.searchIndex
      setColor(selected and BLUE_DARK or (i <= 2 and PAPER_ALT or PAPER))
      chamfer("fill", x, y, cardW, wide and 38 or 20, 3)
      drawInk(entry[1], x + 8, y + 6,
        entry[2] ~= "" and cardW - 16 or cardW - 15,
        selected and INK_WHITE or INK_BLACK)
      if entry[2] ~= "" then
        drawInkRight(entry[2], x + cardW - 7, y + (wide and 22 or 6),
          cardW - 14,
          selected and INK_WHITE or BLUE_DARK)
      end
    end
    if menu.searchMessage then
      drawInkCentered(menu.searchMessage, 8, 121, width - 16, BLUE_DARK)
    end
    drawFooter(menu, "L/R TYPE", "A CHOOSE B BACK")
  end

  local function drawToolFrame(menu)
    local width = screenWidth(menu)
    local title
    if menu.view == "area" then
      local row = menu:current()
      title = row and (menu:monName(row.species) .. " AREA") or "AREA"
    else
      title = "UNOWN MODE"
    end
    setColor(RED)
    love.graphics.rectangle("fill", 0, 0, width, 18)
    setColor(ORANGE)
    love.graphics.rectangle("fill", 0, 16, width, 2)
    drawInk(title, 4, 5, width - 8, INK_WHITE)
    if menu.view == "area" then
      drawFooter(menu, "L/R MAP", "A/B BACK")
    else
      drawFooter(menu, "L/R FORM", "A/B BACK")
    end
  end

  local function drawWideTool(menu, nativePanel)
    local G = love.graphics
    local width = screenWidth(menu)
    if width <= 160 then
      nativePanel(menu)
      drawToolFrame(menu)
      G.setColor(1, 1, 1, 1)
      return
    end
    drawBackdrop(menu)
    local nativeX = math.floor((width - 160) / 2)
    G.push()
    G.translate(nativeX, 0)
    nativePanel(menu)
    G.pop()

    -- The native map/form canvas remains pixel-faithful in the middle, while
    -- the extra columns become useful context rails instead of letterboxing.
    local railW = math.max(18, nativeX - 3)
    setColor(BLUE_DARK)
    chamfer("fill", 2, 21, railW, 108, 3)
    chamfer("fill", width - railW - 2, 21, railW, 108, 3)
    drawInkCentered(menu.view == "area" and "JOHTO" or "FORMS",
      4, 30, railW - 4, INK_WHITE)
    drawInkCentered(menu.view == "area" and "MAP" or "A-Z",
      width - railW, 30, railW - 4, INK_WHITE)
    drawInkCentered("L/R", 4, 113, railW - 4, INK_LIGHT)
    drawInkCentered("BACK", width - railW, 113, railW - 4, INK_LIGHT)
    drawToolFrame(menu)
    G.setColor(1, 1, 1, 1)
  end

  local presentationSource = assert(mod:read("gen2_presentation.lua"))
  local Presentation = assert(load(presentationSource,
    "@" .. mod.path .. "/gen2_presentation.lua"))()(mod, {
      drawPic = drawFittedPanelPic, family = evolutionFamily, known = familyKnown,
      label = evolutionLabel, moves = moveRows, focus = focusFamilyMember,
    })

  local inherited = mod.content.screens:get("Gen2PokedexMenu")
  local provider = inherited or PokedexMenu
  local record = {
    new = function(game, ...)
      if type(mod.exports.reconcileOwnedPokemon) == "function" then
        mod.exports.reconcileOwnedPokemon(game)
      end
      local menu = provider.new(game, ...)
      if type(menu) ~= "table" or menu.modernPokedexGeneration == 2 then
        return menu
      end
      local nativePanel = menu.drawPanel
      local nativeUpdate = menu.update
      menu.modernPokedexUI = true
      menu.modernPokedexGeneration = 2
      PortraitCutouts.attachPokedex(menu)
      menu.modernDexEntries = menu.rows
      menu.modernDexCount = #(menu.rows or {})
      menu.classicGen2PokedexPanel = nativePanel
      menu.modernGen2EvolutionFamily = function(self, species)
        return evolutionFamily(self, species)
      end
      menu.modernGen2EvolutionLabel = function(self, parent)
        return evolutionLabel(self, parent)
      end
      menu.modernGen2MoveRowsFor = function(self, species)
        return moveRows(self, species)
      end
      menu.modernGen2MoveCategory = function(self, move)
        return moveCategory(self, move)
      end
      -- Gen 1 uses five framed rows. Keep native NEW/OLD/A-Z ordering,
      -- search and selection, but make its scroll budget match that layout.
      menu.ensureVisible = function(self)
        local width = self.modernPokedexWideWidth or self.modernPokedexLastWideWidth or 160
        local rows = Presentation.listLayout(width).rows
        if self.index <= self.scroll then self.scroll = self.index - 1
        elseif self.index > self.scroll + rows then self.scroll = self.index - rows end
        self.scroll = math.max(0, math.min(self.scroll, math.max(0, #self.rows - rows)))
      end
      menu:ensureVisible()
      menu.update = function(self, dt)
        local input = self.game and self.game.input
        if input then
          self.entryBlink = (self.entryBlink or 0) + 1
          if Presentation.update(self, input) then return end
        end
        if type(nativeUpdate) == "function" then
          nativeUpdate(self, dt)
          if self.modernGen2ToolReturn and self.view == "entry" then
            self.view = self.modernGen2ToolReturn
            self.modernGen2ToolReturn = nil
          end
        end
      end
      menu.drawPanel = function(self)
        if self.view == "entry" or self.view == "list" or self.view == "results" then
          self:ensureVisible()
          Presentation.draw(self)
        elseif self.view == "option" then
          drawOption(self)
        elseif self.view == "search" then
          drawSearch(self)
        else
          drawWideTool(self, nativePanel)
        end
      end
      installWideDraw(menu, menu.drawPanel)
      return menu
    end,
  }

  if inherited then
    mod.content.screens:override("Gen2PokedexMenu", record)
  else
    mod.content.screens:register("Gen2PokedexMenu", record)
  end
  mod.exports.generation = 2
  mod.exports.dexSize = 251
  mod.log:info("modern native 251-species Gen 2 Pokedex enabled")
end
