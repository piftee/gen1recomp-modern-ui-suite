-- Scoped Gen 2 HUD/category adapters must never change native controllers or
-- leak their temporary drawing overrides into another screen, including errors.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local rectangles,glyphs,colors={},{},{}
local depth=0
local G={
 push=function()depth=depth+1 end,pop=function()depth=depth-1 end,
 setShader=function()end,translate=function()end,
 setColor=function(...)colors={...}end,
 rectangle=function(...)rectangles[#rectangles+1]={...}end,
 transformPoint=function(x,y)return x*2,y*2 end,
}
love.graphics=G
local Font={TTF_BASE=0x400000, useBattleExtra=function()return false end,
 width=function(t)return #t*8 end,advanceOf=function()return 8 end,
 encode=function(t)local r={}for i=1,#t do r[i]=t:byte(i)end return r end,
 drawCode=function(code,x,y)glyphs[#glyphs+1]={code=code,x=x,y=y,ink=colors[1]}end,
}
local Chrome={DEFAULT_BOX_PALETTE={{255,255,255},{170,170,170},{85,85,85},{0,0,0}}}
local function nativeGlyphs(pal)
 return pal,function(code,x,y)
  glyphs[#glyphs+1]={code=code,x=x,y=y,ink=pal[4][1]}
 end,function()end
end
Chrome.paletteGlyphs=nativeGlyphs
local nativeTextCalls=0
Chrome.printThrough=function()nativeTextCalls=nativeTextCalls+1 end
Chrome.printRightThrough=Chrome.printThrough
package.loaded['src.render.Font']=Font
package.loaded['src.ui.gen2.Chrome']=Chrome
package.loaded['src.mods.Runtime']={}
local pushed,enabled,staged=nil,true,true
local screen
local mod={
 options={get=function(_,k)if k=='enabled'then return enabled end end},
 load=function(_,f)return dofile('mods/modern_ui_suite/components/battle_info_hud/'..f)end,
 events={on=function(_,_,fn)pushed=fn end},hooks={wrap=function()end},
 exports={},log={info=function()end},
 find=function(id)if id=='BATTLE_ART_VOXEL_GEN2' then return {exports={battleStage={state=function(expected)
  if staged and expected==screen then return {battle=screen,staged=true,ownership={arena=true}}end
 end}}}end end,
}
dofile('mods/modern_ui_suite/components/battle_info_hud/gen2.lua')(mod)
local nativeFrames,nativeExps=0,0
local player={level=5}
screen={screenId='Gen2BattleState',showEnemyHud=true,showPlayerHud=true,
 activeMon=function()return player end,statusHUDVisible=function()return true end,
 hudCleared=function()return false end,statusTag=function()return nil end,
 drawPlayerHud=function(self)
  Chrome.printThrough('NAME',10,7,Chrome.DEFAULT_BOX_PALETTE)
  Chrome.printRightThrough('20/20',18,10,Chrome.DEFAULT_BOX_PALETTE)
  self.hud:drawPlayerFrame();self.hud:drawExpBar(0.5,10,11)
  return 'native-result'
 end,
 drawWidescreen=function()end,
 hud={drawPlayerFrame=function()nativeFrames=nativeFrames+1 end,
  drawEnemyFrame=function()nativeFrames=nativeFrames+1 end,
  drawExpBar=function()nativeExps=nativeExps+1;return 'native-exp'end},
}
local printThrough,printRight=Chrome.printThrough,Chrome.printRightThrough
pushed({state=screen})
T.eq(screen:drawPlayerHud(),'native-result','HUD preserves native draw result')
T.eq(nativeFrames,0,'terrain HUD has no cartridge L border')
T.eq(nativeTextCalls,0,'native text entry points receive scoped styling')
T.eq(#rectangles,2,'only slim EXP track and fill rectangles, no HUD backing')
T.same(rectangles[2],{'fill',112,91,32,2},'half EXP fills from native right edge')
T.eq(screen.modernStagedExpPixels,32,'EXP consumes native fraction')
T.eq(#glyphs,45,'every glyph has four outline passes and one light face')
T.eq(glyphs[1].ink,0,'outline has dark ink')
T.eq(glyphs[5].ink,255,'glyph face has light ink')
T.eq(glyphs[21].x,103,'numeric HP retains native right alignment plus outline')
T.eq(Chrome.paletteGlyphs,nativeGlyphs,'glyph function is restored')
T.eq(Chrome.printThrough,printThrough,'print function is restored')
T.eq(Chrome.printRightThrough,printRight,'right-aligned print is restored')
T.eq(depth,0,'graphics stack balanced')
for _,fraction in ipairs({-1,0,1,2})do
 rectangles={};screen.hud:drawExpBar(fraction,10,11)
 T.eq(screen.modernStagedExpPixels,math.max(0,math.min(64,fraction*64)),'EXP is clamped '..fraction)
end
for _,mode in ipairs({'disabled','inactive','stadium'})do
 enabled=mode~='disabled';staged=mode~='inactive';screen.stadium2ImporterBattleArtUiPass=mode=='stadium'
 rectangles={};glyphs={};screen:drawPlayerHud()
 T.eq(#rectangles,0,mode..' retains native HUD')
 T.eq(#glyphs,0,mode..' has no styled glyphs')
 T.eq(screen.modernStagedExpPixels,nil,mode..' clears staged EXP ownership')
end
T.eq(nativeFrames,3,'native frames delegate in all fallback paths')
T.eq(nativeExps,3,'native EXP delegates in all fallback paths')
enabled,staged,screen.stadium2ImporterBattleArtUiPass=true,true,nil
-- Install a second instance whose native draw throws in the scoped print.
local failing={}
for key,value in pairs(screen)do failing[key]=value end
failing.modernBattleWideInstalled=nil
failing.drawPlayerHud=function()Chrome.printThrough('X',0,0,Chrome.DEFAULT_BOX_PALETTE);error('native HUD failure')end
screen=failing;pushed({state=screen})
T.eq(pcall(screen.drawPlayerHud,screen),false,'HUD draw failure propagates')
T.eq(Chrome.paletteGlyphs,nativeGlyphs,'failure restores glyph function')
T.eq(Chrome.printThrough,printThrough,'failure restores print function')
T.eq(Chrome.printRightThrough,printRight,'failure restores alignment function')
T.eq(depth,0,'failure balances graphics state')

package.loaded['src.render.GbcPalette']={}
package.loaded['src.ui.gen2.SummaryMenu']={}
local options,categoryOn,categoryPresent={battle_colors=true},true,true
local movePushed
local moveMod={
 options={enabled=function()return true end,get=function(_,k)return options[k]end},
 find=function()if categoryPresent then return {exports={
  moveCategoryReadoutEnabled=function()return categoryOn end,
  getMoveCategory=function()return 'physical'end}}end end,
 events={on=function(_,_,fn)movePushed=fn end},hooks={wrap=function()end},
 content={screens={get=function()end,register=function()end}},exports={},log={info=function()end},
}
dofile('mods/modern_ui_suite/components/typed_move_colors/gen2.lua')(moveMod)
local nativeRectangle,nativeCode=G.rectangle,Font.drawCode
local moveScreen={screenId='Gen2BattleState',phase='moves',moveIndex=1,
 game={data={moves={SCRATCH={}}}},playerMoves=function()return {{id='SCRATCH'}}end,
 draw=function()
  G.rectangle('fill',64,96,80,8);Font.drawCode(1,72,96);Font.drawCode(1,73,97)
  G.rectangle('fill',1,96,8,8);Font.drawCode(2,60,96);Font.drawCode(3,72,104)
  return 'native-moves'
 end,
}
movePushed({state=moveScreen})
rectangles,glyphs={},{}
T.eq(moveScreen:draw(),'native-moves','category scope retains draw result')
T.eq(#rectangles,1,'only legacy category paper is suppressed')
T.eq(#glyphs,2,'category scope preserves unrelated glyph positions')
T.eq(G.rectangle,nativeRectangle,'category scope restores rectangle function')
T.eq(Font.drawCode,nativeCode,'category scope restores font function')
for _,mode in ipairs({'off','absent','native','message'})do
 categoryOn=mode~='off';categoryPresent=mode~='absent';options.text_only=mode=='native'
 moveScreen.phase=mode=='message' and 'resolving' or 'moves'
 rectangles,glyphs={},{};moveScreen:draw()
 T.eq(#rectangles,2,mode..' leaves original category paper available')
 T.eq(#glyphs,4,mode..' leaves original category glyphs available')
end
categoryOn,categoryPresent,options.text_only=true,true,false
moveScreen={screenId='Gen2BattleState',phase='moves',moveIndex=1,game=moveScreen.game,
 playerMoves=moveScreen.playerMoves,draw=function()error('native battle failure')end}
movePushed({state=moveScreen})
T.eq(pcall(moveScreen.draw,moveScreen),false,'category draw failure propagates')
T.eq(G.rectangle,nativeRectangle,'category failure restores rectangles')
T.eq(Font.drawCode,nativeCode,'category failure restores glyphs')
T.eq(moveScreen.typedMoveCategoryScopeActive,nil,'category failure clears scope guard')
T.finish('Gen2 staged HUD and category ownership')
