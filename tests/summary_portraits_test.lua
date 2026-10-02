package.path = './?.lua;./?/init.lua;' .. package.path
local T = require('tests.modkit')
local source, enabled, image, pending = 'battle_art', true, {}, false
local marks, depth, requested, supplied = {{x=1,y=2,w=3,h=4}}, 0
love = {graphics={
  push=function() depth=depth+1 end, pop=function() depth=depth-1 end,
  setShader=function() end, translate=function() end, scale=function() end,
}}
package.loaded['src.render.PaletteFX'] = {trueColorRects=function() return marks end}
local api = {
  frontArt=function(mon) supplied=mon; return image,pending end,
  drawSummaryFrame=function(mon,box)
    requested=box; mon.debug=true
    marks[#marks+1]={x=2,y=3,w=20,h=21}
    return true
  end,
}
local options = {}
local game = {mods={modOptions={['g9-battle-sprites']=options}}}
local resolve = dofile('mods/modern_ui_suite/core/summary_portraits.lua')({
  options={get=function() return source end},
  find=function(id) return enabled and id=='g9-battle-sprites' and {exports=api} or nil end,
})
local mon={species='STARLY',shiny=true,gender='female',form=2}
local paint=resolve(game,mon)
T.eq(type(paint),'function','current provider offers a menu painter')
T.check(supplied~=mon,'provider receives presentation copy')
T.same(supplied,mon,'shiny gender and form fields survive')
T.eq(paint(10,20,2),true,'painter executes safely')
T.same(requested,{x=0,w=56,bottom=56},'provider gets native summary slot')
T.same(marks[1],{x=1,y=2,w=3,h=4},'earlier palette marks remain untouched')
T.same(marks[2],{x=14,y=26,w=40,h=42},'new marks follow summary geometry')
T.eq(mon.debug,nil,'render does not write saved mon')
T.eq(depth,0,'graphics state restored')
image=nil;pending=true
T.eq(type(resolve(game,mon)),'function','pending art suppresses native placeholder')
pending=false
T.eq(resolve(game,mon),nil,'missing artwork falls back')
image={};options.dex_sprites=false
T.eq(type(resolve(game,mon)),'function','Dex switch does not hide summary')
options.summary_sprites=false
T.eq(resolve(game,mon),nil,'summary switch is respected')
options.summary_sprites=nil;options.enable_battle_sprites=false
T.eq(resolve(game,mon),nil,'master switch is respected')
options.enable_battle_sprites=nil;enabled=false
T.eq(resolve(game,mon),nil,'disabled mod cannot supply art')
enabled=true
for _,choice in ipairs({'crystal','hgss'}) do
  source=choice;T.eq(resolve(game,mon),nil,'explicit alternate provider keeps priority')
end
source='default'
T.eq(type(resolve(game,mon)),'function','default uses active provider')
T.eq(resolve(game,{species='UNOWN'}),nil,'native letter renderer retained')
T.eq(resolve(game,{species='STARLY',isEgg=true}),nil,'egg keeps native renderer')
api.frontArt=function() error('missing file') end
T.eq(resolve(game,mon),nil,'failed provider lookup falls back')
api.frontArt=function() return {} end
api.drawSummaryFrame=function() error('provider draw failed') end
T.eq(resolve(game,mon)(0,0,1),false,'provider failure cannot crash the summary')
T.eq(depth,0,'error also restores graphics state')

local interfaceMode, seen, fail = 'modded', nil, false
local native = {draw=function(screen)
  seen=screen.__battleArtOriginalSprite
  if fail then error('native draw failed') end
end}
package.loaded['src.core.GameVersion']={generation=function() return 1 end}
package.loaded['src.ui.SummaryMenu']=native
local handle={exports={lib={require=function() return {setting={get=function() return interfaceMode end}} end}}}
dofile('mods/modern_ui_suite/core/summary_portraits.lua')({
  options={get=function() return 'default' end},
  find=function(id) return id=='BATTLE_ART_VOXEL_FORK' and handle
    or id=='g9-battle-sprites' and {exports=api} end,
})
local original={}
local screen={game=game,mon=mon,__battleArtOriginalCaptured=true,
  __battleArtOriginalSprite=original,__battleArtOriginalTrueColor=true}
native.draw(screen)
T.eq(seen,nil,'native Battle Art cache cannot draw under G9')
T.eq(screen.__battleArtOriginalSprite,original,'cache restored after managed draw')
T.eq(screen.__battleArtOriginalTrueColor,true,'cache colour flag restored')
options.summary_sprites=false; native.draw(screen)
T.eq(seen,original,'summary off retains original cache')
options.summary_sprites=nil;interfaceMode='battle_art';native.draw(screen)
T.eq(seen,original,'explicit Battle Art interface ownership retained')
interfaceMode='modded';screen.modernPartySummary=true;native.draw(screen)
T.eq(seen,original,'modern presenter retains its own sprite ownership')
screen.modernPartySummary=nil;api.frontArt=function() return nil,false end
native.draw(screen);T.eq(seen,original,'unavailable G9 art retains original')
api.frontArt=function() return {} end;fail=true
T.eq(pcall(native.draw,screen),false,'native draw errors propagate')
T.eq(screen.__battleArtOriginalSprite,original,'native error restores cache')
T.finish('suite_summary_portraits')
