-- Real QoL Toggles integration: both options may remain enabled, one label draws.
return function(game)
  local U=dofile(assert(os.getenv('PC_REPO'))..'/tests/drivers/util.lua')
  local World=require('src.world.gen2.World')
  local Save=require('src.core.gen2.Save')
  local Runtime=require('src.mods.Runtime')
  local Font=require('src.render.Font')
  local companion=assert(game.mods.exports.qol_toggles)
  local checks=0
  local function check(ok,label)checks=checks+1;assert(ok,label)end
  love.window.setMode(1280,720,{resizable=true,vsync=0})
  while game.stack:top()do game.stack:pop()end
  game.save=Save.newGame({playerName='AREA QA',trainerId=4321})
  game.save.options=game.options or game.save.options
  game.phase='play'
  local opts=game.mods.modOptions.modern_ui_suite
  opts['start_menu.area_names']=true
  game.mods.modOptions.qol_toggles=game.mods.modOptions.qol_toggles or {}
  local qol=game.mods.modOptions.qol_toggles
  qol.map_location=true
  local world=game.world or World.new(game);game.world=world
  if not world.maps then assert(world:load())end
  -- Freeze game-time only in this disposable profile; draw through the real
  -- frame compositor and both mods' real hooks on the actual map transition.
  game.update=function()end
  local drawGame,drawText=game.draw,Font.draw
  local writes={}
  game.draw=function(self,...)writes={};return drawGame(self,...)end
  Font.draw=function(text,...)
    local key=tostring(text):upper():gsub('[^%w]','')
    writes[key]=(writes[key] or 0)+1
    return drawText(text,...)
  end
  local function shot(name,key,count)
    U.wait(3)
    check(U.shot(game,os.getenv('SHOT_DIR')..'/'..name..'.png'),'capture '..name)
    check((writes[key] or 0)==count,name..' draws '..count..' matching label(s), got '..tostring(writes[key] or 0))
    check(not love.window.hasFocus() and love.audio.getVolume()==0,'silent nonactivating test')
  end
  assert(world:setMap('ROUTE_30',8,12,'down',{via='connection'}))
  world.mapSetup,world.textbox=nil,nil
  if game.mods.exports.BATTLE_ART_VOXEL_GEN2 then
    game.mods.exports.BATTLE_ART_VOXEL_GEN2.lib.require('Gen2WorldAdapter').prepareWorld(world)
  end
  shot('one-area-label','ROUTE30',1)
  check(opts['start_menu.area_names']==true and qol.map_location==true,'both preferences remain enabled')
  companion.setLocationToast('ROUTE 30',love.timer.getTime()-100)
  shot('no-delayed-label','ROUTE30',0)
  qol.map_location=false
  assert(world:setMap('ROUTE_31',8,6,'down',{via='connection'}))
  world.mapSetup,world.textbox=nil,nil
  shot('suite-fallback','ROUTE31',1)
  Runtime.call('input.step',function()end,game,2.1)
  shot('suite-expired','ROUTE31',0)
  Font.draw=drawText;game.draw=drawGame
  print('[DISCORD QA] PASS '..checks..' area banner checks')
  love.event.quit(0)
end
