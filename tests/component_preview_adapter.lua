-- Run one of the seven standalone visual drivers against the embedded copy in
-- Modern UI Suite.  The drivers are intentionally reused: they already cover
-- the mature screen-state matrices, while these aliases make every option
-- write and export lookup hit the suite's canonical namespace.
--
--   SUITE_COMPONENT_DRIVER=mods/modern_party_ui/tests/preview_driver.lua \
--   POKEPORT_DRIVER=mods/modern_ui_suite/tests/component_preview_adapter.lua \
--   POKEPORT_IDENTITY=modern-ui-suite-qa-20260903 POKEPORT_VERSION=red love .
return function(game)
  local driverPath = assert(os.getenv("SUITE_COMPONENT_DRIVER"),
    "SUITE_COMPONENT_DRIVER must name a component preview driver")
  local suite = game.mods and game.mods.exports
    and game.mods.exports.modern_ui_suite
  assert(type(suite) == "table", "Modern UI Suite is not loaded")

  local prefixes = {
    modern_start_menu_ui = "start_menu",
    modern_party_ui = "party",
    modern_bag_ui = "bag",
    modern_pc_ui = "pc",
    modern_pokedex_ui = "pokedex",
    battle_info_hud = "battle_hud",
    typed_move_colors = "move_colors",
  }

  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.mods.modOptions = game.mods.modOptions or {}
  game.mods.modOptions.modern_ui_suite =
    game.mods.modOptions.modern_ui_suite or {}
  game.save.options.modOptions.modern_ui_suite =
    game.save.options.modOptions.modern_ui_suite or {}

  -- A visual matrix can override one or more canonical suite settings without
  -- needing a dedicated driver for every presentation choice. Example:
  --   SUITE_PREVIEW_OPTIONS='party.card_color=mono,party.pattern=plain'
  local previewOptions = os.getenv("SUITE_PREVIEW_OPTIONS")
  for assignment in tostring(previewOptions or ""):gmatch("[^,]+") do
    local key, raw = assignment:match("^%s*([^=]+)%s*=%s*(.-)%s*$")
    assert(key and raw ~= "", "invalid SUITE_PREVIEW_OPTIONS assignment")
    local value = raw
    if raw == "true" then value = true
    elseif raw == "false" then value = false
    end
    game.mods.modOptions.modern_ui_suite[key] = value
    game.save.options.modOptions.modern_ui_suite[key] = value
  end

  local function proxy(bucket, prefix)
    return setmetatable({}, {
      __index = function(_, key) return bucket[prefix .. "." .. key] end,
      __newindex = function(_, key, value) bucket[prefix .. "." .. key] = value end,
      __pairs = function()
        local out = {}
        local stem = prefix .. "."
        for key, value in pairs(bucket) do
          if key:sub(1, #stem) == stem then out[key:sub(#stem + 1)] = value end
        end
        return next, out, nil
      end,
    })
  end

  for id, prefix in pairs(prefixes) do
    local component = suite.components and suite.components[id]
    assert(type(component) == "table", id .. " is missing from the suite")
    game.mods.exports[id] = component.exports
    game.mods.modOptions[id] = proxy(
      game.mods.modOptions.modern_ui_suite, prefix)
    game.save.options.modOptions[id] = proxy(
      game.save.options.modOptions.modern_ui_suite, prefix)
  end

  -- The standalone drivers also inspect their old one-row Options entry.
  -- Supply test-only aliases that open the suite-backed settings, so those
  -- mature visual flows keep reaching their options screens without changing
  -- the production rule that the suite owns exactly one root entry.
  local Runtime = require("src.mods.Runtime")
  local OptionsMenu = require("src.ui.OptionsMenu")
  local schema = game.mods.optionSchemas
    and game.mods.optionSchemas.modern_ui_suite or {}

  local function optionLabel(source, value)
    if source.type == "toggle" then return value ~= false and "ON" or "OFF" end
    for _, choice in ipairs(source.choices or {}) do
      if choice[2] == value then return choice[1] end
    end
    return "----"
  end

  local function openLegacyPage(activeGame, prefix, idPrefix)
    local rows = {}
    for _, source in ipairs(schema) do
      local key = source.key:match("^" .. prefix .. "%.(.+)$")
      if key and key ~= "enabled" then
        local suiteKey = source.key
        rows[#rows + 1] = {
          id = idPrefix .. key,
          label = tostring(source.label or key),
          value = function()
            local value = activeGame.mods.modOptions.modern_ui_suite[suiteKey]
            if value == nil then value = source.default end
            return optionLabel(source, value)
          end,
          step = function(_, direction)
            local live = activeGame.mods.modOptions.modern_ui_suite
            local saved = activeGame.save.options.modOptions.modern_ui_suite
            local value = live[suiteKey]
            if value == nil then value = source.default end
            if source.type == "toggle" then
              value = not value
            else
              local choices, index = source.choices or {}, 1
              for i, choice in ipairs(choices) do
                if choice[2] == value then index = i break end
              end
              index = (index - 1 + (direction or 1)) % #choices + 1
              value = choices[index][2]
            end
            live[suiteKey], saved[suiteKey] = value, value
            return true
          end,
        }
      end
    end
    local page = OptionsMenu.new(activeGame)
    page.rows, page.view = rows, rows
    page.index, page.scroll, page.sub = 1, 0, true
    activeGame.stack:push(page)
    return true
  end

  Runtime.hooks:wrap("ui.options.rows", function(next, activeGame, rows)
    local out = next(activeGame, rows)
    local startSettings = suite.components.modern_start_menu_ui.exports.settings
    out[#out + 1] = {
      id = "modern_start_menu_ui_settings_open",
      label = "MODERN START MENU",
      value = function() return "OPEN" end,
      activate = function(g) return startSettings.open(g) end,
    }
    out[#out + 1] = {
      id = "modern_party_ui", label = "MODERN PARTY",
      value = function() return "OPEN" end,
      activate = function(g)
        return openLegacyPage(g, "party", "modern_party_ui_")
      end,
    }
    out[#out + 1] = {
      id = "modern_bag_ui_options", label = "MODERN BAG",
      value = function() return "OPEN" end,
      activate = function(g)
        return openLegacyPage(g, "bag", "modern_bag_ui_")
      end,
    }
    out[#out + 1] = {
      id = "modern_pokedex_ui", label = "MODERN POKEDEX",
      value = function() return "OPEN" end,
      activate = function(g)
        return openLegacyPage(g, "pokedex", "modern_pokedex_ui_")
      end,
    }
    out[#out + 1] = {
      id = "typed_move_colors_settings_open", label = "TYPED MOVE COLORS",
      value = function() return "OPEN" end,
      activate = function(g)
        return openLegacyPage(g, "move_colors", "typed_move_colors:")
      end,
    }
    return out
  end, -10000, "modern-ui-suite-preview-adapter")

  local chunk, loadErr = loadfile(driverPath)
  assert(chunk, loadErr)
  local driver = chunk()
  assert(type(driver) == "function", driverPath .. " must return a driver")
  return driver(game)
end
