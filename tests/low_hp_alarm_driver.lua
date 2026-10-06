return function(game)
 local U=dofile(os.getenv('PC_REPO')..'/tests/drivers/util.lua')
 local Sound=require('src.core.Sound')
 local Battle=require('src.ui.gen2.BattleState')
 local opts=game.mods.modOptions.modern_ui_suite
 local checks=0
 local function check(ok,label) assert(ok,label);checks=checks+1;print('[ALARM] '..label) end
 local start,stop=Sound.startLoop,Sound.stopLoop
 local playing=false
 Sound.startLoop=function(_,id) if id=='Low_Health_Alarm' then playing=true end end
 Sound.stopLoop=function(id) if id=='Low_Health_Alarm' then playing=false end end
 local mon=require('src.battle.gen2.Mon').new(game.data,'CYNDAQUIL',15);mon.hp=1
 local screen=setmetatable({game=game,battle={player=mon},hudHpPixels=function()return 1 end},{__index=Battle})
 for _,hud in ipairs({true,false}) do
 opts['battle_hud.enabled']=hud
 for _,mode in ipairs({'on','off','reduce'}) do
  opts['battle_hud.low_hp_beep']=mode
  for i=1,45 do screen:updateAlarm();check(playing==(mode=='on' or mode=='reduce' and i<=40),mode..' frame '..i) end
 end
 end
 screen.battle.player=require('src.battle.gen2.Mon').new(game.data,'TOTODILE',15)
 screen.battle.player.hp=1;screen:updateAlarm();check(playing,'new mon rearms reduce')
 screen.lowHealthAlarmDisabled=true;screen:updateAlarm();check(not playing,'native disabled flag stops loop')
 Sound.startLoop,Sound.stopLoop=start,stop
 check(not love.window.hasFocus() and love.audio.getVolume()==0,'silent background')
 print('[DISCORD QA] PASS '..checks..' native alarm checks');love.event.quit(0)
end
