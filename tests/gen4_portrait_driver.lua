return function(game)
 local U=dofile(assert(os.getenv('PC_REPO'))..'/tests/drivers/util.lua')
 local G=love.graphics
 local gen2=require('src.core.GameVersion').generation()==2
 local provider=game.mods.exports.BATTLE_ART_VOXEL_GEN2 or game.mods.exports.BATTLE_ART_VOXEL_FORK
 local art=provider.battleArt or provider.lib.require('BattleArt')
 art.duplicateSetting:setIndex(1,game);art.setting:sync('animated');art.frontAnimationSetting:setIndex(4,game)
 game.mods.modOptions.modern_ui_suite.menu_sprite_source='battle_art'
 game.mods.modOptions.modern_ui_suite['party.aspect_ratio']='16:9'
 local resolve=game.mods.exports.modern_ui_suite.menuPortrait
 local animation=provider.lib.require('AnimatedBattleArt')
 local checks=0
 local function check(ok,label) assert(ok,label);checks=checks+1;print('[GEN4 QA] '..label) end
 local realTime=love.timer.getTime;local now=0;love.timer.getTime=function() return now end
 local make=gen2 and require('src.battle.gen2.Mon').new or require('src.pokemon.Pokemon').new
 for _,species in ipairs({'BULBASAUR','WARTORTLE','PIKACHU','BLASTOISE'}) do
  local mon=make(game.data,species,32)
  local def=animation.definitionFor({species=species,mon=mon,dvs=mon.dvs,data=game.data.pokemon[species]},'front')
  local src=love.image.newImageData(provider.lib.mod.assets:path(def.image))
  local elapsed=0;local cw,ch
  for frame=1,def.frames do
   now=(elapsed+.1)/1000
   local img=assert(resolve(game,mon))
   local w,h=img:getDimensions();cw,ch=cw or w,ch or h
   check(w==cw and h==ch,species..' frame '..frame..' keeps stable size')
   local canvas=G.newCanvas(w,h)
   G.push('all');G.setCanvas(canvas);G.origin();G.setShader();G.setScissor();G.clear(0,0,0,0);G.setColor(1,1,1,1);G.draw(img,0,0);G.pop()
   local actual=canvas:newImageData();canvas:release()
   local count,shown,white,shownWhite=0,0,0,0
   local fx=((frame-1)%def.columns)*def.width;local fy=math.floor((frame-1)/def.columns)*def.height
   for y=0,def.height-1 do for x=0,def.width-1 do
    local r,g,b,a=src:getPixel(fx+x,fy+y);if a>0 then count=count+1;if r==1 and g==1 and b==1 then white=white+1 end end
   end end
   for y=0,h-1 do for x=0,w-1 do
    local r,g,b,a=actual:getPixel(x,y);if a>0 then shown=shown+1;if r==1 and g==1 and b==1 then shownWhite=shownWhite+1 end end
   end end
   check(count==shown,species..' frame '..frame..' preserves every visible pixel')
   check(white==shownWhite,species..' frame '..frame..' preserves white markings')
   elapsed=elapsed+(def.durations and def.durations[frame] or 100)
  end
  check(cw<def.width or ch<def.height,species..' transparent margins removed: '..def.width..'x'..def.height..' -> '..cw..'x'..ch)
  while game.stack:top() do game.stack:pop() end
  game.save.party={mon};now=0
  require('src.ui.Screens').push(game,gen2 and 'Gen2SummaryMenu' or 'SummaryMenu',gen2 and {mon=mon,save=game.save} or mon)
  love.window.setMode(1280,720,{resizable=true});U.wait(3)
  check(U.shot(game,os.getenv('SHOT_DIR')..'/gen4-'..species:lower()..'.png'),'captured '..species)
  check(not love.window.hasFocus() and love.audio.getVolume()==0,'muted and unfocused')
 end
 love.timer.getTime=realTime
 print('[DISCORD QA] PASS '..checks..' Gen4 checks');love.event.quit(0)
end
