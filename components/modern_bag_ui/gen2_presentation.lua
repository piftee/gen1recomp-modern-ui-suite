-- The Gen 1 Bag composition, fed by the native Gen 2 PACK controller.
return function(mod, source)
  local G=love.graphics
  local Palette=require('src.render.PaletteFX')
  local Font=require('src.render.Font')
  local Menu=require('src.ui.Menu')
  local touch=mod.suite and mod.suite.touch
  local palettes={
    BLUEMON={{255,239,255},{148,165,222},{90,123,189},{25,16,16}},
    REDMON={{255,239,255},{255,165,82},{214,82,49},{25,16,16}},
    CYANMON={{255,239,255},{173,206,239},{115,156,206},{25,16,16}},
    BROWNMON={{255,239,255},{230,165,123},{173,115,74},{25,16,16}},
    GREENMON={{255,239,255},{165,214,132},{74,165,90},{25,16,16}},
    PURPLEMON={{255,239,255},{222,181,197},{173,123,189},{25,16,16}},
  }
  local category={ALL='all',ITEMS='items',MEDICINE='medicine',BALL='balls',TM_HM='machines',KEY_ITEM='key'}
  local owner
  local api=assert(load(assert(mod:read('screen.lua')),'@'..mod.path..'/screen.lua'))()(mod,{
    presentationSize=function(state) return state.width,state.height end,
    categoryFor=function(_,id) return category[source.category(owner,id)] or 'items' end,
    capacity=function(state)
      -- Four physical pockets retain their native capacities; All reports
      -- occupied slots without implying one shared capacity.
      return ('%d'):format(#source.order(state.nativeBag))
    end,
    description=function(state,id)
      if not id then return 'Return to the previous screen.' end
      return tostring(state.nativeBag:description() or ''):gsub('<NEXT>',' ')
    end,
    palette=function(_,name) return palettes[name] or palettes.BLUEMON end,
  }).presentation
  local pocketByKey={}
  for _,pocket in ipairs(api.pockets) do pocketByKey[pocket.key]=pocket end
  local function size(menu)
    return menu.modernBagWideWidth or menu.modernBagLastWideWidth or 160,
      menu.modernBagWideHeight or menu.modernBagLastWideHeight or 144
  end
  local function stateFor(menu)
    local state=menu.modernGen2BagPresentation or {nativeBag=menu,game=menu.game}
    menu.modernGen2BagPresentation=state
    state.width,state.height=size(menu)
    state.modernBagPocket=menu.modernBagPocketIndex
    state.modernBagPockets={}
    for _,pocket in ipairs(menu.modernBagPockets) do
      state.modernBagPockets[#state.modernBagPockets+1]=pocketByKey[pocket.key]
    end
    state.items={}
    for _,row in ipairs(menu.rows or {}) do
      state.items[#state.items+1]={value=row.id,
        label=row.tmhmLabel and (row.tmhmLabel..' '..tostring(row.teaches or row.name)) or row.name,
        right=row.showCount and ('x'..tostring(row.count or 0)) or ''}
    end
    -- B remains the normal exit, matching Gen 1's list. The native terminal
    -- CANCEL row appears only while selected, preserving its controller.
    if menu.index==menu:total() and #state.items>0 then
      state.items[#state.items+1]={label='CANCEL',right=''}
    end
    state.index,state.scroll=menu.index,menu.scroll
    local prompt=menu.message or menu.confirm and menu.confirm.prompt
    state.modernBagPrompt=prompt and table.concat(prompt,' '):gsub('{PLAYER}',menu:playerName()) or nil
    state.modernBagSwapId=menu.switching and menu.rows[menu.switching] and menu.rows[menu.switching].id
    state.modernBagDescriptionBlocked=menu.submenu or menu.qtyState or menu.modernBagSortMenu
    state.modernBagDescriptionScroll=menu.modernBagDescriptionScroll
    return state
  end
  local function layout(menu)
    return api.layout(stateFor(menu))
  end
  local function dialog(state,rows,index,opts)
    local menu=Menu.new(state.game,rows,opts)
    menu.index=index or 1
    local dx,dy=math.floor((state.width-160)/2),math.floor((state.height-144)/2)
    G.push('all');G.translate(dx,dy);menu:draw()
    if opts.title then G.setColor(0,0,0,1);Font.draw(opts.title,(menu.tx+1)*8,(menu.ty+1)*8) end
    G.pop()
    return {x=dx+menu.tx*8,y=dy+menu.ty*8,w=menu.tw*8,h=menu.th*8,colors=Palette.GRAYS}
  end
  local function overlays(menu,state,l)
    local zones={}
    if menu.modernBagSortMenu then
      local sort=menu.modernBagSortMenu
      zones[#zones+1]=dialog(state,sort.rows,sort.index,{tx=2,ty=3,tw=16,th=9,rowStep=1.5,title='SORT BY'})
    end
    if menu.submenu then
      local rows={}
      for _,id in ipairs(menu.submenu.rows) do rows[#rows+1]={label=source.labels[id] or id:upper()} end
      zones[#zones+1]=dialog(state,rows,menu.submenu.index,{tx=10,ty=2,tw=10})
    end
    if menu.confirm then
      zones[#zones+1]=dialog(state,{{label='YES'},{label='NO'}},menu.confirm.choice,{tx=14,ty=5,tw=6})
    end
    if menu.qtyState then
      local w,h=40,24
      local row=math.max(0,menu.index-menu.scroll-1)
      local x=l.showDetails and not l.stacked and (l.listX+l.listW-6) or (l.listX+l.listW-w-5)
      local y=math.max(l.contentY,math.min(l.footerY-h,l.listY+3+row*15-5))
      x=math.max(0,math.min(l.width-w,x))
      local q=Menu.new(state.game,{}, {tx=0,ty=0,tw=5,th=3})
      G.push('all');G.translate(x,y);q:draw();G.setColor(0,0,0,1)
      Font.draw('x'..('%02d'):format(menu.qtyState.qty or 1),8,8);G.pop()
      zones[#zones+1]={x=x,y=y,w=w,h=h,colors=Palette.GRAYS}
      menu.modernBagQuantityBounds={x=x,y=y,w=w,h=h}
    end
    return zones
  end
  local function render(menu)
    owner=menu
    local state=stateFor(menu)
    local l=api.layout(state)
    menu.modernBagVisibleRows=l.rows
    menu:ensureVisible()
    state.index,state.scroll=menu.index,menu.scroll
    local counts={}
    for _,id in ipairs(source.order(menu)) do
      local key=category[source.category(menu,id)] or 'items'
      counts.all=(counts.all or 0)+1;counts[key]=(counts[key] or 0)+1
    end
    local canvas=menu.modernGen2BagCanvas
    if not canvas or canvas:getWidth()~=l.width or canvas:getHeight()~=l.canvasHeight then
      if canvas and canvas.release then canvas:release() end
      canvas=G.newCanvas(l.width,l.canvasHeight);canvas:setFilter('nearest','nearest')
      menu.modernGen2BagCanvas=canvas
    end
    local previous=G.getCanvas()
    G.push('all');G.setCanvas(canvas);G.origin();G.setScissor();G.clear(0,0,0,0)
    api.draw(state,counts)
    local zones=api.zones(state,menu.game)
    for _,zone in ipairs(overlays(menu,state,l)) do zones[#zones+1]=zone end
    G.setCanvas(previous);G.pop()
    G.push('all');G.setColor(1,1,1,1)
    local shader=Palette.shader();G.setShader(shader)
    for _,zone in ipairs(zones) do
      if shader then Palette.sendColors(shader,zone.colors) end
      G.draw(canvas,G.newQuad(zone.x,zone.y,zone.w,zone.h,l.width,l.canvasHeight),zone.x,zone.y)
    end
    G.pop()
    menu.modernBagDescriptionScroll=state.modernBagDescriptionScroll
    menu.modernBagHeaderCash,menu.modernBagHeaderBounds=state.modernBagHeaderCash,state.modernBagHeaderBounds
    if touch then
      touch.begin(menu,'window',function()return menu.qtyState or menu.message or menu.confirm or menu.submenu or menu.repeatSfx or menu.modernBagSortMenu or menu.tutorial end,
        function(key,press)press(menu,key)end)
      local pockets=state.modernBagPockets
      local gap=l.width>=210 and 3 or 1
      local tabW=math.floor((l.width-8-gap*(#pockets-1))/#pockets)
      local x0=math.floor((l.width-(tabW*#pockets+gap*(#pockets-1)))/2)
      for i,pocket in ipairs(pockets) do
        touch.add(menu,x0+(i-1)*(tabW+gap),l.tabsY,tabW,l.tabsH,'pocket:'..pocket.key,function()menu:switchPocket(i-menu.modernBagPocketIndex)end)
      end
      for row=1,l.rows do
        local i=menu.scroll+row
        if state.items[i] then touch.add(menu,l.listX,l.listY+4+(row-1)*15,l.listW,15,'item:'..tostring(state.items[i].value),
          function()menu.index=i;menu:ensureVisible()end,function()return menu.index==i end,true) end
      end
    end
  end
  return {render=render,layout=layout,qol=function(menu)return api.qol(stateFor(menu))end}
end
