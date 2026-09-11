-- Run through the repository's isolated quiet native runner, never a live profile.
return function(game)
 local root=assert(os.getenv('PC_REPO'))
 local U=dofile(root..'/tests/drivers/util.lua')
 local Screens=require('src.ui.Screens')
 local gen2=require('src.core.GameVersion').generation()==2
 local G=love.graphics
 local checks=0
 local function check(ok,label) checks=checks+1;assert(ok,label);print('[FEEDBACK QA] '..label) end
 local function clear() while game.stack:top() do game.stack:pop() end end
 local opts=game.mods.modOptions.modern_ui_suite
 local function press(menu,key)
  local old=game.input;game.input=setmetatable({wasPressed=function(_,k) return k==key end,isDown=function() return false end},{__index=old})
  local ok,err=pcall(menu.update,menu,0);game.input=old;assert(ok,err)
 end
 local function shot(name,w,h)
  love.window.setMode(w or 1280,h or 720,{resizable=true})
  U.wait(3)
  check(U.shot(game,os.getenv('SHOT_DIR')..'/'..name..'.png'),'captured '..name)
  check(not love.window.hasFocus() and love.audio.getVolume()==0,'capture muted and unfocused')
 end
 local make=gen2 and require('src.battle.gen2.Mon').new or require('src.pokemon.Pokemon').new
 game.save.party={}
 for _,id in ipairs(gen2 and {'ELEKID','WARTORTLE','BULBASAUR','PIKACHU','QUILAVA'} or {'BLASTOISE','WARTORTLE','BULBASAUR','PIKACHU','CHARMELEON'}) do
  game.save.party[#game.save.party+1]=assert(make(game.data,id,32))
 end
 local mon=game.save.party[1]
 mon.item=gen2 and 'BERRY' or nil;mon.heldItem=gen2 and 'BERRY' or 'LEFTOVERS'
 local function openSummary()
  return Screens.push(game,gen2 and 'Gen2SummaryMenu' or 'SummaryMenu',gen2 and {mon=mon,party=game.save.party,index=1,save=game.save,onClose=function() game.stack:pop() end} or mon)
 end
 for _,ratio in ipairs({'4:3','16:9','fill'}) do
  opts['party.aspect_ratio']=ratio;clear()
  local summary=openSummary();summary.whiteHold=0
  shot('summary-'..ratio:gsub(':','x'))
  if game.mods.exports['Kanto-Reforged'] then
   if gen2 then for _=1,3 do press(summary,'right') end
   else press(summary,'b');press(summary,'b') end
   check(summary.page==(gen2 and 4 or 3),'Kanto info reachable by native navigation')
   shot('kanto-info-'..ratio:gsub(':','x'))
   check(summary.modernAbilityText~=nil,'modern info renders provider data')
   press(summary,'b');check(game.stack:top()~=summary,'native close still works')
  end
 end
 opts['party.aspect_ratio']='4:3';clear()
 local party=Screens.push(game,gen2 and 'Gen2PartyMenu' or 'PartyMenu',gen2 and {submenu=true} or {})
 shot('party-4x3')
 party.index=1;press(party,'right');check(party.index==2,'right reaches second card at 4:3')
 press(party,'down');check(party.index==4,'down follows visible two-column grid')
 local function point(x,y,width)
  if not gen2 then local r=game.renderer:frameRects();return r.uox+x*r.Ux,r.uoy+y*r.Uy end
  local ww,wh=G.getDimensions();local scale=math.min(ww/width,wh/144)
  return (ww-width*scale)/2+x*scale,(wh-144*scale)/2+y*scale
 end
 local function tap(x,y,width)
  x,y=point(x,y,width)
  game:pointerEvent('pressed','touch','feedback',x,y,0,0,1)
  game:pointerEvent('released','touch','feedback',x,y,0,0,1)
 end
 party.index=1
 tap(144,32,192);check(party.index==2 and not party.submenu,'first direct touch selects party card')
 tap(144,32,192);check(party.submenu~=nil,'second direct touch opens native actions')
 local old=party.index;tap(40,32,192);check(party.index==old,'submenu prevents underlying card activation')
 party.submenu=nil
 shot('party-portrait',480,900)
 clear();opts['bag.aspect_ratio']='4:3'
 local Bag=require('src.inventory.Bag')
 for _,id in ipairs({'POTION','SUPER_POTION','ANTIDOTE','POKE_BALL','GREAT_BALL','PARLYZ_HEAL','REPEL'}) do Bag.add(game.save,id,4) end
 local bag=Screens.push(game,gen2 and 'Gen2PackMenu' or 'BagMenu',{save=game.save})
 shot('bag-4x3',1280,720)
 if gen2 then
  local before=bag.modernBagPocketIndex
  tap(192*2.5/6,24,192)
  check(bag.modernBagPocketIndex~=before,'direct touch switches rendered pocket')
  U.wait(2)
  tap(40,54,192);check(bag.index==2 and not bag.submenu,'Bag row tap selects only')
  tap(40,54,192);check(bag.submenu~=nil,'Bag second tap opens native item actions')
 else
  local layout=bag:modernBagLayoutInfo()
  local count=#bag.modernBagPockets;local gap=layout.width>=210 and 3 or 1
  local tw=math.floor((layout.width-8-gap*(count-1))/count)
  local x0=math.floor((layout.width-(tw*count+gap*(count-1)))/2)
  tap(x0+2*(tw+gap)+tw/2,layout.tabsY+8,192)
  check(bag.modernBagPocket==3,'Gen1 direct touch switches rendered pocket')
  shot('bag-medicine')
  layout=bag:modernBagLayoutInfo()
  tap(layout.listX+20,layout.listY+4+7,192)
  check(bag.index==1 and game.stack:top()==bag,'Gen1 Bag first tap selects only: '..tostring(bag.index)..' items '..#bag.items)
  tap(layout.listX+20,layout.listY+4+7,192)
  check(game.stack:top()~=bag,'Gen1 Bag second tap opens native item actions')
 end
 shot('bag-actions')
 clear()
 local pc=Screens.push(game,gen2 and 'Gen2BoxMenu' or 'BoxMenu',{save=game.save})
 shot('pc')
 clear();Screens.push(game,gen2 and 'Gen2PokedexMenu' or 'PokedexMenu',{save=game.save});shot('pokedex')
 clear();local chosen
 local start=Screens.push(game,gen2 and 'Gen2StartMenu' or 'StartMenu',gen2 and {onChoose=function(id) chosen=id;game.stack:pop() end} or nil);shot('start-menu')
 local presentation=game.mods.exports.modern_ui_suite.components.modern_start_menu_ui.exports.presentation
 start.modernStartHudPass=true
 local layout=presentation.layoutFor(start)
 start.modernStartHudPass=nil
 -- Landscape START is composited at the native fit scale in the HUD pass.
 local sx,sy=point(layout.gridX+32+15,layout.gridY+15,layout.width)
 if not gen2 then
  local r=game.renderer:frameRects()
  sx=r.vux+math.floor((r.vuw-layout.width*r.Sx)/2)+(layout.gridX+47)*r.Sx
  sy=r.vuy+math.floor((r.vuh-144*r.Sy)/2)+(layout.gridY+15)*r.Sy
 end
 local function startTap()
  game:pointerEvent('pressed','touch','start-qa',sx,sy,0,0,1)
  game:pointerEvent('released','touch','start-qa',sx,sy,0,0,1)
 end
 startTap();check(start.index==2 and game.stack:top()==start,'START first tap selects tile')
 startTap();check(game.stack:top()~=start,'START second tap invokes native tile action')
 if gen2 then
  clear()
  local Mon=require('src.battle.gen2.Mon')
  local Battle=require('src.battle.gen2.Battle')
  local enemy=Mon.new(game.data,'PIDGEOT',30)
  game.save.party[1].moves={{id='THUNDERPUNCH',pp=15},{id='QUICK_ATTACK',pp=30},{id='SWIFT',pp=20},{id='THUNDER_WAVE',pp=20}}
  local battle=Battle.new({data=game.data,save=game.save,party=game.save.party,wild=enemy,random=function() return 0 end})
  local screen=Screens.push(game,'Gen2BattleState',{save=game.save,battle=battle,onDone=function() end})
  screen.slideFrame=require('src.ui.gen2.BattleAnimView').SLIDE_FRAMES
  screen.showPlayerTrainer=false;screen.showEnemyTrainer=false
  screen.showEnemyHud=true;screen.showPlayerHud=true;screen.ballRows={};screen.queue={}
  screen.message='What will ELEKID do?';screen.messageTimer=0;screen.phase='menu';screen.menuIndex=1;screen.anim=nil
  screen.update=function() end
  shot('battle-hud')
  screen.phase='moves';screen.moveIndex=1;opts['move_colors.layout']='wide';shot('move-colors')
 end
 print('[DISCORD QA] PASS '..checks..' feedback checks');love.event.quit(0)
end
