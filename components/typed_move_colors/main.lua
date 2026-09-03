-- Typed Move Colors is deliberately presentation-only. Move definitions,
-- PP, effects, targeting and battle behavior stay owned by the engine; every
-- tint is resolved from the live merged move table so content mods compose.
return function(mod)
  local optionSchema = {
    { key = "battle_colors", label = "BATTLE COLORS", type = "toggle",
      default = true },
    { key = "layout", label = "MOVE LAYOUT", type = "choice",
      default = "wide", choices = {
        { "WIDE", "wide" }, { "GAME", "game" },
      } },
    { key = "effect_hints", label = "MOVE EFFECT", type = "toggle",
      default = true },
    { key = "menu_colors", label = "MENU COLORS", type = "toggle",
      default = true },
    { key = "strength", label = "COLOR STRENGTH", type = "choice",
      default = "bold", choices = {
        { "SOFT", "soft" }, { "BOLD", "bold" },
        { "VIBRANT", "vibrant" },
      } },
    { key = "opacity", label = "BATTLE OPACITY", type = "choice",
      default = "100", choices = {
        { "100%", "100" }, { "85%", "85" },
        { "70%", "70" }, { "55%", "55" },
      } },
    { key = "text_only", label = "TEXT ONLY", type = "toggle",
      default = false },
  }
  mod.options:define(optionSchema)

  local mainLabels = {
    battle_colors = "MOVE BATTLE",
    layout = "MOVE LAYOUT",
    effect_hints = "MOVE EFFECT",
    menu_colors = "MOVE MENUS",
    strength = "MOVE TINT",
    opacity = "CARD OPACITY",
    text_only = "TEXT ONLY",
  }

  local function setOption(game, key, value)
    return mod.options:set(game, key, value)
  end

  local function optionLabel(row)
    if row.type == "toggle" then
      return mod.options:get(row.key) and "ON" or "OFF"
    end
    local current = mod.options:get(row.key)
    for _, choice in ipairs(row.choices or {}) do
      if choice[2] == current then return choice[1] end
    end
    return "----"
  end

  local function stepOption(game, row, direction)
    if row.type == "toggle" then
      setOption(game, row.key, not mod.options:get(row.key))
      return true
    end
    local choices = row.choices or {}
    if #choices == 0 then return false end
    local current, index = mod.options:get(row.key), 1
    for i, choice in ipairs(choices) do
      if choice[2] == current then index = i break end
    end
    index = (index - 1 + (direction or 1)) % #choices + 1
    setOption(game, row.key, choices[index][2])
    return true
  end

  -- Keep the game's main Options screen compact. The regular mod-manager
  -- settings page still reads optionSchema directly, while this native list
  -- gives the main menu one entry instead of seven consecutive rows.
  local SETTINGS_SCREEN = "typed_move_colors:settings"
  local ListMenu = mod.ui and mod.ui.ListMenu
  if not (ListMenu and type(ListMenu.new) == "function") then
    local ok, module = pcall(require, "src.ui.ListMenu")
    if ok and type(module) == "table" then ListMenu = module end
  end

  local function buildSubmenuItems()
    local items = {}
    for _, row in ipairs(optionSchema) do
      items[#items + 1] = {
        id = mod.id .. ":" .. row.key,
        label = mainLabels[row.key] or row.label,
        right = optionLabel(row),
        option = row,
      }
    end
    items[#items + 1] = { id = "cancel", label = "CANCEL", cancel = true }
    return items
  end

  local function newSettingsMenu(game)
    local menu
    local function refresh(preferredId)
      local oldIndex = menu and menu.index or 1
      local items = buildSubmenuItems()
      if not menu then return items end
      menu.items = items
      local found
      if preferredId then
        for i, item in ipairs(items) do
          if item.id == preferredId then found = i break end
        end
      end
      menu.index = found or math.max(1, math.min(oldIndex, #items))
    end
    local function step(item, direction)
      if not (item and item.option) then return end
      if stepOption(game, item.option, direction) then
        -- ListMenu is outside OptionsMenu's automatic save path, so persist
        -- immediately just as the game's normal option rows do after a step.
        if game and game.writeOptions then pcall(game.writeOptions, game) end
        refresh(item.id)
      end
    end
    menu = ListMenu.new(game, "TYPED MOVE COLORS", {}, {
      wrap = true,
      keyRepeat = true,
      onChoose = function(item, activeMenu)
        if item and item.cancel then
          if activeMenu and activeMenu.close then activeMenu:close() end
          return
        end
        step(item, 1)
      end,
    })
    refresh()
    local baseUpdate = menu.update
    menu.update = function(self, dt)
      local item = self.items and self.items[self.index]
      if item and item.option then
        local input = self.game and self.game.input
        if input and input:wasPressed("left") then step(item, -1); return end
        if input and input:wasPressed("right") then step(item, 1); return end
      end
      return baseUpdate(self, dt)
    end
    menu.screenId = menu.screenId or SETTINGS_SCREEN
    return menu
  end

  local screenRegistryReady = ListMenu and mod.content
    and mod.content.screens and mod.content.screens.register
  if screenRegistryReady then
    mod.content.screens:register(SETTINGS_SCREEN, {
      new = function(game) return newSettingsMenu(game) end,
    })
  end

  local function openSettings(game)
    local stack = game and game.stack
    if not (ListMenu and stack and type(stack.push) == "function") then
      return false
    end
    local ok, menu = pcall(newSettingsMenu, game)
    if not ok or not menu then
      mod.log:error("settings submenu failed: %s", tostring(menu))
      return false
    end
    stack:push(menu)
    return true
  end

  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    local out = next(game, rows)
    if type(out) ~= "table" then return out end
    local submenuReady = ListMenu and game and game.stack
      and type(game.stack.push) == "function"
    if submenuReady then
      local openRow = {
        id = "typed_move_colors_settings_open",
        label = "TYPED MOVE COLORS",
        value = function() return "OPEN" end,
        -- Current OptionsMenu uses activate; older builds treated all rows
        -- as steppers. Providing both keeps the single submenu entry on each
        -- API generation without scattering the individual settings again.
        activate = function(g) return openSettings(g) end,
        step = function(g) return openSettings(g) end,
      }
      if mod.ui and type(mod.ui.insertBefore) == "function" then
        return mod.ui.insertBefore(out, "MODS", openRow)
      end
      out[#out + 1] = openRow
      return out
    end

    -- Older engine builds without custom screens retain the former rows so
    -- every setting remains reachable.
    for _, sourceRow in ipairs(optionSchema) do
      local row = sourceRow
      local rendered = {
        id = "typed_move_colors_" .. row.key,
        label = mainLabels[row.key] or row.label,
      }
      rendered.value = function() return optionLabel(row) end
      rendered.step = function(g, direction)
        return stepOption(g, row, direction)
      end
      out[#out + 1] = rendered
    end
    return out
  end)

  local GameVersion = require("src.core.GameVersion")
  if type(GameVersion.generation) == "function"
      and GameVersion.generation() == 2 then
    return mod:load("gen2.lua")(mod)
  end

  local source, readErr = mod:read("ui.lua")
  if not source then
    mod.log:error("ui.lua is missing (%s); reinstall the mod",
      tostring(readErr or "unknown read error"))
    return
  end
  local chunk, compileErr = load(source, "@" .. mod.path .. "/ui.lua")
  if not chunk then
    mod.log:error("ui.lua did not compile: %s", tostring(compileErr))
    return
  end
  local ok, install = pcall(chunk)
  if not ok or type(install) ~= "function" then
    mod.log:error("ui.lua must return an installer: %s", tostring(install))
    return
  end
  local installed, installErr = pcall(install, mod)
  if not installed then
    mod.log:error("typed move UI failed: %s", tostring(installErr))
    return
  end
  mod.log:info("type-coloured battle and menu moves enabled")
end
