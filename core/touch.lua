-- Hit regions come from the rendered layout. A release selects; a second
-- release on the same selection invokes the controller's ordinary A action.
return function(mod)
  local api, views = {}, setmetatable({}, { __mode = "k" })
  local held, armed
  local function now() return love.timer.getTime() end
  function api.begin(menu, space, blocked, swipe)
    -- Lua 5.1 weak keys alone do not collect a value whose callbacks retain
    -- its key. Keep only the most recently drawn interactive surface.
    for previous in pairs(views) do
      if previous ~= menu then views[previous] = nil end
    end
    views[menu] = nil
    local G = love.graphics
    if not G.transformPoint then return end
    local map
    if space == "canvas" then
      local renderer = menu.game and menu.game.renderer
      if not (renderer and renderer.frameRects) then return end
      local r = renderer:frameRects()
      map = function(x,y) return (x-r.uox)/r.Ux, (y-r.uoy)/r.Uy end
    else
      map = function(x,y,event) return event.gameX or x,event.gameY or y end
    end
    local ww, wh = G.getDimensions()
    views[menu] = { targets={}, map=map, blocked=blocked, swipe=swipe, ww=ww, wh=wh }
  end
  function api.add(menu,x,y,w,h,token,select,selected,confirm)
    local view = views[menu]
    if not view then return end
    local x1,y1 = love.graphics.transformPoint(x,y)
    local x2,y2 = love.graphics.transformPoint(x+w,y+h)
    view.targets[#view.targets+1] = {x=x1,y=y1,w=x2-x1,h=y2-y1,
      token=token,select=select,selected=selected,confirm=confirm}
  end
  local function press(menu,key)
    local game, old = menu.game, menu.game.input
    game.input = setmetatable({wasPressed=function(_,k) return k==key end,
      isDown=function() return false end}, {__index=old})
    local ok, err = pcall(menu.update,menu,0)
    game.input = old
    if not ok then error(err,0) end
  end
  local function hit(view,event)
    local x,y = view.map(event.x,event.y,event)
    for _,t in ipairs(view.targets) do
      if x>=t.x and y>=t.y and x<t.x+t.w and y<t.y+t.h then return t end
    end
  end
  function api.pointer(game,event)
    local menu = game.stack and game.stack:top()
    local view = views[menu]
    local phase = event.phase
    if phase=="cancelled" then held,armed=nil,nil; return false end
    if not view or (view.blocked and view.blocked()) or event.insideGame==false then
      held,armed=nil,nil; return false
    end
    local ww,wh = love.graphics.getDimensions()
    if ww~=view.ww or wh~=view.wh then held,armed=nil,nil;return false end
    if event.button and event.button~=1 then return false end
    if phase=="pressed" then
      if held then held.cancelled=true;armed=nil;return true end
      local target = hit(view,event)
      if not target then armed=nil;return false end
      held={id=event.id,menu=menu,token=target.token,x=event.x,y=event.y,ww=ww,wh=wh}
      return true
    end
    if not held or held.id~=event.id then return false end
    local dx,dy = event.x-held.x,event.y-held.y
    if math.abs(dx)>10 or math.abs(dy)>10 then held.moved=true;armed=nil end
    if phase~="released" then return true end
    local initial=held;held=nil
    if initial.cancelled or initial.menu~=menu or initial.ww~=ww or initial.wh~=wh then return true end
    if initial.moved then
      if view.swipe and math.max(math.abs(dx),math.abs(dy))>=24 then
        local key=math.abs(dx)>math.abs(dy) and (dx<0 and "right" or "left")
          or (dy<0 and "down" or "up")
        view.swipe(key,press)
      end
      return true
    end
    local target=hit(view,event)
    if not target or target.token~=initial.token then armed=nil;return true end
    local confirm=target.confirm and armed and armed.menu==menu
      and armed.token==target.token and now()-armed.at<2
      and target.selected and target.selected()
    target.select()
    if confirm then armed=nil;press(menu,"a")
    elseif target.confirm then armed={menu=menu,token=target.token,at=now()}
    else armed=nil end
    return true
  end
  mod.hooks:wrap("input.pointer",function(next,game,event)
    if api.pointer(game,event) then return true end
    return next(game,event)
  end,1000)
  return api
end
