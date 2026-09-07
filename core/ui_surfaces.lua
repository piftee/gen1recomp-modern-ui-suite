-- Shared sizing and native-child composition for the suite's full-page menus.
return function(mod, settings)
  local Surface = {}

  function Surface.fixedSize(component)
    local game = settings.activeGame
    local options = game and game.save and game.save.options
    if (tonumber(options and options.faithfulRes) or 0) > 0 then return 160, 144 end
    if settings:get(component, "responsive") == false then return 160, 144 end
    local ratio = settings:get(component, "aspect_ratio")
    if ratio == "16:9" then return 256, 144 end
    if ratio == "4:3" then return 192, 144 end
  end

  function Surface.isNativeEvolution(screen)
    if screen.screenId == "EvolutionState" then return true end
    local ok, native = pcall(require, "src.ui.EvolutionState")
    return ok and getmetatable(screen) == native
  end

  function Surface.geometry(component, screen, winW, winH, width, height, scale)
    local fixedW, fixedH = Surface.fixedSize(component)
    local options = screen.game and screen.game.save and screen.game.save.options
    if (tonumber(options and options.faithfulRes) or 0) > 0 then
      fixedW, fixedH = 160, 144
    end
    if fixedW then
      width, height = fixedW, fixedH
      scale = math.min(winW / width, winH / height)
      if scale >= 1 then scale = math.floor(scale) end
    end
    screen.modernUiSurfaceViewport = {w=winW, h=winH, scale=scale}
    return width, height, scale
  end

  -- Game2 paints the wide owner, then draws the native stack for transparent
  -- prompts. That second pass must draw only the overlays above our owner.
  -- Consume a one-pass token rather than hiding the state from visibleBase:
  -- the opaque boundary and all update/input ownership remain native.
  function Surface.guardWideDraw(screen)
    if screen.__modernUiWideGuard or type(screen.drawWidescreen) ~= "function"
        or type(screen.draw) ~= "function" then return end
    screen.__modernUiWideGuard = true
    local wide, native = screen.drawWidescreen, screen.draw
    local overlayTop
    screen.drawWidescreen = function(self, ...)
      overlayTop = nil
      local result = wide(self, ...)
      local stack = self.game and self.game.stack
      local top = stack and stack:top()
      if top and top ~= self then overlayTop = top end
      return result
    end
    screen.draw = function(self, ...)
      local stack = self.game and self.game.stack
      local skip = overlayTop and stack and stack:top() == overlayTop
      overlayTop = nil
      if not skip then return native(self, ...) end
    end
  end

  function Surface.decorate(screen, component)
    if type(screen) ~= "table" then return screen end
    screen.modernUiSurfaceComponent = component.id
    if type(screen.drawWidescreen) == "function" then
      -- Game2 uses this panel-scale contract for the native overlay pass.
      -- Fixed-ratio menus on narrow displays can fit at a smaller scale than
      -- a 160px TextBox, so the prompt must inherit the owner's actual scale.
      screen.battlePanelScale = function(self, w, h)
        local viewport = self.modernUiSurfaceViewport
        if viewport and viewport.w == w and viewport.h == h then return viewport.scale end
      end
    end
    Surface.guardWideDraw(screen)
    return screen
  end

  local function shiftZones(zones, width, height)
    if not zones then return nil end
    local dx, dy = math.floor((width - 160) / 2), math.floor((height - 144) / 2)
    local out = {}
    for i, zone in ipairs(zones) do
      local copy = {}
      for key, value in pairs(zone) do copy[key] = value end
      if zone.x == 0 and zone.y == 0 and zone.w == 160 and zone.h == 144 then
        copy.w, copy.h = width, height
      else
        copy.x, copy.y = (zone.x or 0) + dx, (zone.y or 0) + dy
      end
      out[i] = copy
    end
    return out
  end

  function Surface.bridgeChild(child, owner)
    local evolutionText
    local evolution = not owner.drawWidescreen and Surface.isNativeEvolution(child)
    if evolution and not child.__modernUiEvolutionMatte then
      -- Newer Gen 1 engines keep EvolutionState transparent to retain the
      -- already-open "is evolving" TextBox. Keep that exact controller/text,
      -- but replace the party behind it with opaque paper across the surface.
      child.__modernUiEvolutionMatte = true
      child.isOpaque = true
      local TextBox = require("src.render.TextBox")
      local states = child.game and child.game.stack and child.game.stack.states or {}
      for i = #states - 1, 1, -1 do
        local candidate = states[i]
        if getmetatable(candidate) == TextBox then evolutionText = candidate; break end
        if candidate.isOpaque then break end
      end
    end
    local function paper(self)
      local width, height = self:uiSize()
      local Palette = require("src.render.PaletteFX")
      local rects = Palette.trueColorRects("ui")
      for i = #rects, 1, -1 do rects[i] = nil end
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", 0, 0, width, height)
      if evolutionText then evolutionText:draw() end
    end
    if evolution and child.uiSize then
      -- Bag may have already centered this native scene in its push wrapper.
      -- Add the paper outside that transform; do not center it twice.
      local draw = child.draw
      child.draw = function(self, ...)
        love.graphics.push("all")
        paper(self)
        local ok, result = pcall(draw, self, ...)
        love.graphics.pop()
        if not ok then error(result, 0) end
        return result
      end
      return
    end
    -- Responsive child presenters and Bag's row-anchored prompts already own
    -- their coordinates. Native Gen 2 scenes paint their own window surround.
    if child.uiSize or child.__modernUiNativeChild then return end
    if owner.drawWidescreen then
      Surface.guardWideDraw(child)
      child.modernUiSurfaceComponent = owner.modernUiSurfaceComponent
      return
    end
    if type(owner.uiSize) ~= "function" or type(child.draw) ~= "function" then return end
    local Palette = require("src.render.PaletteFX")
    child.__modernUiNativeChild = true
    child.modernUiSurfaceComponent = owner.modernUiSurfaceComponent
    child.uiSize = function() return owner:uiSize() end
    child.holdsUIAnchors = true
    child.isWideBattleLayout = function() return true end
    local draw, palettes = child.draw, child.sgbPalettes
    child.draw = function(self, ...)
      local width, height = self:uiSize()
      local dx, dy = math.floor((width - 160) / 2), math.floor((height - 144) / 2)
      local G = love.graphics
      G.push("all")
      if self.isOpaque then
        paper(self)
      end
      G.translate(dx, dy)
      local mark = Palette.markTrueColor
      Palette.markTrueColor = function(x, y, w, h)
        return mark(x + dx, y + dy, w, h)
      end
      local ok, result = pcall(draw, self, ...)
      Palette.markTrueColor = mark
      G.pop()
      if not ok then error(result, 0) end
      return result
    end
    if type(palettes) == "function" then
      child.sgbPalettes = function(self, game)
        local width, height = self:uiSize()
        return shiftZones(palettes(self, game), width, height)
      end
    end
  end

  mod.events:on("screen.pushed", function(event)
    local child = event and event.state
    local game = child and (child.game or settings.activeGame)
    local states = game and game.stack and game.stack.states
    if not states or child.modernUiSurfaceComponent or child.isBattle or child.isOverworld then return end
    local seenChild = false
    for i = #states, 1, -1 do
      local screen = states[i]
      if screen == child then
        seenChild = true
      elseif seenChild then
        local id = screen.modernUiSurfaceComponent
        if id then
          if settings:isEnabled(id) then Surface.bridgeChild(child, screen) end
          return
        end
        -- Do not claim scenes belonging to a newer gameplay/full-page owner.
        if screen.isBattle or screen.isOverworld or screen.isOpaque then return end
      end
    end
  end)
  return Surface
end
