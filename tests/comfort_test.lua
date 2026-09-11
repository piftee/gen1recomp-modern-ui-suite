package.path = "./?.lua;./?/init.lua;" .. package.path
local T=require('tests.modkit')
local hooks,events,values={},{},{low_hp_beep='reduce',shop_counts=true,area_names=true}
local C=dofile('mods/modern_ui_suite/core/comfort.lua')({
 hooks={wrap=function(_,key,fn)hooks[key]=fn end},
 events={on=function(_,key,fn)events[key]=fn end},
},{isEnabled=function()return true end,get=function(_,_,key)return values[key] end})
local function alarm(ctx)return hooks['battle.low_health_alarm'](function(x)return x.on end,ctx)end
local battle={player={mon={}}}
local ctx={on=true,battle=battle}
for i=1,40 do T.eq(alarm(ctx),true,'initial alert frame '..i) end
T.eq(alarm(ctx),false,'reduced alert stops')
T.eq(ctx.on,true,'does not overwrite native alarm latch')
battle.player.mon={}
T.eq(alarm(ctx),true,'new active Pokemon gets a new alert')
alarm({on=false,battle=battle})
T.eq(alarm(ctx),true,'HP recovery rearms the alert')
values.low_hp_beep='off';T.eq(alarm(ctx),false,'off silences alert')
values.low_hp_beep='on';T.eq(alarm(ctx),true,'on retains native looping')
local game={save={inventory={POTION=999}},phase='play',stack={top=function()return nil end},world={map={}}}
T.eq(C.owned(game,'POTION'),999,'count reads complete modern stack')
game.save.inventory.POTION=1000;T.eq(C.owned(game,'POTION'),1000,'count refreshes after inventory change')
T.eq(C.owned(game,'ANTIDOTE'),0,'missing inventory count is zero')
T.eq(C.areaName('ROUTE_29',{}),'ROUTE 29','map identifiers have readable fallback')
T.eq(C.areaName('ROUTE_29',{def={name='Route 29'}}),'Route 29','prefer supplied map name')
events['game.ready']({game=game})
events['map.entered']({mapId='ROUTE_29',via='warp'})
T.check(C.areaVisible(game),'area visible after transition')
for i=1,120 do hooks['render.hud'](function()end,game,nil) end
T.check(C.areaVisible(game),'extra render calls do not consume duration')
game.stack.top=function()return {isOpaque=true}end
hooks['input.step'](function()end,game,3)
T.check(not C.areaVisible(game),'menus hide banner')
game.stack.top=function()return nil end
T.check(C.areaVisible(game),'duration pauses under menus')
hooks['input.step'](function()end,game,2.1)
T.check(not C.areaVisible(game),'banner expires after two visible seconds')
game.world.mapSign={}
events['map.entered']({mapId='ROUTE_30',via='warp'})
game.world.mapSign=nil
T.check(not C.areaVisible(game),'native Crystal sign owns the entire entry')
events['map.entered']({mapId='ROUTE_31',via='boot'})
T.check(not C.areaVisible(game),'loading a save does not announce a transition')
values.area_names=false
events['map.entered']({mapId='ROUTE_32',via='warp'})
T.check(not C.areaVisible(game),'area names remain optional')
T.finish('Selected Highlander comfort features')
