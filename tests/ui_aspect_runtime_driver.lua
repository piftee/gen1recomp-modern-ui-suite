-- Native engine proof, using an isolated, silent, nonactivating profile.
return function(game)
  local U=dofile(assert(os.getenv("PC_REPO")).."/tests/drivers/util.lua")
  local Screens=require("src.ui.Screens")
  local Version=require("src.core.GameVersion")
  local gen2=Version.generation()==2
  local G=love.graphics
  local checks=0
  local function check(ok,label) checks=checks+1;assert(ok,label);print("[ASPECT QA] "..label) end
  local function clear() while game.stack:top() do game.stack:pop() end end
  local opts=game.mods.modOptions.modern_ui_suite
  local make=gen2 and require("src.battle.gen2.Mon").new or require("src.pokemon.Pokemon").new
  game.save.party={}
  for _,id in ipairs(gen2 and {"QUILAVA","SPEAROW","WOOPER","TOGEPI"}
      or {"CHARMELEON","SPEAROW","SQUIRTLE","PIKACHU"}) do
    game.save.party[#game.save.party+1]=assert(make(game.data,id,21))
  end
  local function press(menu,key)
    local old=game.input
    game.input=setmetatable({wasPressed=function(_,k) return k==key end,
      isDown=function() return false end},{__index=old})
    local ok,err=pcall(menu.update,menu,0);game.input=old;assert(ok,err)
  end
  local function capture(name,w,h)
    check(not love.window.hasFocus() and love.audio.getVolume()==0,"muted and unfocused before "..name)
    if gen2 then
      local canvas=G.newCanvas(w,h)
      G.push("all");G.setCanvas(canvas);G.origin();G.setScissor();G.setShader();G.clear(1,0,1,1)
      local ok,err=pcall(game.drawScene,game,w,h);G.pop();assert(ok,err)
      local pixels=canvas:newImageData()
      local f=assert(io.open(os.getenv("SHOT_DIR").."/"..name..".png","wb"))
      f:write(pixels:encode("png"):getString());f:close();canvas:release()
      return pixels
    end
    love.window.setMode(w,h,{resizable=true})
    U.wait(2)
    check(U.shot(game,os.getenv("SHOT_DIR").."/"..name..".png"),"captured "..name)
    check(not love.window.hasFocus(),"resize/capture remained in background")
    local file=assert(io.open(os.getenv("SHOT_DIR").."/"..name..".png","rb"))
    local bytes=file:read("*a");file:close()
    return love.image.newImageData(love.filesystem.newFileData(bytes,"qa.png"))
  end
  local function openParty()
    return Screens.push(game,gen2 and "Gen2PartyMenu" or "PartyMenu",gen2 and {submenu=true} or {})
  end
  local function reveal(textbox)
    if not textbox.pages then return end
    local Font=require("src.render.Font")
    local page=textbox.pages[#textbox.pages] or {}
    textbox.shown={}
    for i=math.max(1,#page-1),#page do textbox.shown[#textbox.shown+1]=Font.encode(page[i]) end
    textbox.codes=textbox.shown[#textbox.shown] or {}
    textbox.charIndex=#textbox.codes
    textbox.done=true
  end
  local entries={
    {"party",openParty,"modernPartyLastWideWidth"},
    {"bag",function() return Screens.push(game,gen2 and "Gen2PackMenu" or "BagMenu",{save=game.save}) end,"modernBagLastWideWidth"},
    {"pc",function() return Screens.push(game,gen2 and "Gen2BoxMenu" or "BoxMenu",{save=game.save}) end,"modernPCLastWideWidth"},
    {"pokedex",function() return Screens.push(game,gen2 and "Gen2PokedexMenu" or "PokedexMenu",{save=game.save}) end,"modernPokedexLastWideWidth"},
  }
  for _,entry in ipairs(entries) do
    for _,ratio in ipairs({{"fill",320},{"16:9",256},{"4:3",192}}) do
      clear();opts[entry[1]..".aspect_ratio"]=ratio[1]
      local screen=entry[2]()
      capture(entry[1].."-"..ratio[1]:gsub(":","x"),1600,720)
      local width=gen2 and screen[entry[3]] or select(1,screen:uiSize())
      check(width==ratio[2],entry[1].." honors "..ratio[1].." in an ultrawide window: "..tostring(width))
    end
  end
  for _,ratio in ipairs({{"16:9",256},{"4:3",192}}) do
    clear();opts["party.aspect_ratio"]=ratio[1]
    local party=openParty()
    capture("party-portrait-"..ratio[1]:gsub(":","x"),480,900)
    check((gen2 and party.modernPartyLastWideWidth or select(1,party:uiSize()))==ratio[2],"portrait preserves chosen ratio")
    local summary=Screens.push(game,gen2 and "Gen2SummaryMenu" or "SummaryMenu",
      gen2 and {mon=game.save.party[1],save=game.save,party=game.save.party,index=1} or game.save.party[1])
    capture("summary-"..ratio[1]:gsub(":","x"),1600,720)
    check((gen2 and summary.modernPartyLastWideWidth or select(1,summary:uiSize()))==ratio[2],"summary inherits chosen ratio")
  end
  clear();opts["party.aspect_ratio"]="16:9"
  local party=openParty();party.index=2
  local before=capture("party-before-follow",1600,720)
  if gen2 then
    party:openSubmenu()
    local follow
    for i,row in ipairs(party.submenu.items) do if row.label=="FOLLOW" then follow=i end end
    check(follow~=nil,"Wilds of Kanto contributes the actual FOLLOW action")
    party.submenu.index=follow;press(party,"a")
    check(game.stack:top()~=party,"native FOLLOW action opens its message")
  else
    local Runtime=require("src.mods.Runtime")
    local mon=game.save.party[2]
    local rows=Runtime.call("ui.party.submenu",function(_,r) return r end,game,{},mon,{overworld=game.overworld})
    local follow
    for _,row in ipairs(rows) do if row.label=="FOLLOW" then follow=row end end
    check(follow~=nil,"Wilds of Kanto contributes FOLLOW on Gen 1")
    follow.onSelect(mon,game)
    check(game.stack:top()~=party,"FOLLOW opens its native message")
  end
  local message=game.stack:top()
  reveal(message)
  local after=capture("party-follow-message",1600,720)
  if gen2 then
    local same=true
    -- Every pixel above the native message stays identical: no compact copy,
    -- alternate card positions or changed header is painted over the roster.
    for y=0,459 do
      for x=0,1599 do
        local r,g,b=before:getPixel(x,y);local rr,gg,bb=after:getPixel(x,y)
        if r~=rr or g~=gg or b~=bb then same=false;break end
      end
      if not same then break end
    end
    check(same,"FOLLOW leaves every roster/header pixel above its message unchanged")
    capture("follow-portrait-16x9",480,900)
    check(party:battlePanelScale(480,900)==1,"portrait FOLLOW uses the menu scale, not an oversized native message")
  else
    check(game.stack:top().uiSize and select(1,game.stack:top():uiSize())==256,"FOLLOW retains the party surface")
  end
  while game.stack:top()~=party do game.stack:pop() end
  capture("party-after-follow",1600,720)
  local evo
  if gen2 then
    evo=require("src.ui.gen2.EvolutionAnim").new(game,{mon=game.save.party[1],
      entry={into="TYPHLOSION"},index=1,party=game.save.party,save=game.save})
    evo.phase="flash"
  else
    require("src.pokemon.Evolution").evolve(game,game.save.party[1],"CHARIZARD",function() end)
    local intro=game.stack:top();reveal(intro)
    check(intro.stay and intro.stay.onShown,"native evolution opens its retained intro dialogue")
    intro.stay.onShown()
    local hold=game.stack:top()
    for _=1,50 do hold:update(0) end
    evo=game.stack:top()
    check(evo.screenId=="EvolutionState","native intro/hold creates the real evolution controller")
    evo.loading=nil
  end
  if gen2 then game.stack:push(evo) end
  local pixels=capture("evolution-over-party",1600,720)
  if gen2 then
    local r,g,b=pixels:getPixel(200,200)
    check(r>0.9 and g>0.9 and b>0.9,"evolution paints opaque paper over the party wings")
  else
    check(evo.uiSize and select(1,evo:uiSize())==256,"evolution retains the party surface")
    local r,g,b=pixels:getPixel(200,200)
    check(r>0.9 and g>0.9 and b>0.9,"Gen1 evolution covers the party wings with paper")
    check(evo.isOpaque==true,"transparent native evolution gains an opaque backing")
  end
  while game.stack:top()~=party do game.stack:pop() end
  capture("party-after-evolution",1600,720)
  check(game.stack:top()==party,"evolution returns to the same party controller")
  if not gen2 then
    -- Bag's older push bridge must not center evolution twice or black out
    -- the held dialogue when the stone/rare-candy flow enters the movie.
    clear();opts["bag.aspect_ratio"]="4:3"
    local bag=Screens.push(game,"BagMenu",{})
    capture("bag-before-evolution",1600,720)
    local TextBox=require("src.render.TextBox")
    local intro=TextBox.new(game,"CHARMELEON is\nevolving!",nil,{instant=true})
    game.stack:push(intro)
    local movie=Screens.push(game,"EvolutionState",game.save.party[1],"CHARIZARD",function() end)
    movie.loading=nil
    local shot=capture("evolution-over-bag",1600,720)
    print("[ASPECT QA] Bag movie bridges",movie.__modernBagResponsiveOverlay,movie.__modernUiNativeChild,movie.holdsUIAnchors)
    for _,zone in ipairs(movie:sgbPalettes(game) or {}) do print("[ASPECT QA] Bag movie zone",zone.x,zone.y,zone.w,zone.h) end
    local r,g,b=shot:getPixel(350,200)
    check(r>0.9 and g>0.9 and b>0.9,"Bag evolution covers its wings without stale cards or double centering")
    check(select(1,movie:uiSize())==192,"Bag evolution uses the Bag's selected ratio")
    local rr,gg,bb=shot:getPixel(350,650)
    check(rr>0.9 and gg>0.9 and bb>0.9,"Bag evolution also fills beside the retained dialogue")
  end
  check(not love.window.hasFocus() and love.audio.getVolume()==0,"all native checks stayed muted and in background")
  clear();print("[DISCORD QA] PASS [ASPECT QA] "..checks)
end
