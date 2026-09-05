-- Native controllers, an isolated test profile and offscreen screenshots.
return function(game)
  local Screens = require("src.ui.Screens")
  local Runtime = require("src.mods.Runtime")
  local Version = require("src.core.GameVersion")
  local Bag = require("src.inventory.Bag")
  local PaletteFX = require("src.render.PaletteFX")
  local gen2 = Version.generation() == 2
  local standalone = not game.mods.exports.modern_ui_suite
  local suite = game.mods.exports.modern_ui_suite
  local function api(id)
    return standalone and game.mods.exports[id] or suite.components[id].exports
  end
  local prefixes = { modern_bag_ui="bag", modern_start_menu_ui="start_menu" }
  local function get(id,key)
    local bucket=game.mods.modOptions[standalone and id or "modern_ui_suite"] or {}
    return bucket[standalone and key or (prefixes[id] .. "." .. key)]
  end
  local function set(id,key,value)
    local owner=standalone and id or "modern_ui_suite"
    key=standalone and key or (prefixes[id] .. "." .. key)
    game.mods.modOptions[owner]=game.mods.modOptions[owner] or {}
    game.save.options.modOptions=game.save.options.modOptions or {}
    game.save.options.modOptions[owner]=game.save.options.modOptions[owner] or {}
    game.mods.modOptions[owner][key]=value
    game.save.options.modOptions[owner][key]=value
  end
  game.renderer = game.renderer or {} -- Gen 2 renders directly; only the QA canvases use this shim.
  local checks=0
  local function check(ok,message)
    assert(ok,"CHECKLIST FAILED: "..message)
    checks=checks+1
    print("[CHECKLIST] "..message)
  end
  local function clear() while game.stack:top() do game.stack:pop() end end
  local realInput=game.input
  local function press(menu,key)
    game.input=setmetatable({wasPressed=function(_,button) return button==key end,
      isDown=function() return false end}, {__index=realInput})
    menu:update(0)
    game.input=realInput
    assert(not love.window.hasFocus(),"test window must stay in the background")
  end
  local function shot(menu,name,width,height)
    width,height=width or 256,height or 144
    local g=love.graphics
    local oldSize=game.renderer.uiSize
    game.renderer.uiSize=function() return width,height end
    menu.modernPartyWideWidth=width; menu.modernBagWideWidth=width
    local canvas=g.newCanvas(width,height);canvas:setFilter("nearest","nearest")
    g.push("all");g.setCanvas(canvas);g.origin();g.setShader();g.setScissor()
    g.clear(1,1,1,1)
    if menu.drawPanel then menu:drawPanel() else menu:draw() end
    local display=canvas
    if not gen2 and menu.sgbPalettes then
      display=g.newCanvas(width,height);display:setFilter("nearest","nearest")
      g.setCanvas(display);g.clear(1,1,1,1);g.setColor(1,1,1,1)
      local shader=PaletteFX.shader();g.setShader(shader)
      for _,zone in ipairs(menu:sgbPalettes(game) or {}) do
        if zone.colors then
          PaletteFX.sendColors(shader,zone.colors)
          g.setScissor(zone.x,zone.y,zone.w,zone.h);g.draw(canvas)
        end
      end
      g.setShader();g.setScissor()
    end
    local large=g.newCanvas(width*4,height*4)
    g.setCanvas(large);g.clear(1,1,1,1);g.setColor(1,1,1,1);g.draw(display,0,0,0,4,4)
    g.pop()
    local f=assert(io.open(os.getenv("SHOT_DIR").."/"..name..".png","wb"))
    f:write(large:newImageData():encode("png"):getString());f:close()
    menu.modernPartyWideWidth=nil;menu.modernBagWideWidth=nil
    game.renderer.uiSize=oldSize
  end
  PaletteFX.setMode("gbc")
  game.save.options.faithfulRes=0
  local bagApi=api("modern_bag_ui").pocketSettings
  local startApi=api("modern_start_menu_ui").settings
  if os.getenv("CHECKLIST_REOPEN")=="1" then
    check(get("modern_bag_ui","hide_all")==true,"Hide All persists after process restart")
    check(get("modern_bag_ui","open_on")=="medicine","Open On persists after process restart")
    check(type(get("modern_bag_ui","pocket_order"))=="table","pocket order persists after process restart")
    check(type(get("modern_start_menu_ui","icon_order"))=="table","icon order persists after process restart")
    local bag=Screens.push(game,gen2 and "Gen2PackMenu" or "BagMenu",{})
    local key=gen2 and bag:modernBagLayoutInfo().pocket or bag.modernBagPockets[bag.modernBagPocket].key
    check(key==(gen2 and "MEDICINE" or "medicine"),"restarted Bag opens on the configured visible pocket")
    print("[CHECKLIST] PASS restart "..checks)
    return
  end

  local tm=gen2 and "TM_THUNDERPUNCH" or "TM_THUNDERBOLT"
  game.save.inventory={};game.save.bagOrder={}
  local original={"BICYCLE","POTION","ESCAPE_ROPE",tm,"ANTIDOTE","POKE_BALL"}
  for _,id in ipairs(original) do check(Bag.add(game.save,id,1,game.data),"seed "..id) end
  local function bagMenu()
    clear();return Screens.push(game,gen2 and "Gen2PackMenu" or "BagMenu",{})
  end
  set("modern_bag_ui","skin","modern")
  for _,key in ipairs({"all","items","medicine","balls","machines","key"}) do
    set("modern_bag_ui","open_on",key)
    local menu=bagMenu()
    local actual=gen2 and menu.modernBagPockets[menu.modernBagPocketIndex].key
      or menu.modernBagPockets[menu.modernBagPocket].key
    check(actual==key,"native Bag opens on "..key)
  end
  set("modern_bag_ui","open_on","medicine")
  local menu=bagMenu()
  -- Drive the actual small sort menu with START then A.
  press(menu,"start")
  if gen2 then press(menu,"a") else press(game.stack:top(),"a") end
  check(table.concat(game.save.bagOrder,",")==table.concat({"ESCAPE_ROPE","POTION","ANTIDOTE","POKE_BALL",tm,"BICYCLE"},","),"native category ascending groups the entire Bag")
  check((gen2 and menu:modernBagLayoutInfo().pocket=="ALL")
    or (not gen2 and menu.modernBagPockets[menu.modernBagPocket].key=="all"),"category result is visible from Medicine")
  shot(menu,"bag-categories-ascending")
  press(menu,"start")
  local sorter=gen2 and menu or game.stack:top()
  press(sorter,"down");press(sorter,"a")
  check(table.concat(game.save.bagOrder,",")==table.concat({"BICYCLE",tm,"POKE_BALL","POTION","ANTIDOTE","ESCAPE_ROPE"},","),"native category descending reverses the groups")
  shot(menu,"bag-categories-descending")
  set("modern_bag_ui","hide_all",true)
  clear();bagApi.openOrder(game);local editor=game.stack:top()
  check(#editor.items==5,"native pocket editor contains five visible tabs")
  press(editor,"select");press(editor,"down");press(editor,"b")
  check(editor.held==nil and game.stack:top()==editor,"B cancels a held pocket without closing")
  editor.index=1;press(editor,"select");press(editor,"down");press(editor,"select")
  shot(editor,"bag-pocket-order",160,144);press(editor,"b")
  menu=bagMenu()
  check(menu.modernBagPockets[1].key=="medicine","native tabs use the saved custom order")
  shot(menu,"bag-hidden-all-open-medicine")
  set("modern_bag_ui","skin","classic_pocket");set("modern_bag_ui","open_on","key")
  menu=bagMenu()
  check((gen2 and menu:pocket().id=="KEY_ITEM") or (not gen2 and menu.modernBagPockets[menu.modernBagPocket].key=="key"),"Pocket skin uses the configured opening pocket")
  shot(menu,"bag-pocket-skin")
  set("modern_bag_ui","skin","modern");set("modern_bag_ui","open_on","medicine")

  clear();startApi.openOrder(game)
  check(game.stack:top().items[1].label=="OPEN START ONCE","native icon editor explains discovery before Start opens")
  press(game.stack:top(),"b")
  local removeHook=Runtime.hooks:wrap("ui.start_menu.items",function(next,g,rows)
    local out=next(g,rows)
    for i=1,8 do out[#out+1]={id="checklist_"..i,label="EXTRA "..i,onSelect=function() end} end
    return out
  end,0,"checklist-qa")
  local start=Screens.push(game,gen2 and "Gen2StartMenu" or "StartMenu")
  local liveCount=#start.items
  local movedItem=start.items[1]
  startApi.openOrder(game);editor=game.stack:top()
  check(#editor.items==liveCount and liveCount>7,"icon editor includes every live native and mod-added entry")
  press(editor,"right")
  shot(editor,"start-icon-order",160,144);press(editor,"b")
  clear();start=Screens.push(game,gen2 and "Gen2StartMenu" or "StartMenu")
  check(start.items[2].id==movedItem.id,"reopened native Start applies saved icon order")
  removeHook()

  local makeMon=gen2 and require("src.battle.gen2.Mon").new or require("src.pokemon.Pokemon").new
  local first=assert(makeMon(game.data,gen2 and "CHIKORITA" or "BULBASAUR",10))
  local second=assert(makeMon(game.data,gen2 and "CYNDAQUIL" or "CHARMANDER",10))
  game.save.party={first,second};game.partyMenuSavedIndex=1;game.partyMenuCursor=1
  clear();local roster=Screens.push(game,gen2 and "Gen2PartyMenu" or "PartyMenu",gen2 and {submenu=true} or {})
  roster.modernPartyLastWideWidth=256
  press(roster,"select");press(roster,"right")
  shot(roster,"party-held")
  press(roster,"b")
  check(not (roster.swapFrom or roster.switchFrom) and game.stack:top()==roster,"native B cancels Party hold")
  roster.index=1
  local mail
  if gen2 then
    local Mail=require("src.core.gen2.Mail")
    mail=Mail.entry("FLOWER_MAIL","HELLO","GOLD",123,first.species)
    Mail.set(game.save,1,mail)
  end
  press(roster,"select");press(roster,"right");press(roster,"select")
  check(game.save.party[1]==second and game.save.party[2]==first,"native Select swaps complete party records")
  if gen2 then check(require("src.core.gen2.Mail").get(game.save,2)==mail,"mail follows its Pokémon through the native swap") end

  -- Enter the battle engine's actual replacement factory with a fainted lead.
  clear();game.save.party={first,second};first.hp=0
  game.partyMenuSavedIndex=1;game.partyMenuCursor=1
  local battle,forced
  if gen2 then
    local Battle=require("src.battle.gen2.Battle")
    battle=Battle.new({data=game.data,save=game.save,party=game.save.party,
      wild=makeMon(game.data,"PIDGEY",5),random=function() return 0 end})
    local screen=Screens.push(game,"Gen2BattleState",{save=game.save,battle=battle,onDone=function() end})
    screen:openParty(true);forced=game.stack:top()
    forced.modernPartyLastWideWidth=256
  else
    battle=require("src.battle.BattleState").newWild(game,"PIDGEY",5,{onFinish=function() end})
    game.stack:push(battle);battle.queue={};battle:openReplacementMenu()
    forced=table.remove(battle.queue,1).ui();game.stack:push(forced)
  end
  local originalSize=game.renderer.uiSize
  game.renderer.uiSize=function() return 256,144 end
  forced.index=1;press(forced,"down")
  check(forced.index==2,"Down immediately leaves the fainted slot in the real replacement menu")
  shot(forced,"party-forced-replacement")
  press(forced,"select")
  check(not (forced.swapFrom or forced.switchFrom),"replacement menu cannot pick up party slots")
  press(forced,"a")
  check(game.stack:top()~=forced,"A immediately accepts the healthy replacement")
  check((gen2 and battle.player==second) or (not gen2 and battle.player.mon==second),"battle engine receives the healthy replacement")
  game.renderer.uiSize=originalSize
  clear();game:writeOptions()
  print("[CHECKLIST] PASS native "..checks.." focused="..tostring(love.window.hasFocus()))
end
