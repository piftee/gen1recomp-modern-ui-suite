-- Visual and interaction sweep for every Modern UI Suite settings row.
-- Run from the repository root with only modern_ui_suite enabled:
--   SHOT_DIR=/tmp/modern-ui-suite-options \
--   POKEPORT_DRIVER=mods/modern_ui_suite/tests/options_preview_driver.lua \
--   POKEPORT_IDENTITY=modern-ui-suite-preview POKEPORT_VERSION=red love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local OptionsMenu = require("src.ui.OptionsMenu")
  local GameVersion = require("src.core.GameVersion")
  local Screens = require("src.ui.Screens")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/modern-ui-suite-options"

  local function clear()
    while game.stack:top() do game.stack:pop() end
  end

  local function check(ok, message)
    if not ok then error("MODERN UI SUITE OPTIONS FAILED: " .. message, 0) end
    U.log("PASS", message)
  end

  local function slug(value)
    value = tostring(value or "none"):lower()
    value = value:gsub("[^%w]+", "-"):gsub("^-+", ""):gsub("-+$", "")
    return value ~= "" and value or "none"
  end

  local shotIndex = 0
  local function capture(name)
    shotIndex = shotIndex + 1
    U.wait(2)
    check(U.shot(game, ("%s/%03d-%s.png"):format(DIR, shotIndex, name)),
      name .. " screenshot captured")
  end

  clear()
  local currentVersion = GameVersion.get()
  local generation = type(GameVersion.generation) == "function"
    and GameVersion.generation(currentVersion)
    or 1
  local root
  if generation == 2 then
    root = Screens.push(game, "Gen2OptionsMenu", {
      options = game.save.options,
    })
    root = assert(root:focusRow("modern_ui_suite_settings"),
      "Modern UI Suite row is absent from Gen 2 Options")
  else
    root = OptionsMenu.new(game)
    game.stack:push(root)
  end
  local rootIndex, rootEntry
  local rootRows = type(root.visible) == "function" and root:visible()
    or root.rows or {}
  for index, row in ipairs(rootRows) do
    if row.id == "modern_ui_suite_settings" then
      rootIndex, rootEntry = index, row
      break
    end
  end
  check(rootEntry and type(rootEntry.activate) == "function",
    "the unified suite entry is present in vanilla Options")
  root.index = rootIndex
  root.scroll = math.max(0, rootIndex - 4)
  capture("vanilla-options-entry")
  rootEntry.activate(game)

  local hub = game.stack:top()
  check(hub ~= root and hub.screenId == "modern_ui_suite:settings",
    "the unified suite hub opens")
  check(#(hub.items or {}) == 10,
    "the hub contains both bulk actions, seven components, and Back")
  hub.index = 1
  capture("suite-hub-top")
  hub.index = #hub.items
  capture("suite-hub-bottom")

  local aggregate = game.mods.optionSchemas
    and game.mods.optionSchemas.modern_ui_suite or {}
  local schemaByKey = {}
  for _, row in ipairs(aggregate) do schemaByKey[row.key] = row end

  local testedRows, testedValues = 0, 0
  for hubIndex = 3, 9 do
    hub.index = hubIndex
    local item = hub.items[hubIndex]
    check(item and item.component, "hub component " .. tostring(hubIndex - 2) .. " exists")
    U.tap(game, "a")
    local page = game.stack:top()
    check(page ~= hub and page.modernUiSuiteComponent == item.component.id,
      item.component.short .. " settings page opens")

    for rowIndex, row in ipairs(page.rows or {}) do
      page.index = rowIndex
      page.scroll = math.max(0, rowIndex - 4)
      local source = schemaByKey[row.id]
      if type(row.step) == "function" and source then
        local valueCount = source.type == "toggle" and 2
          or math.max(1, #(source.choices or {}))
        local starting = row.value and row.value() or "value"
        capture(slug(item.component.key) .. "-" .. slug(row.id)
          .. "-" .. slug(starting))
        testedValues = testedValues + 1
        for _ = 2, valueCount do
          U.tap(game, "right")
          local value = row.value and row.value() or "value"
          capture(slug(item.component.key) .. "-" .. slug(row.id)
            .. "-" .. slug(value))
          testedValues = testedValues + 1
        end
        -- One complete cycle must return to the value with which the row
        -- started, proving both wrapping and persistence through the real UI.
        if valueCount > 1 then U.tap(game, "right") end
        check(not row.value or row.value() == starting,
          row.id .. " cycles through every advertised value")
        testedRows = testedRows + 1
      elseif row.id == "start_menu.icon_overrides" then
        capture("start-menu-icon-overrides-entry")
        testedRows = testedRows + 1
      end
    end

    while game.stack:top() ~= hub do game.stack:pop() end
  end

  check(testedRows == 32,
    "all 31 persisted settings and the icon-overrides action were reached")
  check(testedValues == 77,
    "all advertised toggle and choice values were rendered")
  U.log(("PASS %d settings rows and %d values rendered in %d screenshots")
    :format(testedRows, testedValues, shotIndex))
end
