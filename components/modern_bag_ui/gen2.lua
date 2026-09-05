-- Gen 2 owns a four-pocket PACK and a separate item PC. This adapter keeps
-- both native controllers, adds the Modern Bag's virtual browse/sort layer,
-- and replaces their presentation without changing physical storage.
return function(mod, shared)
  local Bag = require("src.inventory.Bag")
  local Chrome = require("src.ui.gen2.Chrome")
  local Font = require("src.render.Font")
  local PackMenu = require("src.ui.gen2.PackMenu")
  local ItemPcMenu = require("src.ui.gen2.ItemPcMenu")

  local INK_BLACK = { 0, 0, 0 }
  local INK_WHITE = { 1, 1, 1 }
  local INK_LIGHT = { 0.68, 0.84, 1 }
  local BLUE = { 0.18, 0.42, 0.88 }
  local BLUE_DARK = { 0.09, 0.20, 0.48 }
  local BLUE_LIGHT = { 0.65, 0.79, 0.94 }
  local GREEN = { 0.19, 0.60, 0.38 }
  local GREEN_DARK = { 0.08, 0.29, 0.18 }
  local PAPER = { 0.95, 0.96, 0.97 }
  local PAPER_ALT = { 0.84, 0.88, 0.92 }
  local TIMES = "\xc3\x97"

  local function option(game, key, fallback)
    local value = mod.options:get(key)
    if value == nil then return fallback end
    return value
  end

  local function install(id, native, decorate)
    local inherited = mod.content.screens:get(id)
    local provider = inherited or native
    local record = {
      new = function(game, ...)
        local menu = provider.new(game, ...)
        return decorate(menu, game, ...)
      end,
    }
    if inherited then
      mod.content.screens:override(id, record)
    else
      mod.content.screens:register(id, record)
    end
  end

  local function setColor(color, alpha)
    love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
  end

  local function toByte(color)
    local out = {}
    for i = 1, 3 do
      local value = color[i] or 0
      out[i] = math.floor((value <= 1 and value * 255 or value) + 0.5)
    end
    return out
  end

  local function inkPalette(color)
    local ink = toByte(color or INK_BLACK)
    return {
      { 255, 255, 255 },
      { math.floor((255 + ink[1]) / 2), math.floor((255 + ink[2]) / 2),
        math.floor((255 + ink[3]) / 2) },
      { math.floor(ink[1] / 2), math.floor(ink[2] / 2),
        math.floor(ink[3] / 2) },
      ink,
    }
  end

  local function fitText(text, maxWidth)
    text = tostring(text or "")
    if not maxWidth or Font.width(text) <= maxWidth then return text end
    local suffix = "."
    local budget = math.max(0, maxWidth - Font.width(suffix))
    if Font.split and Font.spansFitting then
      local spans = Font.split(text)
      local count = Font.spansFitting(spans, budget)
      return count > 0 and text:sub(1, spans[count].to) .. suffix or ""
    end
    while #text > 0 and Font.width(text) > budget do text = text:sub(1, -2) end
    return text .. suffix
  end

  local function drawInkRaw(text, x, y, color)
    text = tostring(text or "")
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

  local function drawInk(text, x, y, maxWidth, color)
    text = fitText(text, maxWidth)
    return drawInkRaw(text, x, y, color)
  end

  local function drawInkRight(text, right, y, maxWidth, color)
    text = fitText(text, maxWidth)
    local width = Font.width(text)
    drawInk(text, math.floor(right) - width, y, width, color)
    return width
  end

  local function moneyText(menu)
    local save = menu and (menu.save or (menu.game and menu.game.save))
    return ("¥%d"):format((save and tonumber(save.money)) or 0)
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

  local function splitDescription(text)
    text = tostring(text or "")
    local out = {}
    for part in (text:gsub("<NEXT>", "\n") .. "\n"):gmatch("(.-)\n") do
      for _, line in ipairs(Chrome.wrap(part, 19)) do out[#out + 1] = line end
    end
    return out
  end

  local function splitDescriptionFor(text, pixelWidth)
    local columns = math.max(8, math.floor((pixelWidth or 152) / 8))
    local out = {}
    for part in (tostring(text or ""):gsub("<NEXT>", "\n") .. "\n")
        :gmatch("(.-)\n") do
      for _, line in ipairs(Chrome.wrap(part, columns)) do
        out[#out + 1] = line
      end
    end
    return out
  end

  local function descriptionScrollState(menu, key)
    local state = menu.modernBagDescriptionScroll
    if not state or state.key ~= key then
      state = { key = key, elapsed = 0, offset = 0, overflow = false }
      menu.modernBagDescriptionScroll = state
    end
    return state
  end

  local function clearDescriptionScroll(menu)
    menu.modernBagDescriptionScroll = nil
  end

  local function setLogicalScissor(x, y, width, height)
    local x1, y1, x2, y2 = x, y, x + width, y + height
    if love.graphics.transformPoint then
      x1, y1 = love.graphics.transformPoint(x1, y1)
      x2, y2 = love.graphics.transformPoint(x2, y2)
    end
    local clipX, clipY = math.min(x1, x2), math.min(y1, y2)
    local clipW, clipH = math.abs(x2 - x1), math.abs(y2 - y1)
    love.graphics.setScissor(math.floor(clipX), math.floor(clipY),
      math.max(1, math.ceil(clipW)), math.max(1, math.ceil(clipH)))
  end

  local function drawReadableDescription(menu, key, text, x, y,
      maxWidth, maxLines, color)
    text = tostring(text or "")
    maxWidth = math.max(8, math.floor(maxWidth or 8))
    maxLines = math.max(1, math.floor(maxLines or 1))
    local lines = splitDescriptionFor(text, maxWidth)
    local fits = #lines <= maxLines
    for _, line in ipairs(lines) do
      if Font.width(line) > maxWidth then fits = false break end
    end
    local stateKey = table.concat({ tostring(key or "description"), text,
      tostring(maxWidth), tostring(maxLines) }, "\31")
    local state = descriptionScrollState(menu, stateKey)
    state.overflow = not fits
    state.maxWidth, state.maxLines = maxWidth, maxLines
    if fits then
      state.offset, state.travel = 0, 0
      for index, line in ipairs(lines) do
        drawInk(line, x, y + (index - 1) * 8, maxWidth, color)
      end
      return false
    end

    local staticCount = math.max(0, maxLines - 1)
    for index = 1, staticCount do
      local line = lines[index]
      if not line or Font.width(line) > maxWidth then
        staticCount = 0
        break
      end
    end
    for index = 1, staticCount do
      drawInk(lines[index], x, y + (index - 1) * 8, maxWidth, color)
    end
    local tail = {}
    for index = staticCount + 1, #lines do tail[#tail + 1] = lines[index] end
    if #tail == 0 then tail[1] = text end
    local tailText = table.concat(tail, "  ")
    local travel = math.max(0, Font.width(tailText) - maxWidth)
    local holdStart, holdEnd, speed = 1.0, 0.75, 36
    local moving = travel / speed
    local cycle = holdStart + moving + holdEnd
    local phase = cycle > 0 and ((state.elapsed or 0) % cycle) or 0
    local offset
    if phase <= holdStart then
      offset = 0
    elseif phase < holdStart + moving then
      offset = math.min(travel, (phase - holdStart) * speed)
    else
      offset = travel
    end
    state.offset, state.travel = offset, travel
    state.tailText, state.staticLines = tailText, staticCount
    local lineY = y + staticCount * 8
    if love.graphics.setScissor then
      love.graphics.push("all")
      -- Scissors use render-target coordinates and do not follow the current
      -- transform. The native Pocket panel is translated inside wide layouts,
      -- so map the logical description viewport before clipping the marquee.
      setLogicalScissor(x, lineY, maxWidth, 8)
      drawInkRaw(tailText, x - offset, lineY, color)
      love.graphics.pop()
    else
      drawInk(tailText, x, lineY, maxWidth, color)
    end
    return true
  end

  -- Game2's stock drawWidescreen methods only centre the 160x144 cartridge
  -- panel.  A Modern UI surface instead keeps the largest integer scale that
  -- fits the classic height, then spends the remaining native pixels on the
  -- layout.  This is the same sizing rule the Gen 1 presenter uses.
  local function installWideDraw(menu, drawPanel, surround)
    menu.drawWidescreen = function(self, winW, winH)
      local G = love.graphics
      local scale = math.max(1, math.floor(math.min(winH / 144, winW / 160)))
      local width = math.max(160, math.min(400, math.floor(winW / scale)))
      local ox = math.floor((winW - width * scale) / 2)
      local oy = math.floor((winH - 144 * scale) / 2)
      setColor(surround)
      G.rectangle("fill", 0, 0, winW, winH)
      G.push()
      G.translate(ox, oy)
      G.scale(scale, scale)
      self.modernBagLastWideWidth = width
      self.modernBagWideWidth = width
      drawPanel(self)
      self.modernBagWideWidth = nil
      G.pop()
      G.setColor(1, 1, 1, 1)
    end
  end

  -- Gen 2 physically stores four pockets, but the Modern Bag's Gen 1 surface
  -- also provides All and Medicine views. Keep those as filters over the
  -- cartridge stores: no inventory entry is migrated and every native action
  -- still receives the item's real source pocket.
  local MODERN_POCKETS = {
    { id = "ALL", full = "ALL", label = "ALL", compact = "A",
      title = "ALL ITEMS" },
    { id = "ITEMS", source = "ITEM", full = "ITEMS", label = "ITEM",
      compact = "I", title = "ITEMS" },
    { id = "MEDICINE", source = "ITEM", full = "MEDICINE", label = "MED",
      compact = "M", title = "MEDICINE" },
    { id = "BALL", source = "BALL", full = "BALLS", label = "BALL",
      compact = "B", title = "POKé BALLS" },
    { id = "TM_HM", source = "TM_HM", full = "TM/HM", label = "TM",
      compact = "TM", title = "TMs/HMs" },
    { id = "KEY_ITEM", source = "KEY_ITEM", full = "KEY ITEMS", label = "KEY",
      compact = "K", title = "KEY ITEMS" },
  }

  local MODERN_POCKET_INDEX = {}
  for index, pocket in ipairs(MODERN_POCKETS) do
    MODERN_POCKET_INDEX[pocket.id] = index
  end

  local NATIVE_POCKET_INDEX = {}
  for index, pocket in ipairs(PackMenu.POCKETS or {}) do
    NATIVE_POCKET_INDEX[pocket.id] = index
  end

  local MEDICINE = {
    ANTIDOTE = true, AWAKENING = true, BERRY = true, BERRY_JUICE = true,
    BITTER_BERRY = true, BURNT_BERRY = true, BURN_HEAL = true,
    CALCIUM = true, CARBOS = true, ELIXER = true, ENERGYPOWDER = true,
    ENERGY_ROOT = true, ETHER = true, FRESH_WATER = true, FULL_HEAL = true,
    FULL_RESTORE = true, GOLD_BERRY = true, HEAL_POWDER = true, HP_UP = true,
    HYPER_POTION = true, ICE_BERRY = true, ICE_HEAL = true, IRON = true,
    LEMONADE = true, MAX_ELIXER = true, MAX_ETHER = true,
    MAX_POTION = true, MAX_REVIVE = true, MINT_BERRY = true,
    MIRACLEBERRY = true, MOOMOO_MILK = true, MYSTERYBERRY = true,
    PARLYZ_HEAL = true, POTION = true, PP_UP = true, PROTEIN = true,
    PRZCUREBERRY = true, PSNCUREBERRY = true, RAGECANDYBAR = true,
    RARE_CANDY = true, REVIVAL_HERB = true, REVIVE = true,
    SACRED_ASH = true, SODA_POP = true, SUPER_POTION = true, ZINC = true,
  }

  local SORT_CHOICES = {
    { label = "CATEGORY ASC", kind = "category" },
    { label = "CATEGORY DESC", kind = "category", descending = true },
    { label = "NAMES A-Z", kind = "name" },
    { label = "NAMES Z-A", kind = "name", descending = true },
  }

  local POCKET_LABEL = {
    ALL = "ALL", ITEMS = "ITEM", MEDICINE = "MED",
    ITEM = "ITEM", BALL = "BALL", KEY_ITEM = "KEY", TM_HM = "TM",
  }

  local SUBMENU_LABEL = {
    use = "USE", give = "GIVE", toss = "TOSS", sel = "SEL", quit = "QUIT",
  }

  local function parityEnabled(menu, game)
    return menu.modernBagControllerReady
      and option(menu.game or game, "skin", "modern") ~= "classic_pocket"
  end

  local function activeModernPocket(menu)
    return MODERN_POCKETS[menu.modernBagPocketIndex or 1]
      or MODERN_POCKETS[1]
  end

  local function pocketLabelFor(pocket, tabWidth)
    local full = pocket.full or pocket.label
      or POCKET_LABEL[pocket.id] or pocket.id
    local regular = pocket.label or POCKET_LABEL[pocket.id] or pocket.id
    local label = Font.width(full) <= tabWidth and full
      or (Font.width(regular) <= tabWidth and regular)
      or pocket.compact or regular
    return fitText(label, tabWidth)
  end

  local function modernTabLabels(width)
    local labels = {}
    for i, pocket in ipairs(MODERN_POCKETS) do
      local x = math.floor((i - 1) * width / #MODERN_POCKETS)
      local nextX = math.floor(i * width / #MODERN_POCKETS)
      labels[i] = pocketLabelFor(pocket, nextX - x)
    end
    return labels
  end

  local function selectedId(menu)
    local row = menu.rows and menu.rows[menu.index]
    return row and row.id or nil
  end

  local function isMedicine(menu, itemId)
    if MEDICINE[itemId] then return true end
    local def = menu.items and menu.items[itemId]
    if not def or (def.pocket and def.pocket ~= "ITEM") then return false end
    local declared = tostring(def.modernBagCategory or def.bagCategory
      or def.category or ""):lower()
    if declared == "medicine" or declared == "med" then return true end
    local held = tostring(def.heldEffect or "")
    if held == "HELD_BERRY" or held == "HELD_RESTORE_PP"
        or held:find("HELD_HEAL", 1, true) == 1 then
      return true
    end
    -- Gen 2 evolution stones use the party selector too, but the established
    -- Gen 1 Medicine category leaves them with general Items.
    local looksLikeStone = tostring(itemId):find("STONE", 1, true) ~= nil
    return def.fieldMenu == "ITEMMENU_PARTY" and not looksLikeStone
  end

  local function categoryFor(menu, itemId)
    local source = menu.pocketOf and menu:pocketOf(itemId) or "ITEM"
    if source == "ITEM" then
      return isMedicine(menu, itemId) and "MEDICINE" or "ITEMS"
    end
    return source
  end

  local function viewIncludes(menu, view, itemId)
    if view.id == "ALL" then return true end
    return categoryFor(menu, itemId) == view.id
  end

  local function orderedBagIds(menu)
    local save = menu.save
    if not (save and type(save.inventory) == "table") then return {} end
    local ok, order = pcall(Bag.order, save, menu.bagData)
    return ok and type(order) == "table" and order or {}
  end

  local function nativeRowsById(menu, baseRebuild)
    local savedPocket, savedIndex, savedScroll, savedRows = menu.pocketIndex,
      menu.index, menu.scroll, menu.rows
    local rows = {}
    for index, pocket in ipairs(PackMenu.POCKETS or {}) do
      menu.pocketIndex, menu.index, menu.scroll = index, 1, 0
      baseRebuild(menu)
      for _, row in ipairs(menu.rows or {}) do
        row.modernBagSourcePocket = pocket.id
        rows[row.id] = row
      end
    end
    menu.pocketIndex, menu.index, menu.scroll, menu.rows = savedPocket,
      savedIndex, savedScroll, savedRows
    return rows
  end

  local function restoreRow(menu, wantedId, fallbackIndex, fallbackScroll)
    local index
    if wantedId then
      for i, row in ipairs(menu.rows or {}) do
        if row.id == wantedId then index = i break end
      end
    end
    menu.index = index or math.max(1, math.min(tonumber(fallbackIndex) or 1,
      #(menu.rows or {}) + 1))
    menu.scroll = math.max(0, tonumber(fallbackScroll) or 0)
    if menu.ensureVisible then menu:ensureVisible() end
  end

  local function rebuildModernRows(menu, baseRebuild)
    local restore = menu.modernBagRestoreState
    menu.modernBagRestoreState = nil
    local wantedId = restore and restore.id or selectedId(menu)
    local fallbackIndex = restore and restore.index or menu.index
    local fallbackScroll = restore and restore.scroll or menu.scroll
    local view = activeModernPocket(menu)
    local sourceIndex = view.source and NATIVE_POCKET_INDEX[view.source]

    if sourceIndex and view.id ~= "ITEMS" and view.id ~= "MEDICINE" then
      menu.pocketIndex = sourceIndex
      baseRebuild(menu)
      for _, row in ipairs(menu.rows or {}) do
        row.modernBagSourcePocket = view.source
      end
      -- The native TM/HM controller always restores number order. Name sorts
      -- are the explicit exception requested by the shared Start sorter.
      if view.id == "TM_HM" and menu.modernBagSortKind == "name" then
        local descending = menu.modernBagSortDescending
        table.sort(menu.rows, function(a, b)
          local av = tostring(a.name or a.id):lower()
          local bv = tostring(b.name or b.id):lower()
          if av ~= bv then
            if descending then return av > bv end
            return av < bv
          end
          if descending then return tostring(a.id) > tostring(b.id) end
          return tostring(a.id) < tostring(b.id)
        end)
      end
    else
      local nativeRows = nativeRowsById(menu, baseRebuild)
      local rows = {}
      for _, itemId in ipairs(orderedBagIds(menu)) do
        local row = nativeRows[itemId]
        if row and viewIncludes(menu, view, itemId) then rows[#rows + 1] = row end
      end
      menu.rows = rows
    end

    restoreRow(menu, wantedId, fallbackIndex, fallbackScroll)
    local row = menu.rows and menu.rows[menu.index]
    local physical = (row and row.modernBagSourcePocket) or view.source
    if physical and NATIVE_POCKET_INDEX[physical] then
      menu.pocketIndex = NATIVE_POCKET_INDEX[physical]
    end
  end

  local function saveModernPocketState(menu)
    local view = activeModernPocket(menu)
    menu.modernBagPocketState[view.id] = {
      id = selectedId(menu), index = menu.index, scroll = menu.scroll,
    }
    if menu.modernBagPersistentState then
      menu.modernBagPersistentState.pocket = view.id
    end
  end

  local function prepareSelectedPocket(menu)
    local row = menu.rows and menu.rows[menu.index]
    local source = row and (row.modernBagSourcePocket
      or (menu.pocketOf and menu:pocketOf(row.id)))
    if source and NATIVE_POCKET_INDEX[source] then
      menu.pocketIndex = NATIVE_POCKET_INDEX[source]
    end
  end

  local function storeSelectedNativeCursor(menu, baseRebuild, baseStoreCursor)
    if not baseStoreCursor then return end
    local row = menu.rows and menu.rows[menu.index]
    local source = row and (row.modernBagSourcePocket
      or (menu.pocketOf and menu:pocketOf(row.id)))
    local sourceIndex = source and NATIVE_POCKET_INDEX[source]
    if not (row and sourceIndex) then return end
    local savedPocket, savedIndex, savedScroll, savedRows = menu.pocketIndex,
      menu.index, menu.scroll, menu.rows
    menu.pocketIndex, menu.index, menu.scroll = sourceIndex, 1, 0
    baseRebuild(menu)
    for index, nativeRow in ipairs(menu.rows or {}) do
      if nativeRow.id == row.id then menu.index = index break end
    end
    if menu.ensureVisible then menu:ensureVisible() end
    baseStoreCursor(menu)
    menu.pocketIndex, menu.index, menu.scroll, menu.rows = savedPocket,
      savedIndex, savedScroll, savedRows
  end

  local function swapBagRows(menu, sourceId, targetId)
    if not sourceId or not targetId or sourceId == targetId then return false end
    local order = orderedBagIds(menu)
    local sourceIndex, targetIndex
    for index, itemId in ipairs(order) do
      if itemId == sourceId then sourceIndex = index end
      if itemId == targetId then targetIndex = index end
    end
    if not (sourceIndex and targetIndex) then return false end
    order[sourceIndex], order[targetIndex] = order[targetIndex], order[sourceIndex]
    return true
  end

  local function sortBag(menu, kind, descending)
    local save = menu.save
    local inventory = save and save.inventory
    if type(inventory) ~= "table" then return false end
    local selected = selectedId(menu)
    local entries = {}
    for index, itemId in ipairs(orderedBagIds(menu)) do
      if inventory[itemId] and not Bag.isBadge(itemId) then
        local def = menu.items and menu.items[itemId] or {}
        entries[#entries + 1] = {
          id = itemId,
          original = index,
          name = tostring(def.name or itemId):lower(),
          category = categoryFor(menu, itemId),
        }
      end
    end
    local ranks = { ITEMS = 1, MEDICINE = 2, BALL = 3, TM_HM = 4,
      KEY_ITEM = 5 }
    table.sort(entries, function(a, b)
      if kind == "category" then
        local av, bv = ranks[a.category] or 99, ranks[b.category] or 99
        if av ~= bv then
          if descending then return av > bv end
          return av < bv
        end
        return a.original < b.original
      end
      if a.name ~= b.name then
        if descending then return a.name > b.name end
        return a.name < b.name
      end
      if descending then return a.id > b.id end
      return a.id < b.id
    end)
    local order = save.bagOrder
    if type(order) ~= "table" then
      order = {}
      save.bagOrder = order
    end
    for index = #order, 1, -1 do order[index] = nil end
    for index, entry in ipairs(entries) do order[index] = entry.id end
    menu.modernBagSortKind = kind
    menu.modernBagSortDescending = descending and true or false
    menu.modernBagRestoreState = { id = selected }
    if menu.rebuild then menu:rebuild() end
    return true
  end

  local function openSortMenu(menu)
    if menu.tutorial then return false end
    menu.modernBagSortMenu = { index = 1, rows = SORT_CHOICES }
    if menu.playSfx then menu:playSfx("Sfx_ReadText2") end
    return true
  end

  local function updateSortMenu(menu, input)
    local sort = menu.modernBagSortMenu
    if input:wasPressed("up") then
      sort.index = sort.index > 1 and sort.index - 1 or #sort.rows
    elseif input:wasPressed("down") then
      sort.index = sort.index < #sort.rows and sort.index + 1 or 1
    elseif input:wasPressed("a") then
      local choice = sort.rows[sort.index]
      menu.modernBagSortMenu = nil
      sortBag(menu, choice.kind, choice.descending)
      if menu.playSfx then menu:playSfx("Sfx_ReadText2") end
    elseif input:wasPressed("b") or input:wasPressed("start") then
      menu.modernBagSortMenu = nil
      if menu.playSfx then menu:playSfx("Sfx_ReadText2") end
    end
  end

  local function drawPackOverlay(self)
    local G = love.graphics
    local width = self.modernBagWideWidth or 160
    local listW = parityEnabled(self) and width or math.min(width, 160)
    if self.modernBagSortMenu then
      local sort = self.modernBagSortMenu
      local w, h = math.min(128, listW - 8), 78
      local x, y = listW - w - 4, 26
      setColor(BLUE_LIGHT)
      chamfer("fill", x, y, w, h, 3)
      setColor(BLUE_DARK)
      G.setLineWidth(2)
      chamfer("line", x + 1, y + 1, w - 2, h - 2, 3)
      drawInk("SORT BY", x + 9, y + 6, w - 18, INK_BLACK)
      for i, choice in ipairs(sort.rows or SORT_CHOICES) do
        local rowY = y + 17 + (i - 1) * 14
        if i == sort.index then
          setColor(BLUE_DARK)
          G.rectangle("fill", x + 5, rowY, w - 10, 13)
        end
        drawInk(choice.label, x + 14, rowY + 3, w - 21,
          i == sort.index and INK_WHITE or INK_BLACK)
        if i == sort.index then
          setColor(INK_WHITE)
          G.rectangle("fill", x + 8, rowY + 4, 3, 5)
        end
      end
    end
    if self.submenu then
      local menu = self.submenu
      local count = #menu.rows
      local h = count * 16 + 8
      local x, y, w = listW - 84, math.max(18, 112 - h), 82
      setColor(BLUE_LIGHT)
      chamfer("fill", x, y, w, h, 3)
      setColor(BLUE_DARK)
      G.setLineWidth(2)
      chamfer("line", x + 1, y + 1, w - 2, h - 2, 3)
      for i, id in ipairs(menu.rows) do
        local rowY = y + 4 + (i - 1) * 16
        if i == menu.index then
          setColor(BLUE_DARK)
          G.rectangle("fill", x + 5, rowY, w - 10, 14)
        end
        drawInk(SUBMENU_LABEL[id] or tostring(id):upper(), x + 13, rowY + 3,
          w - 20, i == menu.index and INK_WHITE or INK_BLACK)
        if i == menu.index then
          setColor(INK_WHITE)
          G.rectangle("fill", x + 7, rowY + 5, 3, 5)
        end
      end
    end
    if self.qtyState then
      local x, y, w, h = listW - 56, 86, 54, 24
      setColor(BLUE_LIGHT)
      chamfer("fill", x, y, w, h, 3)
      setColor(BLUE_DARK)
      chamfer("line", x + 0.5, y + 0.5, w - 1, h - 1, 3)
      drawInk(TIMES .. ("%02d"):format(self.qtyState.qty or 1),
        x + 9, y + 8, w - 16, INK_BLACK)
    end
    if self.confirm then
      local x, y, w, h = listW - 56, 66, 54, 44
      setColor(BLUE_LIGHT)
      chamfer("fill", x, y, w, h, 3)
      for i, label in ipairs({ "YES", "NO" }) do
        local rowY = y + 5 + (i - 1) * 16
        if i == self.confirm.choice then
          setColor(BLUE_DARK)
          G.rectangle("fill", x + 4, rowY, w - 8, 14)
        end
        drawInk(label, x + 15, rowY + 3, 28,
          i == self.confirm.choice and INK_WHITE or INK_BLACK)
      end
    end
  end

  local function packHeaderInfo(menu, width)
    local cash = moneyText(menu)
    local cashW = Font.width(cash)
    local fullCount = ("%02d ITEMS"):format(#(menu.rows or {}))
    local shortCount = ("%02d"):format(#(menu.rows or {}))
    local countText = fullCount
    local availableWithFull = width - 5 - cashW - 4
      - Font.width(fullCount) - 5
    if availableWithFull < Font.width("START") then countText = shortCount end
    local countW = Font.width(countText)
    local hintLeft = 5 + cashW + 4
    local hintRight = width - 5 - countW - 4
    local hintWidth = math.max(0, hintRight - hintLeft)
    local hint = hintWidth >= Font.width("START SORT") and "START SORT"
      or (hintWidth >= Font.width("START") and "START" or nil)
    return {
      cash = cash, cashX = 5, cashW = cashW,
      count = countText, countW = countW,
      countX = width - 5 - countW,
      hint = hint, hintLeft = hintLeft, hintRight = hintRight,
    }
  end

  local function modernPackPanel(self)
    local G = love.graphics
    local width = self.modernBagWideWidth or 160
    local listW = width
    setColor({ 0.90, 0.93, 0.96 })
    G.rectangle("fill", 0, 0, width, 144)

    setColor(BLUE)
    G.rectangle("fill", 0, 0, width, 16)
    setColor(BLUE_LIGHT)
    G.rectangle("fill", 0, 14, width, 2)
    local header = packHeaderInfo(self, width)
    drawInk(header.cash, header.cashX, 4, header.cashW, INK_WHITE)
    drawInkRight(header.count, width - 5, 4, header.countW, INK_WHITE)
    if header.hint then
      drawInk(header.hint, header.hintLeft + math.floor(
        (header.hintRight - header.hintLeft - Font.width(header.hint)) / 2),
        4, header.hintRight - header.hintLeft, INK_LIGHT)
    end
    self.modernBagHeaderCash = header.cash
    self.modernBagHeaderBounds = header

    local pockets = parityEnabled(self) and MODERN_POCKETS
      or (PackMenu.POCKETS or {})
    local selectedPocket = parityEnabled(self) and self.modernBagPocketIndex
      or self.pocketIndex
    local pocketCount = math.max(1, #pockets)
    for i, pocket in ipairs(pockets) do
      local x = math.floor((i - 1) * listW / pocketCount)
      local nextX = math.floor(i * listW / pocketCount)
      local tabW = nextX - x
      local selected = i == selectedPocket
      setColor(selected and BLUE_DARK or PAPER)
      G.rectangle("fill", x + 1, 17, tabW - 2, 14)
      setColor(selected and BLUE_LIGHT or PAPER_ALT)
      G.rectangle("line", x + 1.5, 17.5, tabW - 3, 13)
      local fitted = pocketLabelFor(pocket, tabW)
      drawInk(fitted, x + math.floor((tabW - Font.width(fitted)) / 2), 20,
        tabW, selected and INK_WHITE or INK_BLACK)
    end

    for visible = 1, 5 do
      local i = visible + (self.scroll or 0)
      local y = 32 + (visible - 1) * 16
      local selected = i == self.index
      setColor(selected and BLUE_DARK or (visible % 2 == 0 and PAPER_ALT or PAPER))
      G.rectangle("fill", 2, y + 1, listW - 4, 14)
      if selected then
        setColor(INK_WHITE)
        G.rectangle("fill", 4, y + 4, 2, 8)
      end
      local color = selected and INK_WHITE or INK_BLACK
      local entry = self.rows and self.rows[i]
      if entry then
        local label = (entry.tmhmLabel and
          (entry.tmhmLabel .. " " .. tostring(entry.teaches or entry.name)))
          or entry.name
        drawInk(label, 10, y + 4, listW - 50, color)
        if entry.showCount then
          drawInkRight(TIMES .. tostring(entry.count or 0), listW - 7, y + 4, 32,
            color)
        end
      elseif i == self:total() then
        drawInk("CANCEL", 10, y + 4, 96, color)
      end
      if i == self.switching and not selected then
        setColor(BLUE_DARK)
        G.rectangle("line", 3.5, y + 2.5, listW - 7, 11)
      end
    end

    setColor({ 0.04, 0.05, 0.07 })
    local footerX, footerY, footerW, footerH = 0, 112, width, 32
    G.rectangle("fill", footerX, footerY, footerW, footerH)
    setColor(BLUE_LIGHT)
    G.rectangle("line", footerX + 1.5, footerY + 1.5,
      footerW - 3, footerH - 3)
    local current = self.rows and self.rows[self.index]
    local lines = self.message or (self.confirm and self.confirm.prompt)
    local hasTitle = current and not lines
    if current and not lines then
      drawInk(current.name or current.id, footerX + 6, footerY + 3,
        footerW - 12, INK_LIGHT)
      local description = self:description()
      local canScroll = not (self.modernBagSortMenu or self.submenu
        or self.qtyState or self.confirm or self.switching)
      if canScroll then
        drawReadableDescription(self, current.id, description,
          footerX + 6, footerY + 13, footerW - 12, 2, INK_WHITE)
      else
        clearDescriptionScroll(self)
        lines = splitDescriptionFor(description, footerW - 12)
      end
    else
      clearDescriptionScroll(self)
    end
    local maxLines = hasTitle and 2 or 3
    local firstLineY = hasTitle and (footerY + 13) or (footerY + 4)
    for i = 1, math.min(maxLines, #(lines or {})) do
      drawInk(tostring(lines[i]):gsub("{PLAYER}", self:playerName()),
        footerX + 6, firstLineY + (i - 1) * 8, footerW - 12, INK_WHITE)
    end
    drawPackOverlay(self)
    G.setColor(1, 1, 1, 1)
  end

  local function drawClassicPackEnhancements(self)
    local blocked = self.message or self.confirm or self.qtyState
      or self.submenu or self.modernBagSortMenu or self.switching
    local current = self.rows and self.rows[self.index]
    local description = current and self:description()
    if not blocked and description then
      Chrome.box(0, 12, 20, 6)
      drawReadableDescription(self, current.id, description,
        8, 104, 144, 2, INK_BLACK)
    else
      clearDescriptionScroll(self)
    end

    local cash = moneyText(self)
    local cashW = math.min(64, math.max(32, Font.width(cash) + 8))
    setColor(BLUE_DARK)
    love.graphics.rectangle("fill", 0, 0, cashW, 16)
    drawInk(cash, 4, 4, cashW - 8, INK_WHITE)
    self.modernBagHeaderCash = cash
    self.modernBagHeaderBounds = {
      cash = cash, cashX = 4, cashW = Font.width(cash),
      countX = 160, hintLeft = cashW, hintRight = cashW,
    }
  end

  local function decoratePack(menu, game, opts)
    if type(menu) ~= "table" or menu.modernBagGeneration == 2 then return menu end
    local nativePanel = menu.drawPanel
    local baseUpdate = menu.update
    local baseRebuild = menu.rebuild
    local baseSwitchPocket = menu.switchPocket
    local baseStoreCursor = menu.storeCursor
    local baseRestoreCursor = menu.restoreCursor
    local baseArmSwitch = menu.armSwitch
    local basePlaceSwitch = menu.placeSwitch
    local baseEndSwitch = menu.endSwitch
    menu.modernBagUI = true
    menu.modernBagGeneration = 2
    menu.classicGen2PackPanel = nativePanel
    local stateOwner = menu.game or game
    local persistent = stateOwner and stateOwner.modernBagGen2Cursor
    if stateOwner and not persistent then
      persistent = { views = {} }
      stateOwner.modernBagGen2Cursor = persistent
    end
    if persistent then persistent.views = persistent.views or {} end
    menu.modernBagPersistentState = persistent
    menu.modernBagPocketState = persistent and persistent.views or {}
    local nativePocket = (PackMenu.POCKETS or {})[menu.pocketIndex or 1]
    local initialId = nativePocket and nativePocket.id or "ITEM"
    if initialId == "ITEM" then initialId = "ITEMS" end
    local specialPack = type(opts) == "table"
      and (opts.pocket or opts.give or opts.battle or opts.tutorial)
    if not specialPack and persistent and persistent.pocket
        and MODERN_POCKET_INDEX[persistent.pocket] then
      initialId = persistent.pocket
    end
    menu.modernBagPocketIndex = MODERN_POCKET_INDEX[initialId] or 1
    menu.modernBagRestoreState = menu.modernBagPocketState[initialId]
    menu.modernBagControllerReady = type(baseUpdate) == "function"
      and type(baseRebuild) == "function"

    if menu.modernBagControllerReady then
      menu.rebuild = function(self)
        if parityEnabled(self, game) then
          return rebuildModernRows(self, baseRebuild)
        end
        return baseRebuild(self)
      end

      menu.storeCursor = function(self)
        if parityEnabled(self, game) then
          saveModernPocketState(self)
          local id = activeModernPocket(self).id
          if id == "ALL" or id == "ITEMS" or id == "MEDICINE" then
            return storeSelectedNativeCursor(self, baseRebuild, baseStoreCursor)
          end
        end
        if baseStoreCursor then return baseStoreCursor(self) end
      end

      menu.restoreCursor = function(self)
        if parityEnabled(self, game) then
          local view = activeModernPocket(self)
          local state = self.modernBagPocketState[view.id]
          if state then
            self.index, self.scroll = state.index or 1, state.scroll or 0
            return
          end
          if view.id == "ALL" or view.id == "ITEMS"
              or view.id == "MEDICINE" then
            self.index, self.scroll = 1, 0
            return
          end
        end
        if baseRestoreCursor then return baseRestoreCursor(self) end
      end

      menu.switchPocket = function(self, delta)
        if not parityEnabled(self, game) then
          return baseSwitchPocket(self, delta)
        end
        self:storeCursor()
        self.modernBagPocketIndex = (self.modernBagPocketIndex - 1
          + (delta or 0)) % #MODERN_POCKETS + 1
        local view = activeModernPocket(self)
        local state = self.modernBagPocketState[view.id]
        if not state and view.source and view.id ~= "ITEMS"
            and view.id ~= "MEDICINE" and baseRestoreCursor then
          self.pocketIndex = NATIVE_POCKET_INDEX[view.source]
          baseRestoreCursor(self)
          state = { index = self.index, scroll = self.scroll }
        end
        self.modernBagRestoreState = state or { index = 1, scroll = 0 }
        self.switching, self.message = nil, nil
        self:rebuild()
        if self.playSfx then self:playSfx("Sfx_SwitchPockets") end
      end

      menu.armSwitch = function(self)
        if parityEnabled(self, game) then
          local id = activeModernPocket(self).id
          if id == "ALL" or id == "ITEMS" or id == "MEDICINE" then
            if self.isCancel and self:isCancel() then return end
            if not (self.rows and self.rows[self.index]) then return end
            self.switching = self.index
            self.message = { "Where should this", "be moved to?" }
            return
          end
        end
        return baseArmSwitch(self)
      end

      menu.placeSwitch = function(self)
        if parityEnabled(self, game) then
          local id = activeModernPocket(self).id
          if id == "ALL" or id == "ITEMS" or id == "MEDICINE" then
            local source = self.rows and self.rows[self.switching]
            local target = self.rows and self.rows[self.index]
            if source and target then swapBagRows(self, source.id, target.id) end
            self.modernBagRestoreState = { id = source and source.id }
            self:rebuild()
            if self.playSfxTwice then self:playSfxTwice("Sfx_SwitchPokemon") end
            if baseEndSwitch then baseEndSwitch(self) else
              self.switching, self.message = nil, nil
            end
            return
          end
        end
        return basePlaceSwitch(self)
      end

      menu.update = function(self, dt)
        local description = self.modernBagDescriptionScroll
        if description then
          description.elapsed = (description.elapsed or 0)
            + math.max(0, tonumber(dt) or 0)
        end
        local input = self.game and self.game.input
        if self.modernBagSortMenu then
          clearDescriptionScroll(self)
          if input and input.wasPressed then updateSortMenu(self, input) end
          return
        end
        local idle = not (self.qtyState or self.switching or self.message
          or self.confirm or self.submenu or self.repeatSfx)
        if idle and input and input.wasPressed
            and input:wasPressed("start") and openSortMenu(self) then
          return
        end
        if idle and parityEnabled(self, game) and input and input.wasPressed
            and (input:wasPressed("a") or input:wasPressed("select")) then
          prepareSelectedPocket(self)
        end
        return baseUpdate(self, dt)
      end

      -- Rebuild once through the virtual view after all method wrappers are in
      -- place. The original native pocket remains the starting selection.
      menu:rebuild()
    end

    menu.drawPanel = function(self)
      if option(self.game or game, "skin", "modern") == "classic_pocket" then
        local width = tonumber(self.modernBagWideWidth) or 160
        if width <= 160 then
          local result = nativePanel(self)
          drawClassicPackEnhancements(self)
          if self.modernBagSortMenu then drawPackOverlay(self) end
          return result
        end
        love.graphics.push()
        local panelX = math.floor((width - 160) / 2)
        love.graphics.translate(panelX, 0)
        love.graphics.push("all")
        if love.graphics.setScissor then
          -- Keep stock content inside its cartridge-sized panel. In
          -- particular, the native one-line description is unbounded.
          setLogicalScissor(0, 0, 160, 144)
        end
        local ok, result = pcall(nativePanel, self)
        love.graphics.pop()
        if ok then
          drawClassicPackEnhancements(self)
          if self.modernBagSortMenu then drawPackOverlay(self) end
        end
        love.graphics.pop()
        if not ok then error(result, 0) end
        return result
      end
      return modernPackPanel(self)
    end
    installWideDraw(menu, menu.drawPanel, { 0.90, 0.93, 0.96 })
    -- Preserve the helper names used by existing preview and companion mods.
    menu.modernBagSwitchPocket = function(self, delta)
      return self:switchPocket(delta)
    end
    menu.modernBagLayoutInfo = function(self)
      local modern = parityEnabled(self, game)
      local width = tonumber(self.modernBagWideWidth
        or self.modernBagLastWideWidth) or 160
      return { generation = 2, pockets = modern and #MODERN_POCKETS or 4,
        pocket = modern and activeModernPocket(self).id
          or ((PackMenu.POCKETS or {})[self.pocketIndex or 1] or {}).id,
        skin = option(self.game or game, "skin", "modern"),
        layout = modern and "full-width-bottom" or "native",
        listWidth = modern and width or math.min(width, 160),
        detailPosition = modern and "bottom" or "native",
        detailWidth = modern and width or math.min(width, 160),
        tabLabels = modern and modernTabLabels(width) or nil }
    end
    menu.modernBagQolInfo = function(self)
      local scroll = self.modernBagDescriptionScroll or {}
      local header = self.modernBagHeaderBounds or {}
      return {
        money = moneyText(self), headerCash = self.modernBagHeaderCash,
        header = header,
        descriptionOverflow = scroll.overflow and true or false,
        descriptionOffset = tonumber(scroll.offset) or 0,
        descriptionTravel = tonumber(scroll.travel) or 0,
        descriptionElapsed = tonumber(scroll.elapsed) or 0,
        descriptionStaticLines = tonumber(scroll.staticLines) or 0,
        descriptionTail = scroll.tailText,
      }
    end
    menu.modernBagCategoryFor = function(self, id) return categoryFor(self, id) end
    menu.modernBagSort = sortBag
    menu.modernBagOpenSort = openSortMenu
    return menu
  end

  local function pcDescription(self)
    local row = self.rows and self.rows[self.listIndex]
    local def = row and self:def(row.id)
    return def and def.description or nil
  end

  local function drawPcFooter(self, title, lines)
    local G = love.graphics
    local width = self.modernBagWideWidth or 160
    local wide = width >= 196
    local x = wide and math.max(154, math.floor(width * 0.58)) + 2 or 0
    local y = wide and 18 or 112
    local w = width - x
    local h = wide and 126 or 32
    setColor({ 0.04, 0.05, 0.07 })
    G.rectangle("fill", x, y, w, h)
    setColor({ 0.52, 0.88, 0.64 })
    G.rectangle("line", x + 1.5, y + 1.5, w - 3, h - 3)
    if title then drawInk(title, x + 6, y + 5, w - 12,
      { 0.55, 0.95, 0.68 }) end
    local maxLines = wide and math.max(2, math.floor((h - 22) / 10)) or 2
    for i = 1, math.min(maxLines, #(lines or {})) do
      drawInk(tostring(lines[i]):gsub("{PLAYER}", self:playerName()), x + 6,
        y + 6 + i * 10, w - 12, INK_WHITE)
    end
  end

  local function modernItemPcPanel(self)
    if self.phase == "deposit" and self.pack then
      self.pack:drawPanel()
      return
    end
    local G = love.graphics
    local width = self.modernBagWideWidth or 160
    local wide = width >= 196
    local listW = wide and math.max(154, math.floor(width * 0.58)) or width
    setColor({ 0.90, 0.94, 0.91 })
    G.rectangle("fill", 0, 0, width, 144)
    setColor(GREEN)
    G.rectangle("fill", 0, 0, width, 16)
    setColor({ 0.52, 0.88, 0.64 })
    G.rectangle("fill", 0, 14, width, 2)
    drawInk("ITEM PC", 5, 4, 80, INK_WHITE)
    drawInkRight(tostring(self.phase or "menu"):upper(), width - 5, 4, 64,
      INK_WHITE)

    if self.phase == "withdraw" or self.phase == "toss" then
      for visible = 1, 4 do
        local i = visible + (self.scroll or 0)
        local y = 20 + (visible - 1) * 22
        local selected = i == self.listIndex
        setColor(selected and GREEN_DARK
          or (visible % 2 == 0 and PAPER_ALT or PAPER))
        chamfer("fill", 4, y, listW - 8, 19, 2)
        local color = selected and INK_WHITE or INK_BLACK
        local row = self.rows and self.rows[i]
        if row then
          drawInk(row.name, 12, y + 5, listW - 52, color)
          if not self:cantToss(row.id) then
            drawInkRight(TIMES .. tostring(row.count or 0), listW - 10, y + 5, 32,
              color)
          end
        elseif i == self:listTotal() then
          drawInk("CANCEL", 12, y + 5, 100, color)
        end
      end
      local row = self.rows and self.rows[self.listIndex]
      local descLines = wide and splitDescriptionFor(pcDescription(self),
        width - listW - 12) or splitDescription(pcDescription(self))
      drawPcFooter(self, row and row.name, descLines)
    else
      for i, entry in ipairs(self.entries or {}) do
        local y = 19 + (i - 1) * 15
        local selected = i == self.index
        setColor(selected and GREEN_DARK
          or (i % 2 == 0 and PAPER_ALT or PAPER))
        chamfer("fill", 8, y, listW - 16, 13, 2)
        if selected then
          setColor(INK_WHITE)
          G.rectangle("fill", 12, y + 3, 2, 7)
        end
        drawInk(entry.label, 19, y + 3, listW - 33,
          selected and INK_WHITE or INK_BLACK)
      end
      drawPcFooter(self, "PLAYER'S PC", { "Choose an action." })
    end

    if self.qtyState then
      local q = self.qtyState
      drawPcFooter(self, q.prompt and q.prompt[1],
        { q.prompt and q.prompt[2] or "", TIMES .. ("%02d"):format(q.qty or 1) })
    elseif self.confirm then
      drawPcFooter(self, self.confirm.prompt and self.confirm.prompt[1],
        { self.confirm.prompt and self.confirm.prompt[2] or "" })
      local x, y = 104, 62
      setColor({ 0.60, 0.84, 0.68 })
      chamfer("fill", x, y, 52, 44, 3)
      for i, label in ipairs({ "YES", "NO" }) do
        local rowY = y + 5 + (i - 1) * 16
        if i == self.confirm.choice then
          setColor(GREEN_DARK)
          G.rectangle("fill", x + 4, rowY, 44, 14)
        end
        drawInk(label, x + 14, rowY + 3, 30,
          i == self.confirm.choice and INK_WHITE or INK_BLACK)
      end
    elseif self.message then
      local page = self.message.pages and self.message.pages[self.message.page]
      drawPcFooter(self, "ITEM PC", page)
    end
    G.setColor(1, 1, 1, 1)
  end

  local function decorateItemPc(menu)
    if type(menu) ~= "table" or menu.modernBagGeneration == 2 then return menu end
    local nativePanel = menu.drawPanel
    menu.modernPCUI = true
    menu.modernBagGeneration = 2
    menu.classicGen2ItemPcPanel = nativePanel
    menu.drawPanel = modernItemPcPanel
    installWideDraw(menu, menu.drawPanel, { 0.90, 0.94, 0.91 })
    return menu
  end

  install("Gen2PackMenu", PackMenu, decoratePack)
  install("Gen2ItemPcMenu", ItemPcMenu, decorateItemPc)
  mod.exports.skins = shared and shared.skins or {}
  mod.exports.activeSkin = function(game)
    local skins = shared and shared.skins or {}
    local index = shared and shared.skinIndex and shared.skinIndex(game) or 1
    return skins[index] and skins[index].value or "modern"
  end
  mod.exports.generation = 2
  mod.log:info("modern six-view PACK over four native pockets and item PC enabled for Gen 2")
end
