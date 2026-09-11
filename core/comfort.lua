-- Selected Highlander comfort ideas, adapted to public hooks and native Gen 2
-- controllers. No global constructors, text functions or gameplay rules change.
return function(mod, settings)
  local C = {}
  local activeGame, toast
  local chirps = setmetatable({}, {__mode="k"})
  local function enabled(component, key)
    return settings:isEnabled(component) and settings:get(component, key)
  end
  local function currentMon(screen)
    local player = screen and (screen.battle and screen.battle.player or screen.player)
    return type(player) == "table" and (player.mon or player) or nil
  end
  mod.hooks:wrap("battle.low_health_alarm", function(next, ctx)
    if type(ctx) ~= "table" then return next(ctx) end
    local mode = enabled("battle_info_hud", "low_hp_beep")
    local battle, on = ctx.battle, ctx.on
    if battle then
      if mode ~= "reduce" or not on then chirps[battle] = nil
      else
        local mon = currentMon(battle)
        local burst = chirps[battle]
        if not burst or burst.mon ~= mon then
          burst = {mon=mon, frames=40}; chirps[battle] = burst
        end
        on = burst.frames > 0
        burst.frames = math.max(0, burst.frames - 1)
      end
    end
    if mode == "off" then on = false end
    local adjusted = {}
    for k,v in pairs(ctx) do adjusted[k]=v end
    adjusted.on = on
    return next(adjusted)
  end)

  function C.owned(game, id)
    local n = game and game.save and game.save.inventory and game.save.inventory[id]
    return math.max(0, math.floor(tonumber(n) or 0))
  end
  local function drawOwned(game, id)
    if not id or not enabled("modern_bag_ui", "shop_counts") then return end
    local Font, G = require("src.render.Font"), love.graphics
    G.push("all")
    G.setColor(1,1,1,1); G.rectangle("fill",0,0,80,16)
    G.setColor(0,0,0,1)
    Font.draw("OWN " .. tostring(C.owned(game,id)),4,4)
    G.pop()
  end
  function C.decorateShop(menu, game)
    if type(menu) ~= "table" or menu.modernShopCount then return end
    local method, selected
    if menu.screenId == "Gen2MartMenu" then
      method = "drawUnder"
      selected = function(self)
        if self.phase ~= "buy" and self.phase ~= "buyQuantity" then return end
        local row = self.entries and self.entries[self.index]
        return row and row.id
      end
    elseif getmetatable(menu) == require("src.ui.ListMenu") and menu.dialogue
        and menu.itemBox and menu.money and not menu.onSelectKey then
      local priced = false
      for _, row in ipairs(menu.items or {}) do
        if row.value and (row.price or row.right) then priced = true; break end
      end
      if not priced then return end
      method = "draw"
      selected = function(self)
        local row = self.items and self.items[self.index]
        return row and not row.cancel and row.value
      end
    else return end
    local draw = menu[method]
    if type(draw) ~= "function" then return end
    menu.modernShopCount = true
    menu[method] = function(self, ...)
      local result = draw(self, ...)
      if game.stack:top() == self then drawOwned(game, selected(self)) end
      return result
    end
  end
  mod.events:on("screen.pushed", function(event)
    local game = event and (event.game or event.state and event.state.game) or activeGame
    if game then C.decorateShop(event and event.state, game) end
  end, -1000)

  function C.areaName(mapId, map)
    local def = type(map) == "table" and (map.def or map) or {}
    for _, key in ipairs({"label", "name", "title", "displayName"}) do
      if type(def[key]) == "string" and def[key] ~= "" then return def[key]:gsub("\n", " ") end
    end
    if type(mapId) ~= "string" then return nil end
    return mapId:gsub("_", " "):gsub("(%l)(%u)", "%1 %2")
      :gsub("(%a)(%d)", "%1 %2")
  end
  function C.overworldVisible(game)
    local top = game and game.stack and game.stack:top()
    if top then return top.isOverworld == true and not top.textbox end
    return game and game.phase == "play" and game.world and game.world.map
      and not game.world.textbox and not game.world.mapSetup
  end
  function C.areaVisible(game)
    return toast and toast.game == game and toast.left > 0
      and enabled("modern_start_menu_ui", "area_names") and C.overworldVisible(game)
      and not (game.world and game.world.mapSign)
  end
  mod.events:on("game.ready", function(event)
    activeGame = event and (event.game or event)
    toast = nil
  end)
  mod.events:on("map.entered", function(event)
    toast = nil
    if not enabled("modern_start_menu_ui", "area_names") or type(event) ~= "table"
        or event.via == "boot" or event.via == "continue" then return end
    local game = event.game or activeGame
    -- Crystal already presents a native sign for many outdoor transitions.
    -- Yield for the entire entry, even if that sign is dismissed early.
    if not game or game.world and game.world.mapSign then return end
    local name = C.areaName(event.mapId, event.map)
    if name then toast = {game=game, text=name, left=2} end
  end)
  mod.hooks:wrap("input.step", function(next, game, dt)
    activeGame = game or activeGame
    if toast and (not enabled("modern_start_menu_ui", "area_names") or toast.game ~= game) then
      toast = nil
    elseif toast and C.areaVisible(game) then
      toast.left = toast.left - math.max(0, tonumber(dt) or 0)
    end
    return next(game, dt)
  end)
  local function linesFor(text, Font)
    local lines, line = {}, ""
    for word in text:gmatch("%S+") do
      local trial = line == "" and word or line .. " " .. word
      if Font.width(trial) <= 136 then line = trial
      else
        if line ~= "" then lines[#lines+1] = line end
        line = word
      end
    end
    if line ~= "" then lines[#lines+1]=line end
    if #lines > 2 then lines[2] = lines[2] .. "..." end
    for i=1, math.min(2,#lines) do
      local spans = Font.split(lines[i])
      local n = Font.spansFitting(spans,136)
      if n < #spans then
        lines[i] = n > 1 and lines[i]:sub(1,spans[n-1].to) .. "." or "."
      end
    end
    return lines
  end
  mod.hooks:wrap("render.hud", function(next, game, viewport)
    local result = next(game, viewport)
    if not C.areaVisible(game) or type(viewport) ~= "table" then return result end
    local Font, G = require("src.render.Font"), love.graphics
    local lines = linesFor(toast.text, Font)
    local scale = viewport.scale or 1
    local height = #lines > 1 and 36 or 24
    G.push("all")
    G.translate(viewport.gameX or 0, viewport.gameY or 0); G.scale(scale,scale)
    G.setColor(1,1,1,1); G.rectangle("fill",4,140-height,152,height)
    G.setColor(0,0,0,1); G.setLineWidth(1); G.rectangle("line",4.5,140-height+0.5,151,height-1)
    for i=1, math.min(2,#lines) do
      Font.draw(lines[i],math.floor((160-Font.width(lines[i]))/2),140-height+8+(i-1)*12)
    end
    G.pop()
    return result
  end)
  return C
end
