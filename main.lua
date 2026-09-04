return function(mod)
  local function loadLocal(relative)
    local source, readErr = mod:read(relative)
    assert(source, tostring(readErr or (relative .. " is missing")))
    local chunk, compileErr = load(source, "@" .. mod.path .. "/" .. relative)
    assert(chunk, compileErr)
    return chunk()
  end

  local components = loadLocal("core/components.lua")
  local makeSettings = loadLocal("core/settings.lua")
  local makeScope = loadLocal("core/scope.lua")
  local makeHub = loadLocal("core/hub.lua")
  local settings = makeSettings(mod, components)
  local state = {
    componentApis = {},
    optionsHooks = {},
    screenTouches = {},
    bootErrors = {},
  }

  -- Validate the complete archive before any component gets a chance to
  -- register. This keeps a damaged all-in-one install atomic.
  for _, component in ipairs(components) do
    local base = "components/" .. component.id .. "/"
    for _, relative in ipairs(component.files or {}) do
      local source, readErr = mod:read(base .. relative)
      assert(source, tostring(readErr or (base .. relative .. " is missing")))
      local chunk, compileErr = load(source, "@" .. mod.path .. "/" .. base .. relative)
      assert(chunk, compileErr)
    end
    for _, relative in ipairs(component.assets or {}) do
      local bytes, readErr = mod:read(base .. relative)
      assert(bytes and #bytes > 0,
        tostring(readErr or (base .. relative .. " is missing or empty")))
    end
  end

  -- Migration is registered before component lifecycle listeners, so legacy
  -- preferences are visible by the time their first game.ready work runs.
  mod.events:on("game.ready", function(event)
    settings:migrate(event and (event.game or event))
  end, 10000)

  local installOrder = {}
  for index, component in ipairs(components) do installOrder[index] = component end
  table.sort(installOrder, function(a, b) return a.installOrder < b.installOrder end)
  for _, component in ipairs(installOrder) do
    local scope = makeScope(mod, settings, state, component)
    local installer = scope:load("main.lua")
    assert(type(installer) == "function",
      component.id .. "/main.lua must return an installer")
    installer(scope)
    if state.bootErrors[component.id] then
      error(component.id .. " failed to initialize: " .. state.bootErrors[component.id], 0)
    end
  end

  -- Per-category GAME SPEED treats an unmarked overlay as transparent to the
  -- gameplay state below it. That is useful for dialogue, but it makes a
  -- replacement menu opened over the overworld inherit OVERWORLD SPEED. The
  -- suite's controllers already carry stable presentation markers, so claim
  -- MENU SPEED while one of those controllers (or an unmarked child prompt
  -- above it) owns the top of the stack. Stop at a newer gameplay boundary so
  -- a stale menu underneath a battle/overworld can never change its speed.
  local menuMarkers = {
    modernStartMenuUI = true,
    modernUiSuiteComponent = true,
    modernBagUI = true,
    modernBagSortMenu = true,
    modernPCUI = true,
    __modernBagResponsiveOverlay = true,
    __modernBagTossPrompts = true,
    modernPartyUI = true,
    modernPartySummary = true,
    modernPartyNaming = true,
    modernPartyRibbons = true,
    modernPartyRelearn = true,
    modernPartyMovesManager = true,
    modernMoveDetail = true,
    modernPokedexUI = true,
    modernPokedexEntry = true,
    modernPokedexAreaMap = true,
    modernDexSearchOpen = true,
    modernDexAreaBridge = true,
  }

  local screenPrefixes = { mod.id .. ":" }
  for _, component in ipairs(components) do
    screenPrefixes[#screenPrefixes + 1] = component.id .. ":"
  end

  local function suiteMenuInStack(game)
    local states = game and game.stack and game.stack.states
    for index = #(states or {}), 1, -1 do
      local screen = states[index]
      if type(screen) == "table" then
        for marker in pairs(menuMarkers) do
          if screen[marker] == true then return true end
        end
        local screenId = screen.screenId
        if type(screenId) == "string" then
          for _, prefix in ipairs(screenPrefixes) do
            if screenId:sub(1, #prefix) == prefix then return true end
          end
        end
        if screen.isBattle or screen.isOverworld then return false end
      end
    end
    return false
  end

  mod.hooks:wrap("core.logic_speed", function(next, game)
    local inherited = next(game)
    if not suiteMenuInStack(game) then return inherited end
    local options = game and game.save and game.save.options
    local menuSpeed = tonumber(options and options.speedMenu)
    -- Engines predating independent speed categories have only `speed`.
    -- Passing through retains their established single-speed behavior.
    return menuSpeed or inherited
  end, 1000)

  mod.options:define(settings:aggregateSchema())
  local hub = makeHub(mod, settings, state, components)

  local public = {}
  for _, component in ipairs(components) do
    public[component.id] = {
      version = component.version,
      enabled = function() return settings:isEnabled(component) end,
      exports = component.exports,
    }
  end
  mod.exports.components = public
  mod.exports.isEnabled = function(id)
    local component = settings.byId[id]
    return component and settings:isEnabled(component) or false
  end
  mod.exports.settings = hub
  mod.exports.apiVersion = 1
  mod.log:info("seven-component Modern UI Suite initialized")
end
