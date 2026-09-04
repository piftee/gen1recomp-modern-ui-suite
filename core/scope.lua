return function(parent, settings, state, component)
  local api = {
    id = component.id,
    version = component.version,
    path = parent.path .. "/components/" .. component.id,
    manifest = { id = component.id, version = component.version },
    exports = {},
    DELETE = parent.DELETE,
    ui = parent.ui,
    save = parent.save,
    storage = parent.storage,
    checkpoints = parent.checkpoints,
    input = parent.input,
    migrations = parent.migrations,
  }

  component.exports = api.exports
  state.componentApis[component.id] = api

  local function gated()
    return settings:isEnabled(component)
  end

  api.options = {
    define = function(_, schema)
      return settings:registerSchema(component, schema)
    end,
    get = function(_, key)
      return settings:get(component, key)
    end,
    set = function(_, game, key, value)
      return settings:set(game, component, key, value)
    end,
    enabled = function()
      return gated()
    end,
  }
  api.suite = {
    option = function(id, key) return settings:get(id, key) end,
    enabled = function(id) return settings:isEnabled(id) end,
  }

  api.events = {
    on = function(_, name, callback, priority)
      return parent.events:on(name, function(payload)
        if gated() then return callback(payload) end
      end, priority)
    end,
    once = function(_, name, callback, priority)
      local cancel
      cancel = parent.events:on(name, function(payload)
        if not gated() then return end
        if cancel then cancel(); cancel = nil end
        return callback(payload)
      end, priority)
      return cancel
    end,
    emit = function(_, name, payload)
      return parent.events:emit(name, payload)
    end,
    -- Compatibility shims sometimes have to remain installed while a visual
    -- component is switched off.  They do not draw that component; they keep
    -- two third-party providers from painting the same native surface.  Keep
    -- this explicit so ordinary component lifecycle listeners stay gated.
    always = function(_, name, callback, priority)
      return parent.events:on(name, callback, priority)
    end,
  }

  api.hooks = {
    wrap = function(_, name, callback, priority)
      if name == "ui.options.rows" then
        state.optionsHooks[component.id] = callback
        return function() state.optionsHooks[component.id] = nil end
      end
      return parent.hooks:wrap(name, function(next, ...)
        if gated() then return callback(next, ...) end
        return next(...)
      end, priority)
    end,
  }

  local NATIVE_SCREENS = {
    BagMenu = "src.ui.BagMenu",
    PlayerPC = "src.ui.PlayerPC",
    PartyMenu = "src.ui.PartyMenu",
    SummaryMenu = "src.ui.SummaryMenu",
    NamingScreen = "src.ui.NamingScreen",
    BoxMenu = "src.ui.BoxMenu",
    PokedexMenu = "src.ui.PokedexMenu",
    DexEntryMenu = "src.ui.DexEntryMenu",
    MoveLearnMenu = "src.ui.MoveLearnMenu",
    Gen2PackMenu = "src.ui.gen2.PackMenu",
    Gen2ItemPcMenu = "src.ui.gen2.ItemPcMenu",
    Gen2PartyMenu = "src.ui.gen2.PartyMenu",
    Gen2SummaryMenu = "src.ui.gen2.SummaryMenu",
    Gen2NamingScreen = "src.ui.gen2.NamingScreen",
    Gen2BoxMenu = "src.ui.gen2.BoxMenu",
    Gen2PcMenu = "src.ui.gen2.PcMenu",
    Gen2PokedexMenu = "src.ui.gen2.PokedexMenu",
  }

  local function constructor(record)
    if type(record) == "function" then return record end
    return type(record) == "table" and record.new or nil
  end

  local function nativeNew(id, game, ...)
    local path = NATIVE_SCREENS[id]
    assert(path, "no native fallback registered for screen " .. tostring(id))
    local native = require(path)
    assert(type(native) == "table" and type(native.new) == "function",
      "native screen has no constructor: " .. path)
    return native.new(game, ...)
  end

  local function wrapScreen(id, record, downstream)
    if id:find(":settings", 1, true) or id:find(":icon_picker", 1, true) then
      return record
    end
    local new = assert(constructor(record), "screen record needs a constructor: " .. id)
    local out = type(record) == "table" and setmetatable({}, getmetatable(record)) or {}
    if type(record) == "table" then
      for key, value in pairs(record) do out[key] = value end
    end
    out.new = function(game, ...)
      if gated() then return new(game, ...) end
      local fallback = constructor(downstream)
      if fallback then return fallback(game, ...) end
      return nativeNew(id, game, ...)
    end
    out.__modernUiSuiteComponent = component.id
    out.__modernUiSuiteEnabled = gated
    return out
  end

  api.content = {}
  for name, registry in pairs(parent.content) do api.content[name] = registry end
  local parentScreens = parent.content.screens
  api.content.screens = {
    get = function(_, id) return parentScreens:get(id) end,
    has = function(_, id) return parentScreens:get(id) ~= nil end,
    register = function(_, id, record)
      local downstream = parentScreens:get(id)
      state.screenTouches[component.id] = (state.screenTouches[component.id] or 0) + 1
      return parentScreens:register(id, wrapScreen(id, record, downstream))
    end,
    override = function(_, id, record)
      local downstream = parentScreens:get(id)
      state.screenTouches[component.id] = (state.screenTouches[component.id] or 0) + 1
      return parentScreens:override(id, wrapScreen(id, record, downstream))
    end,
    patch = function(_, ...) return parentScreens:patch(...) end,
    remove = function(_, ...) return parentScreens:remove(...) end,
  }

  api.assets = setmetatable({
    path = function(_, relative)
      return parent.assets:path("components/" .. component.id .. "/" .. relative)
    end,
    image = function(_, relative)
      return parent.assets:image("components/" .. component.id .. "/" .. relative)
    end,
  }, { __index = parent.assets })

  function api:read(relative)
    return parent:read("components/" .. component.id .. "/" .. relative)
  end

  function api:load(relative)
    local source, readErr = self:read(relative)
    assert(source, tostring(readErr or (relative .. " is missing")))
    local chunk, compileErr = load(source, "@" .. self.path .. "/" .. relative)
    assert(chunk, compileErr)
    return chunk()
  end

  api.find = function(first, second)
    local id = second == nil and first or second
    local internal = state.componentApis[id]
    if internal then
      local spec = settings.byId[id]
      return { id = id, version = spec.version, exports = internal.exports }
    end
    return parent.find(id)
  end

  api.log = {
    info = function(_, fmt, ...)
      return parent.log:info("[%s] " .. fmt, component.id, ...)
    end,
    warn = function(_, fmt, ...)
      return parent.log:warn("[%s] " .. fmt, component.id, ...)
    end,
    error = function(_, fmt, ...)
      state.bootErrors[component.id] = string.format(fmt, ...)
      return parent.log:error("[%s] " .. fmt, component.id, ...)
    end,
  }

  return setmetatable(api, { __index = parent })
end
