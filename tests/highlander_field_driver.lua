return function(game)
  local U=dofile(assert(os.getenv("PC_REPO")).."/tests/drivers/util.lua")
  local S=require("src.ui.Screens")
  local R=require("src.mods.Runtime")
  local api=game.mods.exports.modern_ui_suite
  local opts=game.mods.modOptions.modern_ui_suite
  local P=require("src.pokemon.Pokemon")
  local checks=0
  local function check(ok,label)assert(ok,label);checks=checks+1;print("[FIELD] "..label)end
  local function clear()while game.stack:top()do game.stack:pop()end end
  local function shot(name)
    U.wait(3);check(U.shot(game,os.getenv("SHOT_DIR").."/"..name..".png"),"capture "..name)
    check(not love.window.hasFocus() and love.audio.getVolume()==0,"muted and unfocused")
  end
  local ow=game.overworld
  local function enter(map,x,y,facing)
    clear();game.stack:push(ow,map,x,y,facing or "down",{via="boot"})
  end
  game.save.party={P.new(game.data,"CHARIZARD",50),P.new(game.data,"BLASTOISE",50),P.new(game.data,"PIKACHU",50),P.new(game.data,"PIDGEOT",50)}
  for _,mon in ipairs(game.save.party)do mon.moves={{id="TACKLE",pp=35}}end
  for _,id in ipairs({"HM_CUT","HM_SURF","HM_STRENGTH","HM_FLY","HM_FLASH","CASCADEBADGE","SOULBADGE","RAINBOWBADGE","THUNDERBADGE","BOULDERBADGE"})do game.save.inventory[id]=1 end
  opts["pokemoves.no_learn_hms"]=true;opts["pokemoves.instant_tmhm"]=true
  enter("ROUTE_2",4,4)
  local cx,cy
  for y=1,ow.map.heightCells-2 do
    for x=1,ow.map.widthCells-2 do
      if ow.map:cellTile(x,y)==0x3d and ow.map:isWalkableCell(x,y+1) then cx,cy=x,y;break end
    end
    if cx then break end
  end
  check(cx,"real Route 2 tree available")
  ow.player.cellX,ow.player.cellY,ow.player.facing=cx,cy+1,"up"
  ow:interact()
  local text=game.stack:top()
  check(text~=ow and type(text.onDone)=="function","A starts native Cut without learning it")
  game.stack:pop();text.onDone()
  check(#ow.cutBlocks.ROUTE_2==1,"Cut changes native tree block")
  enter("PALLET_TOWN",9,12)
  local found=false
  for y=1,ow.map.heightCells-1 do
    for x=1,ow.map.widthCells-1 do
      if ow.map:isWalkableCell(x,y) then
        ow.player.cellX,ow.player.cellY,ow.player.facing=x,y,"down"
        if ow:useSurfFieldMove()=="ok" then found=true;break end
      end
    end
    if found then break end
  end
  check(found,"real Pallet shoreline available")
  ow:interact();text=game.stack:top()
  check(text~=ow and type(text.onDone)=="function","A starts native Surf")
  game.stack:pop();text.onDone();check(ow.player.surfing,"Surf actually mounts")
  enter("SEAFOAM_ISLANDS_1F",4,4)
  local boulder
  for _,npc in ipairs(ow.npcs)do if npc.def.sprite=="SPRITE_BOULDER" then boulder=npc;break end end
  check(boulder,"real Seafoam boulder available")
  local face=ow.npcAtCell;ow.npcAtCell=function()return boulder end
  ow:interact();ow.npcAtCell=face
  check(ow.strengthActive,"A enables native Strength")
  enter("PALLET_TOWN",9,12)
  local old=game.input
  game.input=setmetatable({wasPressed=function(_,k)return k=="select"end},{__index=old})
  ow:handleInput();game.input=old
  local menu=game.stack:top();local fly,flash
  for _,item in ipairs(menu.items or {})do if item.label=="FLY" then fly=item elseif item.label=="FLASH" then flash=item end end
  check(fly and flash,"SELECT lists eligible field HMs without teaching")
  game.stack:pop();fly.onSelect()
  check(game.stack:top().fly==true,"FLY opens native destination map")
  enter("PALLET_TOWN",9,12)
  opts["qol.running_shoes"]="toggle"
  game.input:step();table.insert(game.input.pressQueue,"b");game.input:step()
  check(R.call("movement.speed",function(n)return n end,16,{input=game.input})==8,"B toggles running in actual overworld")
  table.insert(game.input.pressQueue,"b");game.input:step()
  check(R.call("movement.speed",function(n)return n end,16,{input=game.input})==16,"second B restores walking")
  opts["start_menu.pokebox"]=true;opts["start_menu.theme"]="green"
  S.push(game,"StartMenu");shot("green-start-pokebox")
  enter("PALLET_TOWN",9,12)
  opts["qol.sparkling_hidden"]=true
  local list=game.data.field.hiddenItems.PALLET_TOWN
  game.data.field.hiddenItems.PALLET_TOWN={{x=9,y=12,item="POTION"}}
  local rectangle=love.graphics.rectangle;local sparkles=0
  love.graphics.rectangle=function(mode,x,y,w,h,...)
    if (w==7 and h==1) or (w==1 and h==7) then sparkles=sparkles+1 end
    return rectangle(mode,x,y,w,h,...)
  end
  ow:drawWorld();check(sparkles>=2,"unclaimed hidden item draws sparkle")
  game.save.hiddenTaken=game.save.hiddenTaken or {};game.save.hiddenTaken.PALLET_TOWN_9_12=true
  sparkles=0;ow:drawWorld();check(sparkles==0,"collected hidden item stops sparkling")
  love.graphics.rectangle=rectangle;game.data.field.hiddenItems.PALLET_TOWN=list
  local battle=require("src.battle.BattleState").newWild(game,"RATTATA",5,{onFinish=function()end})
  opts["move_colors.colored_pokeballs"]=true;opts["move_colors.colored_pokemoves"]=true
  battle.animPlayer={_suiteBallVisible=true,_suiteBall="GREAT_BALL"}
  local rgb=battle:animSpriteColors({obp="f0"},0,0)
  check(rgb[2][3]>rgb[2][1],"Great Ball animation uses blue palette")
  battle.animPlayer={_suiteMove="EMBER"}
  rgb=battle:animSpriteColors({obp="f0"},0,0)
  check(rgb[2][1]>rgb[2][3],"Fire move animation uses red palette")
  print("[DISCORD QA] PASS "..checks.." Highlander field and visual checks");love.event.quit(0)
end
