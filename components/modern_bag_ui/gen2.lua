-- Gen 2 owns a four-pocket PACK and a separate item PC. This adapter keeps
-- both native controllers and replaces only their presentation.
return function(mod, shared)
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
        return decorate(menu, game)
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
    drawInk(text, math.floor(right) - width, y, width, color)
    return width
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

  local POCKET_LABEL = {
    ITEM = "ITEM", BALL = "BALL", KEY_ITEM = "KEY", TM_HM = "TM",
  }

  local SUBMENU_LABEL = {
    use = "USE", give = "GIVE", toss = "TOSS", sel = "SEL", quit = "QUIT",
  }

  local function drawPackOverlay(self)
    local G = love.graphics
    local width = self.modernBagWideWidth or 160
    local listW = width >= 196 and math.max(156, math.floor(width * 0.62))
      or 160
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

  local function modernPackPanel(self)
    local G = love.graphics
    local width = self.modernBagWideWidth or 160
    local wide = width >= 196
    local listW = wide and math.max(156, math.floor(width * 0.62)) or width
    local detailX = listW + (wide and 2 or 0)
    local detailW = width - detailX
    setColor({ 0.90, 0.93, 0.96 })
    G.rectangle("fill", 0, 0, width, 144)

    setColor(BLUE)
    G.rectangle("fill", 0, 0, width, 16)
    setColor(BLUE_LIGHT)
    G.rectangle("fill", 0, 14, width, 2)
    drawInk("PACK", 5, 4, 72, INK_WHITE)
    drawInkRight(("%02d ITEMS"):format(#(self.rows or {})), width - 5, 4, 72,
      INK_WHITE)

    local pockets = PackMenu.POCKETS or {}
    local tabW = math.floor(listW / math.max(1, #pockets))
    for i, pocket in ipairs(pockets) do
      local x = (i - 1) * tabW
      local selected = i == self.pocketIndex
      setColor(selected and BLUE_DARK or PAPER)
      G.rectangle("fill", x + 1, 17, tabW - 2, 14)
      setColor(selected and BLUE_LIGHT or PAPER_ALT)
      G.rectangle("line", x + 1.5, 17.5, tabW - 3, 13)
      local label = POCKET_LABEL[pocket.id] or pocket.label or pocket.id
      local fitted = fitText(label, tabW - 6)
      drawInk(fitted, x + math.floor((tabW - Font.width(fitted)) / 2), 20,
        tabW - 6, selected and INK_WHITE or INK_BLACK)
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
    if wide then
      footerX, footerY, footerW, footerH = detailX, 32, detailW, 112
    end
    G.rectangle("fill", footerX, footerY, footerW, footerH)
    setColor(BLUE_LIGHT)
    G.rectangle("line", footerX + 1.5, footerY + 1.5,
      footerW - 3, footerH - 3)
    local current = self.rows and self.rows[self.index]
    local lines = self.message or (self.confirm and self.confirm.prompt)
    if current and not lines then
      drawInk(current.name or current.id, footerX + 6, footerY + 5,
        footerW - 12, INK_LIGHT)
      lines = wide and splitDescriptionFor(self:description(), footerW - 12)
        or splitDescription(self:description())
    end
    local maxLines = wide and math.max(2, math.floor((footerH - 22) / 10)) or 2
    for i = 1, math.min(maxLines, #(lines or {})) do
      drawInk(tostring(lines[i]):gsub("{PLAYER}", self:playerName()),
        footerX + 6, footerY + 6 + i * 10, footerW - 12, INK_WHITE)
    end
    drawPackOverlay(self)
    G.setColor(1, 1, 1, 1)
  end

  local function decoratePack(menu, game)
    if type(menu) ~= "table" or menu.modernBagGeneration == 2 then return menu end
    local nativePanel = menu.drawPanel
    menu.modernBagUI = true
    menu.modernBagGeneration = 2
    menu.classicGen2PackPanel = nativePanel
    menu.drawPanel = function(self)
      if option(self.game or game, "skin", "modern") == "classic_pocket" then
        local width = tonumber(self.modernBagWideWidth) or 160
        if width <= 160 then return nativePanel(self) end
        love.graphics.push()
        love.graphics.translate(math.floor((width - 160) / 2), 0)
        local ok, result = pcall(nativePanel, self)
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
      return { generation = 2, pockets = 4,
        skin = option(self.game or game, "skin", "modern") }
    end
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
  mod.log:info("modern four-pocket PACK and item PC enabled for Gen 2")
end
