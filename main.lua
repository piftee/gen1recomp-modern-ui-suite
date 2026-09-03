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
