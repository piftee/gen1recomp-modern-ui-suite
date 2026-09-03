-- One compact home for Modern Start Menu UI preferences. Unknown START-menu
-- entries are discovered lazily by main.lua, then exposed here as visual icon
-- pickers instead of being scattered through the game's main Options list.
return function(mod, presentation, config)
  local Font = require("src.render.Font")
  local Sound = require("src.core.Sound")
  local paletteOK, PaletteFX = pcall(require, "src.render.PaletteFX")
  if not paletteOK then PaletteFX = nil end

  local ListMenu = mod.ui and mod.ui.ListMenu
  if not (ListMenu and type(ListMenu.new) == "function") then
    local ok, module = pcall(require, "src.ui.ListMenu")
    if ok and type(module) == "table" then ListMenu = module end
  end

  local Settings = {
    available = ListMenu ~= nil,
    choices = config.iconChoices,
  }
  local SCREEN_W, SCREEN_H = 160, 144
  local COLUMNS, PAGE_SIZE = 4, 16
  local GRID_X, GRID_Y, CELL_W, CELL_H = 4, 18, 36, 23
  local COL_STEP, ROW_STEP = 38, 24

  local function beep(game)
    if game and game.data then
      pcall(Sound.play, game.data, "Press_AB")
    end
  end

  local function closeState(state)
    local stack = state and state.game and state.game.stack
    if not (stack and type(stack.pop) == "function") then return end
    local top = type(stack.top) == "function" and stack:top() or nil
    if top == nil or top == state then stack:pop() end
  end

  local function fitText(text, width)
    text = tostring(text or "")
    if Font.width(text) <= width then return text end
    while #text > 1 and Font.width(text .. ".") > width do
      text = text:sub(1, -2)
    end
    return text .. "."
  end

  local function centerText(text, y, width, x)
    text, x, width = tostring(text or ""), x or 0, width or SCREEN_W
    Font.draw(text, math.floor(x + (width - Font.width(text)) / 2), y)
  end

  local function compactLabel(label)
    local text = presentation.normalizeText(label or "MENU")
    text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if #text > 12 then text = text:sub(1, 11) .. "." end
    return text ~= "" and text or "MENU"
  end

  local function palette(state, game)
    if PaletteFX and game and game.data then
      return PaletteFX.wholeNamed(game.data, "MEWMON")
    end
  end

  function Settings.newPicker(game, key, entry, onChanged)
    local picker = {
      game = game,
      key = key,
      entry = entry,
      index = 1,
      isOpaque = true,
      screenId = mod.id .. ":icon_picker",
      choices = config.iconChoices,
    }
    for index, choice in ipairs(picker.choices) do
      if choice[2] == config.iconChoice(game, key) then
        picker.index = index
        break
      end
    end

    function picker:uiSize() return SCREEN_W, SCREEN_H end
    picker.sgbPalettes = palette

    local function move(delta)
      local count = #picker.choices
      picker.index = ((picker.index - 1 + delta) % count) + 1
    end

    function picker:update()
      local input = self.game and self.game.input
      if not input then return end
      if input:wasPressed("left") then move(-1)
      elseif input:wasPressed("right") then move(1)
      elseif input:wasPressed("up") then move(-COLUMNS)
      elseif input:wasPressed("down") then move(COLUMNS)
      elseif input:wasPressed("b") then
        beep(self.game)
        closeState(self)
      elseif input:wasPressed("a") then
        beep(self.game)
        local choice = self.choices[self.index]
        config.setIconChoice(self.game, self.key, choice[2])
        if self.game and self.game.writeOptions then
          pcall(self.game.writeOptions, self.game)
        end
        closeState(self)
        if onChanged then onChanged() end
      end
    end

    function picker:draw()
      love.graphics.push("all")
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", 0, 0, SCREEN_W, SCREEN_H)
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw("CHOOSE ICON", 8, 4)
      local page = math.floor((self.index - 1) / PAGE_SIZE) + 1
      local pages = math.max(1, math.ceil(#self.choices / PAGE_SIZE))
      local pageText = ("%d/%d"):format(page, pages)
      Font.draw(pageText, SCREEN_W - 8 - Font.width(pageText), 4)
      love.graphics.rectangle("fill", 4, 15, 152, 1)

      local first = (page - 1) * PAGE_SIZE + 1
      for slot = 1, PAGE_SIZE do
        local choiceIndex = first + slot - 1
        local choice = self.choices[choiceIndex]
        if not choice then break end
        local col = (slot - 1) % COLUMNS
        local row = math.floor((slot - 1) / COLUMNS)
        local x, y = GRID_X + col * COL_STEP, GRID_Y + row * ROW_STEP
        local selected = choiceIndex == self.index
        love.graphics.setColor(selected and 0 or 0.72,
          selected and 0 or 0.72, selected and 0 or 0.72, 1)
        love.graphics.rectangle("fill", x, y, CELL_W, CELL_H)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", x + 2, y + 2, CELL_W - 4,
          CELL_H - 4)
        presentation.drawIcon(choice[2], x + 10, y + 3)
      end

      love.graphics.setColor(0, 0, 0, 1)
      love.graphics.rectangle("fill", 4, 115, 152, 1)
      local selected = self.choices[self.index]
      centerText(selected and selected[1] or "AUTO", 119)
      local entryLabel = fitText(compactLabel(self.entry.label), 144)
      centerText(entryLabel, 132)
      love.graphics.pop()
    end
    return picker
  end

  local function buildItems(game, iconsOnly)
    local items = {}
    if not iconsOnly then
      items = {
        {
        id = mod.id .. ":theme",
        label = "PHONE THEME",
        right = config.themeLabel(),
        kind = "theme",
        },
        {
        id = mod.id .. ":position",
        label = "POSITION",
        right = config.positionLabel(),
        kind = "position",
        },
        {
        id = mod.id .. ":clock",
        label = "CLOCK",
        right = config.clockLabel(),
        kind = "clock",
        },
      }
    end
    for _, key in ipairs(config.customEntryOrder) do
      local entry = config.customEntries[key]
      if entry then
        items[#items + 1] = {
          id = mod.id .. ":icon:" .. key,
          label = compactLabel(entry.label),
          right = config.iconChoiceLabel(game, key),
          kind = "icon",
          key = key,
          entry = entry,
        }
      end
    end
    if #items == (iconsOnly and 0 or 3) then
      items[#items + 1] = {
        id = mod.id .. ":none",
        label = "NO MOD ENTRIES",
        right = "----",
        kind = "empty",
      }
    end
    items[#items + 1] = { id = mod.id .. ":back", label = "BACK", cancel = true }
    return items
  end

  function Settings.newMenu(game, iconsOnly)
    if not ListMenu then return nil end
    local menu
    local function refresh(preferredId)
      local oldIndex = menu and menu.index or 1
      local items = buildItems(game, iconsOnly)
      if not menu then return items end
      menu.items = items
      local found
      for index, item in ipairs(items) do
        if preferredId and item.id == preferredId then found = index break end
      end
      menu.index = found or math.max(1, math.min(oldIndex, #items))
      menu.scroll = math.max(0, math.min(menu.scroll or 0,
        math.max(0, #items - (menu.rows or 7))))
    end

    local function persist()
      if game and game.writeOptions then pcall(game.writeOptions, game) end
    end

    local function choose(item, activeMenu)
      if not item then return end
      if item.cancel then
        if activeMenu and activeMenu.close then activeMenu:close() end
      elseif item.kind == "theme" then
        config.stepTheme(game, 1)
        persist()
        refresh(item.id)
      elseif item.kind == "position" then
        config.stepPosition(game, 1)
        persist()
        refresh(item.id)
      elseif item.kind == "clock" then
        config.stepClock(game, 1)
        persist()
        refresh(item.id)
      elseif item.kind == "icon" then
        local picker = Settings.newPicker(game, item.key, item.entry,
          function() refresh(item.id) end)
        game.stack:push(picker)
      end
    end

    menu = ListMenu.new(game,
      iconsOnly and "START MENU ICONS" or "MODERN START MENU", {}, {
      wrap = true,
      keyRepeat = true,
      onChoose = choose,
    })
    refresh()
    local baseUpdate = menu.update
    menu.update = function(self, dt)
      local item = self.items and self.items[self.index]
      local input = self.game and self.game.input
      if item and (item.kind == "theme" or item.kind == "position"
          or item.kind == "clock") and input then
        local step = item.kind == "theme" and config.stepTheme
          or item.kind == "position" and config.stepPosition
          or config.stepClock
        if input:wasPressed("left") then
          step(self.game, -1); persist(); refresh(item.id); return
        elseif input:wasPressed("right") then
          step(self.game, 1); persist(); refresh(item.id); return
        end
      end
      return baseUpdate(self, dt)
    end
    menu.screenId = mod.id .. ":settings"
    menu.modernStartRefresh = refresh
    return menu
  end

  function Settings.open(game)
    local stack = game and game.stack
    if not (ListMenu and stack and type(stack.push) == "function") then
      return false
    end
    local ok, menu = pcall(Settings.newMenu, game)
    if not ok or not menu then
      mod.log:error("settings submenu failed: %s", tostring(menu))
      return false
    end
    stack:push(menu)
    return true
  end

  function Settings.openIcons(game)
    local stack = game and game.stack
    if not (ListMenu and stack and type(stack.push) == "function") then
      return false
    end
    local ok, menu = pcall(Settings.newMenu, game, true)
    if not ok or not menu then
      mod.log:error("icon settings submenu failed: %s", tostring(menu))
      return false
    end
    stack:push(menu)
    return true
  end

  return Settings
end
