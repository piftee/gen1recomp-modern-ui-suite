return function(parent, components)
  local Settings = {
    parent = parent,
    components = components,
    byId = {},
    schemas = {},
    activeGame = nil,
  }

  for _, component in ipairs(components) do
    Settings.byId[component.id] = component
  end

  -- The manager renders schemas through the same 160x144 four-row option
  -- boxes as the in-game menu.  Prefixing every imported label verbatim made
  -- otherwise useful names such as "MOVE COLORS BATTLE OPACITY" run through
  -- the right border.  Keep component pages concise (their title already
  -- supplies the context), and use short, unambiguous labels in the flat
  -- manager schema.
  local MANAGER_PREFIX = {
    start_menu = "START",
    party = "PARTY",
    bag = "BAG",
    pc = "PC",
    pokedex = "DEX",
    battle_hud = "HUD",
    move_colors = "MOVE",
  }
  local MANAGER_DETAIL = {
    start_menu = {
      theme = "COLOUR", position = "POSITION", clock = "CLOCK",
    },
    party = {
      card_color = "CARD COLOR", animate_icons = "ANIMATION",
      sprite_source = "ICONS", hp_text = "HP DISPLAY", exp_text = "EXP",
      exp_strip = "EXP STRIP", empty_slots = "EMPTY", pattern = "BACKDROP",
      responsive = "WIDE", rename_style = "RENAME",
    },
    bag = { skin = "SKIN" },
    pc = { box_exclusive = "BOX ONLY" },
    pokedex = {
      responsive = "WIDE", pattern = "BACKDROP", theme = "COLOURS",
    },
    move_colors = {
      battle_colors = "BATTLE", layout = "LAYOUT", effect_hints = "EFFECT",
      menu_colors = "MENUS", strength = "TINT", opacity = "OPACITY",
      text_only = "TEXT ONLY",
      text_position = "TEXT ALIGN", box_color = "BOX COLOR", info_position = "INFO SIDE",
    },
  }

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, item in pairs(value) do out[copy(key, seen)] = copy(item, seen) end
    return out
  end

  local function componentFor(self, component)
    if type(component) == "table" then return component end
    return assert(self.byId[component], "unknown suite component: " .. tostring(component))
  end

  function Settings:keyFor(component, key)
    component = componentFor(self, component)
    if key == "__enabled" or key == component.enabledOption then
      return component.key .. ".enabled"
    end
    return component.key .. "." .. key
  end

  function Settings:registerSchema(component, schema)
    component = componentFor(self, component)
    self.schemas[component.id] = schema or {}
    component.schema = schema or {}
    component.defaults = component.defaults or {}
    for _, row in ipairs(schema or {}) do
      if type(row) == "table" and type(row.key) == "string" then
        component.defaults[row.key] = row.default
      end
    end
    return schema
  end

  function Settings:detailLabel(component, row)
    component = componentFor(self, component)
    local label = tostring(row.label or row.key or component.name)
    -- These prefixes are useful when the standalone mod owns the page, but
    -- duplicate the suite component title in this nested page.
    label = label:gsub("^START MENU ", ""):gsub("^POKEDEX ", "")
    return label
  end

  function Settings:managerLabel(component, row)
    component = componentFor(self, component)
    local prefix = MANAGER_PREFIX[component.key] or component.short
    if not row then return component.managerEnabledLabel or (prefix .. " ENABLED") end
    local details = MANAGER_DETAIL[component.key] or {}
    local detail = details[row.key] or self:detailLabel(component, row)
    -- Do not repeat a component prefix already present in a fallback label.
    if detail:sub(1, #prefix + 1) == prefix .. " " then return detail end
    return prefix .. " " .. detail
  end

  function Settings:get(component, key)
    component = componentFor(self, component)
    local fullKey = self:keyFor(component, key)
    local value = self.parent.options:get(fullKey)
    if value ~= nil then return value end
    if key == "__enabled" or key == component.enabledOption then
      return component.defaultEnabled ~= false
    end
    return component.defaults and component.defaults[key] or nil
  end

  function Settings:isEnabled(component)
    return self:get(component, "__enabled") ~= false
  end

  local function optionTables(game, suiteId, create)
    local saved = game and game.save and game.save.options
    local live = game and game.mods
    local savedBucket, liveBucket
    if saved then
      if create then
        saved.modOptions = saved.modOptions or {}
        saved.modOptions[suiteId] = saved.modOptions[suiteId] or {}
      end
      savedBucket = saved.modOptions and saved.modOptions[suiteId]
    end
    if live then
      if create then
        live.modOptions = live.modOptions or {}
        live.modOptions[suiteId] = live.modOptions[suiteId] or {}
      end
      liveBucket = live.modOptions and live.modOptions[suiteId]
    end
    return savedBucket, liveBucket
  end

  function Settings:set(game, component, key, value, quiet)
    component = componentFor(self, component)
    game = game or self.activeGame
    assert(game, "Modern UI Suite settings need the live game")
    local fullKey = self:keyFor(component, key)
    local saved, live = optionTables(game, self.parent.id, true)
    -- Structured preferences (currently Start Menu icon overrides) must not
    -- make the persisted save table and the live loader table aliases.
    if saved then saved[fullKey] = copy(value) end
    if live then live[fullKey] = copy(value) end
    if not quiet and game.mods and game.mods.events then
      game.mods.events:emit("mod.options_changed", {
        mod = self.parent.id, key = fullKey, value = value,
        component = component.id,
      })
      -- Existing integrations that only observe the old event identity keep
      -- receiving a notification even though the suite bucket is canonical.
      game.mods.events:emit("mod.options_changed", {
        mod = component.id,
        key = key == "__enabled" and "enabled" or key,
        value = value,
        suite = self.parent.id,
      })
    end
    return true
  end

  function Settings:setEnabled(game, component, value, quiet)
    return self:set(game, component, "__enabled", value ~= false, quiet)
  end

  function Settings:setAll(game, value)
    for _, component in ipairs(self.components) do
      -- Bulk UI actions must not opt a player into gameplay changes or
      -- disable an independently selected QoL option with the renderers.
      if component.bulkUI ~= false then self:setEnabled(game, component, value, false) end
    end
    return true
  end

  function Settings:persist(game)
    game = game or self.activeGame
    if game and type(game.writeOptions) == "function" then
      return pcall(game.writeOptions, game)
    end
    return false
  end

  function Settings:migrate(game)
    if type(game) ~= "table" then return false end
    self.activeGame = game
    local saved, live = optionTables(game, self.parent.id, true)
    if not saved and not live then return false end
    local changed = false

    local function targetMissing(fullKey)
      return (not saved or saved[fullKey] == nil)
        and (not live or live[fullKey] == nil)
    end

    local legacyTables = game.save and game.save.options
      and game.save.options.modOptions or {}
    local loaderTables = game.mods and game.mods.modOptions or {}
    for _, component in ipairs(self.components) do
      local legacySaved = legacyTables[component.id] or {}
      local legacyLive = loaderTables[component.id] or {}
      for _, row in ipairs(component.schema or {}) do
        if row.key ~= component.enabledOption then
          local fullKey = self:keyFor(component, row.key)
          if targetMissing(fullKey) then
            local value = legacyLive[row.key]
            if value == nil then value = legacySaved[row.key] end
            if value ~= nil then
              value = copy(value)
              if saved then saved[fullKey] = value end
              if live then live[fullKey] = copy(value) end
              changed = true
            end
          end
        end
      end
      if component.enabledOption then
        local fullKey = self:keyFor(component, "__enabled")
        if targetMissing(fullKey) then
          local value = legacyLive[component.enabledOption]
          if value == nil then value = legacySaved[component.enabledOption] end
          if value ~= nil then
            if saved then saved[fullKey] = value ~= false end
            if live then live[fullKey] = value ~= false end
            changed = true
          end
        end
      end
      for _, key in ipairs(component.legacyExtras or {}) do
        local fullKey = self:keyFor(component, key)
        if targetMissing(fullKey) then
          local value = legacyLive[key]
          if value == nil then value = legacySaved[key] end
          if value ~= nil then
            value = copy(value)
            if saved then saved[fullKey] = value end
            if live then live[fullKey] = copy(value) end
            changed = true
          end
        end
      end
    end
    if saved then saved._migration_version = 1 end
    if live then live._migration_version = 1 end
    if changed then self:persist(game) end
    return changed
  end

  function Settings:aggregateSchema()
    local schema = {}
    for _, component in ipairs(self.components) do
      schema[#schema + 1] = {
        key = self:keyFor(component, "__enabled"),
        label = self:managerLabel(component),
        type = "toggle",
        default = component.defaultEnabled ~= false,
      }
    end
    for _, component in ipairs(self.components) do
      for _, source in ipairs(component.schema or {}) do
        if source.key ~= component.enabledOption then
          local row = copy(source)
          row.key = self:keyFor(component, source.key)
          row.label = self:managerLabel(component, source)
          schema[#schema + 1] = row
        end
      end
    end
    return schema
  end

  return Settings
end
