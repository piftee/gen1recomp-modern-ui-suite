-- StartMenu remains responsible for building actions and every other mod
-- still contributes through ui.start_menu.items before this mod sees the
-- final controller. New engines expose a dedicated presentation hook; the
-- screen.pushed listener below keeps the same archive working on API 2 mobile
-- builds released before that hook existed.
return function(mod)
  local optionSchema = {
    { key = "theme", label = "START MENU THEME", type = "choice",
      default = "map", choices = {
        { "MAP", "map" }, { "RED", "red" },
        { "BLUE", "blue" }, { "DMG", "dmg" },
      } },
    { key = "position", label = "START MENU POSITION", type = "choice",
      default = "right", choices = {
        { "LEFT", "left" }, { "MID-L", "mid_left" },
        { "CENTER", "center" }, { "MID-R", "mid_right" },
        { "RIGHT", "right" },
      } },
    { key = "clock", label = "START MENU CLOCK", type = "choice",
      default = "play", choices = {
        { "PLAY", "play" }, { "DEVICE", "device" },
      } },
  }
  mod.options:define(optionSchema)

  local optionRows = {}
  for _, row in ipairs(optionSchema) do optionRows[row.key] = row end

  local ICON_CHOICES = {
    { "AUTO", "auto" }, { "DEX", "pokedex" }, { "PKMN", "party" },
    { "BAG", "bag" }, { "ID", "trainer" }, { "SAVE", "save" },
    { "OPT", "options" }, { "GEAR", "pokegear" }, { "LINK", "link" },
    { "MODS", "mods" }, { "QUIT", "quit" }, { "MENU", "generic" },
    { "QUEST", "quest" }, { "MAP", "map" }, { "MUSIC", "music" },
    { "CAMERA", "camera" }, { "TROPHY", "trophy" },
    { "HEART", "heart" }, { "STAR", "star" }, { "TOOLS", "tools" },
    { "KEY", "key" }, { "CLOCK", "clock" }, { "MAIL", "mail" },
    { "CHAT", "chat" }, { "HOME", "home" }, { "SHOP", "shop" },
    { "CHEST", "chest" }, { "BATTLE", "battle" },
    { "POTION", "potion" }, { "BIKE", "bicycle" },
    { "CRAFT", "craft" }, { "SEARCH", "search" },
  }
  local ICON_VALUES = {}
  for _, choice in ipairs(ICON_CHOICES) do ICON_VALUES[choice[2]] = true end
  local customEntries, customEntryOrder = {}, {}
  local presentation

  local function setOption(game, key, value)
    return mod.options:set(game, key, value)
  end

  local function choiceLabel(key)
    local row = optionRows[key]
    local current = mod.options:get(key)
    for _, choice in ipairs(row.choices) do
      if choice[2] == current then return choice[1] end
    end
    return row.choices[1][1]
  end

  local function stepChoice(game, key, direction)
    local choices = optionRows[key].choices
    local current, index = mod.options:get(key), 1
    for i, choice in ipairs(choices) do
      if choice[2] == current then index = i break end
    end
    index = (index - 1 + (direction or 1)) % #choices + 1
    setOption(game, key, choices[index][2])
    return true
  end

  local function themeLabel() return choiceLabel("theme") end
  local function positionLabel() return choiceLabel("position") end
  local function clockLabel() return choiceLabel("clock") end
  local function stepTheme(game, direction)
    return stepChoice(game, "theme", direction)
  end
  local function stepPosition(game, direction)
    return stepChoice(game, "position", direction)
  end
  local function stepClock(game, direction)
    return stepChoice(game, "clock", direction)
  end

  local function iconTable(game, create)
    local icons = mod.options:get("icons")
    if type(icons) ~= "table" and create then
      icons = {}
      mod.options:set(game, "icons", icons)
    end
    return type(icons) == "table" and icons or nil
  end

  local function loaderIconTable(game, create)
    return iconTable(game, create)
  end

  local function iconChoice(game, key)
    local saved = iconTable(game, false)
    local value = saved and saved[key]
    if value == nil then
      local live = loaderIconTable(game, false)
      value = live and live[key]
    end
    return ICON_VALUES[value] and value or "auto"
  end

  local function setIconChoice(game, key, value)
    value = ICON_VALUES[value] and value or "auto"
    local saved, live = iconTable(game, true), loaderIconTable(game, true)
    local stored = value ~= "auto" and value or nil
    if saved then saved[key] = stored end
    if live then live[key] = stored end
    mod.options:set(game, "icons", saved)
  end

  local function stepIcon(game, key, direction)
    local current, index = iconChoice(game, key), 1
    for i, choice in ipairs(ICON_CHOICES) do
      if choice[2] == current then index = i break end
    end
    index = (index - 1 + (direction or 1)) % #ICON_CHOICES + 1
    setIconChoice(game, key, ICON_CHOICES[index][2])
    return true
  end

  local function iconChoiceLabel(game, key)
    local current = iconChoice(game, key)
    for _, choice in ipairs(ICON_CHOICES) do
      if choice[2] == current then return choice[1] end
    end
    return "AUTO"
  end

  local function selectorLabel(label)
    local compact = presentation and presentation.normalizeText
      and presentation.normalizeText(label) or tostring(label or "MENU"):upper()
    if #compact > 10 then compact = compact:sub(1, 9) .. "." end
    return "ICON " .. compact
  end

  local function loadModule(filename, label)
    local source, readErr = mod:read(filename)
    if not source then
      mod.log:error("%s is missing (%s); reinstall the mod", filename,
        tostring(readErr or "unknown read error"))
      return nil
    end
    local chunk, compileErr = load(source, "@" .. mod.path .. "/" .. filename)
    if not chunk then
      mod.log:error("%s did not compile: %s", label, tostring(compileErr))
      return nil
    end
    local ok, value = pcall(chunk)
    if not ok then
      mod.log:error("%s failed to load: %s", label, tostring(value))
      return nil
    end
    return value
  end

  local icons = loadModule("icons.lua", "icon atlas metadata")
  local makePresentation = loadModule("screen.lua", "menu presentation")
  if type(icons) ~= "table" or type(makePresentation) ~= "function" then return end

  local made
  made, presentation = pcall(makePresentation, mod, icons)
  if not made or type(presentation) ~= "table"
      or type(presentation.decorate) ~= "function" then
    mod.log:error("menu presentation factory failed: %s", tostring(presentation))
    return
  end

  local settings
  local makeSettings = loadModule("settings.lua", "settings interface")
  if type(makeSettings) == "function" then
    local ok, value = pcall(makeSettings, mod, presentation, {
      themeLabel = themeLabel,
      stepTheme = stepTheme,
      positionLabel = positionLabel,
      stepPosition = stepPosition,
      clockLabel = clockLabel,
      stepClock = stepClock,
      customEntries = customEntries,
      customEntryOrder = customEntryOrder,
      iconChoices = ICON_CHOICES,
      iconChoice = iconChoice,
      setIconChoice = setIconChoice,
      iconChoiceLabel = iconChoiceLabel,
    })
    if ok and type(value) == "table" then
      settings = value
    else
      mod.log:error("settings interface failed: %s", tostring(value))
    end
  end

  -- Keep the game's main Options screen tidy: every preference owned by this
  -- mod now lives behind one row. API 2 builds without custom list screens
  -- retain the older flat controls so theme and overrides remain reachable.
  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    local out = next(game, rows)
    if type(out) ~= "table" then return out end
    if settings and settings.available and game and game.stack
        and type(game.stack.push) == "function" then
      local openRow = {
        id = "modern_start_menu_ui_settings_open",
        label = "MODERN START MENU",
        value = function() return "OPEN" end,
        activate = function(g) return settings.open(g) end,
        step = function(g) return settings.open(g) end,
      }
      if mod.ui and type(mod.ui.insertBefore) == "function" then
        return mod.ui.insertBefore(out, "MODS", openRow)
      end
      out[#out + 1] = openRow
      return out
    end

    out[#out + 1] = {
      id = "modern_start_menu_ui_theme",
      label = "PHONE THEME",
      value = themeLabel,
      step = stepTheme,
    }
    out[#out + 1] = {
      id = "modern_start_menu_ui_position",
      label = "POSITION",
      value = positionLabel,
      step = stepPosition,
    }
    out[#out + 1] = {
      id = "modern_start_menu_ui_clock",
      label = "CLOCK",
      value = clockLabel,
      step = stepClock,
    }
    for index, key in ipairs(customEntryOrder) do
      local entry = customEntries[key]
      out[#out + 1] = {
        id = "modern_start_menu_ui_icon_" .. index,
        label = selectorLabel(entry.label),
        value = function(g) return iconChoiceLabel(g, key) end,
        step = function(g, direction) return stepIcon(g, key, direction) end,
      }
    end
    return out
  end)


  -- screen.lua asks this callback at draw time, so choosing from the visual
  -- picker updates the phone immediately without reopening START.
  mod.startMenuIconOverrideFor = function(item, game)
    local key = presentation.entryKeyFor(item)
    local value = iconChoice(game, key)
    return value ~= "auto" and value or nil
  end

  local function rememberCustomEntries(menu, game)
    for _, item in ipairs(menu.items or {}) do
      if presentation.isCustomItem(item, game) then
        local key = presentation.entryKeyFor(item)
        if not customEntries[key] then
          customEntries[key] = {
            label = tostring(item.label or item.shortLabel or item.id or "MENU"),
          }
          customEntryOrder[#customEntryOrder + 1] = key
        end
      end
    end
  end

  local function decorate(menu, game, source)
    if type(menu) ~= "table" or menu.modernStartMenuUI then return menu end
    if type(menu.items) ~= "table" or type(menu.update) ~= "function"
        or type(menu.draw) ~= "function" then
      mod.log:warn("%s found an incompatible StartMenu controller; keeping it unchanged",
        source)
      return menu
    end
    local ok, decorated = pcall(presentation.decorate, menu, game or menu.game)
    if not ok then
      mod.log:error("could not decorate START menu through %s: %s",
        source, tostring(decorated))
      return menu
    end
    rememberCustomEntries(menu, game or menu.game)
    return type(decorated) == "table" and decorated or menu
  end

  mod.hooks:wrap("ui.start_menu.presentation",
    function(next, game, menu)
      local downstream = next(game, menu)
      if type(downstream) ~= "table" then return downstream end
      return decorate(downstream, game, "presentation hook")
    end, 1000)

  -- API 2 shipped screen lifecycle events before it shipped the dedicated
  -- ui.start_menu.presentation seam. Screens.push stamps screenId before
  -- screen.pushed fires, so this fallback receives the finished controller,
  -- including rows contributed by third-party mods. Decoration is in-place
  -- and idempotent, making this a no-op on engines that already ran the hook.
  mod.events:on("screen.pushed", function(event)
    local menu = type(event) == "table" and event.state or nil
    if type(menu) ~= "table"
        or (menu.screenId ~= "StartMenu"
          and menu.screenId ~= "Gen2StartMenu")
        or menu.modernStartMenuUI then return end
    decorate(menu, menu.game, "screen.pushed compatibility fallback")
  end, -1000)

  -- Keep the native 160x144 stack stable so opening START cannot recalculate
  -- the map, screen-position mode or Save overlays. On a genuinely wide
  -- display, re-present only the phone in the final window-space HUD pass;
  -- this gives Gen 1 and Gen 2 configurable horizontal placement without
  -- resizing or anchoring the underlying game surface.
  mod.hooks:wrap("render.hud", function(next, game, viewport)
    local result = next(game, viewport)
    local stack = game and game.stack
    local menu = stack and stack.top and stack:top() or nil
    if not (type(menu) == "table" and menu.modernStartMenuUI
        and type(viewport) == "table") then
      return result
    end
    local requestedWidth = presentation.responsiveSize
      and select(1, presentation.responsiveSize(menu)) or 160
    if requestedWidth <= 160 then return result end
    local winW = tonumber(viewport.width) or love.graphics.getWidth()
    local winH = tonumber(viewport.height) or love.graphics.getHeight()
    local pixelScale = math.max(1, tonumber(viewport.scale) or 1)
    local scaleX = pixelScale / math.max(1e-6, tonumber(viewport.dpiX) or 1)
    local scaleY = pixelScale / math.max(1e-6, tonumber(viewport.dpiY) or 1)
    local width = math.max(160, math.min(requestedWidth,
      math.floor(winW / scaleX)))
    menu.modernStartLastWideWidth = width
    if width <= 160 then return result end
    local ox = math.floor((winW - width * scaleX) / 2)
    local oy = math.floor((winH - 144 * scaleY) / 2)
    love.graphics.push("all")
    love.graphics.translate(ox, oy)
    love.graphics.scale(scaleX, scaleY)
    menu.modernStartHudPass = true
    if presentation.applyHudPalette then
      local shader = presentation.applyHudPalette(menu)
      if shader then love.graphics.setShader(shader) end
    end
    presentation.draw(menu)
    menu.modernStartHudPass = nil
    love.graphics.pop()
    return result
  end, 1000)

  mod.exports.presentation = presentation
  mod.exports.decorate = decorate
  mod.exports.iconChoiceFor = iconChoice
  mod.exports.customIconEntries = customEntries
  mod.exports.settings = settings
  mod.exports.iconChoices = ICON_CHOICES
  mod.log:info("phone-panel START menu enabled (mobile compatibility active)")
end
