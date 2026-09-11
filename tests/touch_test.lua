package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local time,w,h=0,800,720
love={timer={getTime=function() return time end},graphics={
  getDimensions=function() return w,h end,transformPoint=function(x,y) return x*2+10,y*2+20 end}}
local hook
local api=dofile('mods/modern_ui_suite/core/touch.lua')({hooks={wrap=function(_,_,f) hook=f end}})
local old={};local menu={index=1};local top=menu
local game={input=old,stack={top=function() return top end}}
menu.game=game
local actions=0
function menu:update() if game.input:wasPressed('a') then actions=actions+1 end end
local blocked=false
local function draw()
 api.begin(menu,'window',function() return blocked end,function(key,press) press(menu,key) end)
 for i=1,2 do api.add(menu,(i-1)*30,0,28,20,'row'..i,function() menu.index=i end,function() return menu.index==i end,true) end
end
local function event(phase,x,y,id)
 return api.pointer(game,{phase=phase,x=x or 80,y=y or 30,id=id or 1,source='touch'})
end
local function tap() event('pressed');event('released') end
draw();event('pressed');T.eq(menu.index,1,'press never selects');event('released')
T.eq(menu.index,2,'release selects transformed row');T.eq(actions,0,'first tap cannot confirm')
draw();tap();T.eq(actions,1,'second selected tap uses native A');T.eq(game.input,old,'input restored')
tap();event('pressed');event('moved',80,80);event('released',80,80);tap();T.eq(actions,1,'drag disarms confirmation')
event('pressed');blocked=true;event('released');T.eq(actions,1,'modal blocks pending tap');blocked=false
event('pressed');top={};event('released');top=menu;T.eq(actions,1,'changed screen cancels')
event('pressed');event('pressed',80,30,2);event('released');T.eq(actions,1,'multitouch cancels pending tap')
tap();time=3;tap();T.eq(actions,1,'expired confirmation selects only')
event('pressed');w=1000;event('released');T.eq(actions,1,'resizing cancels pending tap');w=800
draw();tap();event('cancelled');tap();T.eq(actions,1,'cancelled gesture disarms')
-- Gen 1 frame rects map window units into the actual UI canvas at HiDPI.
menu.game.renderer={frameRects=function() return {uox=100,uoy=50,Ux=4,Uy=3} end}
api.begin(menu,'canvas');api.add(menu,0,0,20,20,'canvas',function() menu.index=9 end)
event('pressed',180,140);event('released',180,140);T.eq(menu.index,9,'Gen1 canvas offset/scale respected')
T.finish('suite_direct_touch')
