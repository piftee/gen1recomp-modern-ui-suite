return function(mod, settings, state, components)
  local ListMenu = mod.ui and mod.ui.ListMenu
  if not (ListMenu and type(ListMenu.new) == "function") then
    ListMenu = require("src.ui.ListMenu")
  end
  local OptionsMenu = require("src.ui.OptionsMenu")

  local function labelFor(row, component)
    return settings:detailLabel(component, row)
  end

  local function optionValue(component, row)
    local value = settings:get(component, row.key)
    if row.type == "toggle" then return value ~= false and "ON" or "OFF" end
    for _, choice in ipairs(row.choices or {}) do
      if choice[2] == value then return choice[1] end
    end
    return tostring(value or "----")
  end

  local function stepOption(game, component, row, direction)
    if row.type == "toggle" then
      return settings:set(game, component, row.key,
        not settings:get(component, row.key))
    end
    local choices = row.choices or {}
    if #choices == 0 then return false end
    local current, index = settings:get(component, row.key), 1
    for i, choice in ipairs(choices) do
      if choice[2] == current then index = i break end
    end
    index = (index - 1 + (direction or 1)) % #choices + 1
    return settings:set(game, component, row.key, choices[index][2])
  end

  local function originalOptionRow(component, game)
    local hook = state.optionsHooks[component.id]
    if type(hook) ~= "function" then return nil end
    local ok, rows = pcall(hook, function(_, source) return source end, game, {})
    if not ok or type(rows) ~= "table" then return nil end
    for _, row in ipairs(rows) do
      if type(row) == "table" and (row.activate or row.step) then return row end
    end
  end

  local function openOriginalOptions(component, game)
    local row = originalOptionRow(component, game)
    if not row then return false end
    if row.activate then return row.activate(game) end
    if row.step then return row.step(game, 1) end
    return false
  end

  local function openBagCompanions(component, game)
    local stack = game and game.stack
    local before = stack and type(stack.top) == "function" and stack:top() or nil
    local opened = openOriginalOptions(component, game)
    local page = stack and type(stack.top) == "function" and stack:top() or nil
    if opened ~= false and page and page ~= before and type(page.rows) == "table" then
      for index = #page.rows, 1, -1 do
        if page.rows[index].id == "modern_bag_ui_skin" then
          table.remove(page.rows, index)
        end
      end
      page.view = page.rows
      page.index, page.scroll = 1, 0
    end
    return opened
  end

  local openHub
  local function openComponent(game, component)
    local rows = {
      {
        id = component.key .. ".enabled",
        label = component.enabledLabel or "ENABLED",
        value = function()
          return settings:isEnabled(component) and "ON" or "OFF"
        end,
        step = function(activeGame)
          local changed = settings:setEnabled(activeGame, component,
            not settings:isEnabled(component))
          -- Gen 2's native Options page does not write after a custom step.
          -- Persist this independent switch just as hub left/right does.
          settings:persist(activeGame)
          return changed
        end,
      },
    }
    for _, row in ipairs(component.schema or {}) do
      if row.key ~= component.enabledOption then
        local source = row
        rows[#rows + 1] = {
          id = component.key .. "." .. source.key,
          label = labelFor(source, component),
          value = function() return optionValue(component, source) end,
          step = function(activeGame, direction)
            return stepOption(activeGame, component, source, direction)
          end,
        }
      end
    end
    if component.id == "modern_start_menu_ui" then
      rows[#rows + 1] = {
        id = "start_menu.icon_overrides",
        label = "ICON OVERRIDES",
        value = function() return "OPEN" end,
        activate = function(activeGame)
          local exports = component.exports or {}
          local interface = exports.settings
          if interface and interface.openIcons then return interface.openIcons(activeGame) end
          return openOriginalOptions(component, activeGame)
        end,
      }
    elseif component.id == "modern_bag_ui"
        and (mod.find("useful_bag") or mod.find("Kanto-Reforged")) then
      rows[#rows + 1] = {
        id = "bag.companions",
        label = "COMPANION OPTIONS",
        value = function() return "OPEN" end,
        activate = function(activeGame)
          return openBagCompanions(component, activeGame)
        end,
      }
    end
    local page = OptionsMenu.new(game)
    page.rows, page.view = rows, rows
    page.index, page.scroll, page.sub = 1, 0, true
    page.modernUiSuiteComponent = component.id
    game.stack:push(page)
    return true
  end

  openHub = function(game)
    local menu
    local function buildItems()
      local items = {
        { id = "enable_all", label = "ENABLE ALL UI", action = "enable" },
        { id = "disable_all", label = "DISABLE ALL UI", action = "disable" },
      }
      for _, component in ipairs(components) do
        items[#items + 1] = {
          id = component.id,
          label = component.short,
          right = settings:isEnabled(component) and "ON" or "OFF",
          component = component,
        }
      end
      items[#items + 1] = { id = "back", label = "BACK", cancel = true }
      return items
    end
    local function refresh(preferred)
      local old = menu and menu.index or 1
      local items = buildItems()
      if not menu then return items end
      menu.items = items
      local selected
      for index, item in ipairs(items) do
        if preferred and item.id == preferred then selected = index break end
      end
      menu.index = selected or math.max(1, math.min(old, #items))
    end
    menu = ListMenu.new(game, "MODERN UI SUITE", {}, {
      wrap = true,
      keyRepeat = true,
      onChoose = function(item, active)
        if not item then return end
        if item.cancel then
          active:close()
        elseif item.action == "enable" then
          settings:setAll(game, true); settings:persist(game); refresh(item.id)
        elseif item.action == "disable" then
          settings:setAll(game, false); settings:persist(game); refresh(item.id)
        elseif item.component then
          openComponent(game, item.component)
        end
      end,
    })
    refresh()
    local baseUpdate = menu.update
    menu.update = function(self, dt)
      local item = self.items and self.items[self.index]
      local input = self.game and self.game.input
      if item and item.component and input
          and (input:wasPressed("left") or input:wasPressed("right")) then
        settings:setEnabled(self.game, item.component,
          not settings:isEnabled(item.component))
        settings:persist(self.game)
        refresh(item.id)
        return
      end
      return baseUpdate(self, dt)
    end
    menu.screenId = mod.id .. ":settings"
    game.stack:push(menu)
    return true
  end

  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    local out = next(game, rows)
    if type(out) ~= "table" then return out end
    local row = {
      id = "modern_ui_suite_settings",
      label = "MODERN UI SUITE",
      value = function() return "OPEN" end,
      activate = openHub,
      step = openHub,
    }
    if mod.ui and type(mod.ui.insertBefore) == "function" then
      return mod.ui.insertBefore(out, "MODS", row)
    end
    out[#out + 1] = row
    return out
  end)

  return { open = openHub, openComponent = openComponent }
end
