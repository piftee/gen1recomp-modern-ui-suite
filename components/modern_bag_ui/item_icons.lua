-- Colour item art shared by Modern Bag and Modern UI Suite. All base-game IDs
-- are mapped explicitly; unknown mod items return false to the category fallback.
return function(mod)
  local function readModule(name)
    return assert(load(assert(mod:read(name)), '@'..mod.path..'/'..name))()
  end
  local map, spans = readModule('item_icon_map.lua'), readModule('item_icon_spans.lua')
  local images, quads = {}, {}
  local api = {}
  function api.frame(id, data)
    if not id then return nil end
    local variants = map.variants[id]
    if variants then
      local generation = tonumber(data and (data.generation or data.items and data.items.generation))
      if generation ~= 2 and data and data.items and data.items.MASTER_BALL then
        generation = data.items.MASTER_BALL.pocket and 2 or 1
      end
      return variants[tostring(generation == 2 and 2 or 1)]
    end
    local def = data and data.items and data.items[id]
    local machine = def and def.machine
    if map.machine_items[id] or machine or (def and def.tmLabel) then
      local moveId = (machine and machine.move) or (def and def.teaches) or id:match('^[TH]M_(.+)$')
      local move = data and data.moves and data.moves[moveId]
      local moveType = move and tostring(move.type):upper()
      return map.discs[moveType] or map.discs.NORMAL
    end
    return map.frames[id]
  end
  function api.draw(menu, id, x, y, size)
    local frame = api.frame(id, menu.game and menu.game.data)
    if frame == nil then return false end
    size = size and size < 24 and 12 or 24
    if images[size] == nil then
      local ok, image = pcall(love.graphics.newImage, mod.path..'/assets/item_icons/items-'..size..'.png')
      if not ok then images[size] = false; return false end
      image:setFilter('nearest', 'nearest')
      images[size], quads[size] = image, {}
    end
    local image = images[size]
    if not image then return false end
    if not quads[size][frame] then
      local w,h = image:getDimensions()
      quads[size][frame] = love.graphics.newQuad(frame % map.columns * size,
        math.floor(frame / map.columns) * size, size, size, w, h)
    end
    x,y = math.floor(x),math.floor(y)
    love.graphics.push('all')
    love.graphics.setShader()
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(image, quads[size][frame], x,y)
    love.graphics.pop()
    local zones = menu.modernBagItemIconZones or {}
    menu.modernBagItemIconZones = zones
    for _, span in ipairs(spans[size][frame+1]) do
      zones[#zones+1] = {colors=false,x=x+span[1],y=y+span[2],w=span[3],h=1}
    end
    menu.modernBagItemIcon = {id=id,frame=frame,x=x,y=y,size=size}
    return true
  end
  function api.zones(menu, zones)
    for _, zone in ipairs(menu.modernBagItemIconZones or {}) do zones[#zones+1]=zone end
    return zones
  end
  return api
end
