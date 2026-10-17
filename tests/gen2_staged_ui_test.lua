-- Scoped Gen 2 HUD/category adapters must never change native controllers or
-- leak their temporary drawing overrides into another screen, including errors.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local rectangles,glyphs,colors,paint={},{},{},{}
local failRectangle=false
local depth=0
local G={
 push=function()depth=depth+1 end,pop=function()depth=depth-1 end,
 setShader=function()end,translate=function()end,
 setColor=function(...)colors={...}end,
 rectangle=function(...)
  if failRectangle then error('rectangle failure') end
  rectangles[#rectangles+1]={...};paint[#paint+1]=colors
 end,
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
local boxes=0
Chrome.paletteBox=function()boxes=boxes+1 end
package.loaded['src.render.Font']=Font
package.loaded['src.ui.gen2.Chrome']=Chrome
package.loaded['src.mods.Runtime']={}
local pushed,enabled,staged,counterEnabled=nil,true,true,false
local screen
local mod={
 options={get=function(_,k)if k=='enabled'then return enabled elseif k=='enemy_hp_counter'then return counterEnabled end end},
 load=function(_,f)return dofile('mods/modern_ui_suite/components/battle_info_hud/'..f)end,
 events={on=function(_,_,fn)pushed=fn end},hooks={wrap=function()end},
 exports={},log={info=function()end},
 find=function(id)if id=='BATTLE_ART_VOXEL_GEN2' then return {exports={battleStage={state=function(expected)
  if staged and expected==screen then return {battle=screen,staged=true,ownership={arena=true}}end
 end}}}end end,
}
dofile('mods/modern_ui_suite/components/battle_info_hud/gen2.lua')(mod)
local nativeFrames,nativeExps=0,0
local tiles={}
local player={level=5,hp=1,maxHp=20}
screen={screenId='Gen2BattleState',showEnemyHud=true,showPlayerHud=true,game={data={}},
 hudHp=function(_,mon)return mon.hp end,drawHpBar=function()return 'native-bar'end,
 activeMon=function()return player end,statusHUDVisible=function()return true end,
 hudCleared=function()return false end,statusTag=function()return nil end,
 drawPlayerHud=function(self)
  Chrome.printThrough('NAME',10,7,Chrome.DEFAULT_BOX_PALETTE)
  Chrome.printRightThrough('20/20',18,10,Chrome.DEFAULT_BOX_PALETTE)
  self.hud:drawPlayerFrame();self.hud:drawExpBar(0.5,10,11)
  return 'native-result'
 end,
 drawBottom=function()
  Chrome.printThrough('FIGHT',10,14,Chrome.DEFAULT_BOX_PALETTE)
  Chrome.printRightThrough('MSG',18,16,Chrome.DEFAULT_BOX_PALETTE)
  return 'native-bottom'
 end,
 drawWidescreen=function()end,
 hud={drawTile=function(_,key,first,tile,tx,ty,palette)
   tiles[#tiles+1]={key=key,first=first,tile=tile,tx=tx,ty=ty,palette=palette}
   return 'native-tile'
  end,
  drawCaughtIcon=function(self,tx,ty)return self:drawTile('expBar',0x54,0x5d,tx,ty,{})end,
  drawPlayerFrame=function()nativeFrames=nativeFrames+1 end,
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
for _,phase in ipairs({'menu','resolving','ask-nickname','choose-forget','stats-box'})do
 screen.phase=phase;rectangles,glyphs={},{}
 T.eq(screen:drawBottom(),'native-bottom',phase..' preserves native bottom result')
 T.eq(#glyphs,40,phase..' uses the same outline as the upper HUD')
 T.eq(glyphs[5].ink,255,phase..' has a light face')
 T.eq(#rectangles,0,phase..' text styling adds no backing panel')
 T.eq(Chrome.printThrough,printThrough,phase..' restores the printer')
end
for _,phase in ipairs({'moves','moveSelect'})do
 screen.phase=phase;glyphs={};screen:drawBottom()
 T.eq(#glyphs,0,phase..' leaves move ink with its own presenter')
end
screen.phase='menu'
local nativeBox=Chrome.paletteBox
local popup=screen.modernBattleOutlineBottom(function()
 Chrome.paletteBox(14,7,6,5)
 Chrome.paletteBox(0,12,20,6)
end)
rectangles,paint={},{};boxes=0;popup(screen)
T.eq(boxes,2,'native popup and main box renderers both run')
T.eq(#rectangles,1,'only the popup gains a solid background')
T.same(rectangles[1],{'fill',112,56,48,40},'popup fill uses the native tile bounds')
T.same(paint[1],{0.10,0.12,0.16,1},'popup fill is opaque')
T.eq(Chrome.paletteBox,nativeBox,'popup box function is restored')
Chrome.paletteBox=function()error('popup failure')end
local throwingBox=Chrome.paletteBox
T.eq(pcall(popup,screen),false,'popup renderer failure propagates')
T.eq(Chrome.paletteBox,throwingBox,'failure restores exact inherited box renderer')
T.eq(depth,0,'popup failure balances graphics state')
Chrome.paletteBox=nativeBox
counterEnabled=true
local rectangle=G.rectangle
local filtered=0
local filter=function(...)
 local color=type(colors[1])=='table' and colors[1] or colors
 if color[1]==1 and color[2]==1 and color[3]==1 then filtered=filtered+1;return end
 return rectangle(...)
end
G.rectangle=filter;paint={};rectangles={}
T.eq(screen:drawHpBar(player,'enemy',2,2),'native-bar','enemy meter retains native result')
T.eq(filtered,0,'white HP digits bypass the provider paper filter')
local white=0
for _,color in ipairs(paint)do
 color=type(color[1])=='table' and color[1] or color
 if color[1]==1 and color[2]==1 and color[3]==1 then white=white+1 end
end
T.check(white>0,'low HP digits have a white face')
local barOnly=true
for _,rect in ipairs(rectangles)do if rect[2]<32 then barOnly=false end end
T.check(barOnly,'staged meter preserves the native HP label')
T.eq(screen.modernStagedEnemyMeter,true,'enemy meter records ownership in the HUD pass')
T.eq(G.rectangle,filter,'meter restores the inherited paper filter')
failRectangle=true
T.eq(pcall(screen.drawHpBar,screen,player,'enemy',2,2),false,'meter drawing failure propagates')
T.eq(G.rectangle,filter,'meter failure restores inherited graphics function')
T.eq(depth,0,'meter failure balances graphics state')
failRectangle=false;G.rectangle=rectangle;counterEnabled=false
tiles={}
T.eq(screen.hud:drawCaughtIcon(1,1),'native-tile','caught icon keeps its native result')
T.eq(#tiles,5,'native caught tile has four outline passes and one face')
T.eq(tiles[1].palette[4][1],0,'caught outline is black')
T.eq(tiles[5].palette[4][1],255,'caught face is white')
T.eq(tiles[5].tile,0x5d,'caught styling uses the original tile')
local tileDraw=screen.hud.drawTile
local tileFailure=function()error('tile failure')end
screen.hud.drawTile=tileFailure
T.eq(pcall(screen.hud.drawCaughtIcon,screen.hud,1,1),false,'caught tile failure propagates')
T.eq(screen.hud.drawTile,tileFailure,'caught failure restores the inherited tile renderer')
T.eq(depth,0,'caught failure balances graphics state')
screen.hud.drawTile=tileDraw
for _,fraction in ipairs({-1,0,1,2})do
 rectangles={};screen.hud:drawExpBar(fraction,10,11)
 T.eq(screen.modernStagedExpPixels,math.max(0,math.min(64,fraction*64)),'EXP is clamped '..fraction)
end
for _,mode in ipairs({'disabled','inactive','stadium'})do
 enabled=mode~='disabled';staged=mode~='inactive';screen.stadium2ImporterBattleArtUiPass=mode=='stadium'
 rectangles={};glyphs={};screen.phase='menu';screen:drawPlayerHud();screen:drawBottom()
 T.eq(screen.modernStagedDialogueOutlined,nil,mode..' leaves dialogue native')
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
failing.drawBottom=function()Chrome.printThrough('X',0,0,Chrome.DEFAULT_BOX_PALETTE);error('native bottom failure')end
screen=failing;pushed({state=screen})
T.eq(pcall(screen.drawPlayerHud,screen),false,'HUD draw failure propagates')
T.eq(Chrome.paletteGlyphs,nativeGlyphs,'failure restores glyph function')
T.eq(Chrome.printThrough,printThrough,'failure restores print function')
T.eq(Chrome.printRightThrough,printRight,'failure restores alignment function')
T.eq(depth,0,'failure balances graphics state')

T.eq(pcall(screen.drawBottom,screen),false,'bottom draw failure propagates')
T.eq(Chrome.paletteGlyphs,nativeGlyphs,'bottom failure restores glyph function')
T.eq(Chrome.printThrough,printThrough,'bottom failure restores print function')
T.eq(Chrome.printRightThrough,printRight,'bottom failure restores alignment function')
T.eq(screen.modernStagedTextScopeActive,nil,'bottom failure clears the scope guard')
T.eq(depth,0,'bottom failure balances graphics state')
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
