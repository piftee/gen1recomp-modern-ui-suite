-- Capture the real tabbed Pokédex, reached from its index.
return function(game)
 local U=dofile(assert(os.getenv('PC_REPO'))..'/tests/drivers/util.lua')
 local Screens=require('src.ui.Screens')
 local gen2=require('src.core.GameVersion').generation()==2
 print('[DEX PARITY] start')
 local opts=game.mods.modOptions.modern_ui_suite
 local checks=0
 local function check(ok,label) checks=checks+1;assert(ok,label);print('[DEX PARITY] '..label) end
 local function press(menu,key)
  local old=game.input
  game.input=setmetatable({wasPressed=function(_,k) return k==key end,isDown=function() return false end},{__index=old})
  local ok,err=pcall(menu.update,menu,0);game.input=old;assert(ok,err)
 end
 game.save.pokedex.owned=game.save.pokedex.owned or {}
 for id in pairs(game.data.pokemon) do
  game.save.pokedex.seen[id]=true
  game.save.pokedex.owned[id]=true
  if game.save.pokedex.caught then game.save.pokedex.caught[id]=true end
 end
 local provider=game.mods.exports.BATTLE_ART_VOXEL_GEN2 or game.mods.exports.BATTLE_ART_VOXEL_FORK
 if provider then
  local art=provider.battleArt or provider.lib.require('BattleArt')
  art.duplicateSetting:setIndex(1,game);art.setting:sync('animated');art.frontAnimationSetting:setIndex(4,game)
  opts.menu_sprite_source='battle_art'
 end
 local function shot(name,w,h)
  if w then love.window.setMode(w,h,{resizable=true,vsync=0}) end
  print('[DEX PARITY] waiting '..name)
  U.wait(3)
  print('[DEX PARITY] shooting '..name)
  check(U.shot(game,os.getenv('SHOT_DIR')..'/'..name..'.png'),'captured '..name)
  check(not love.window.hasFocus() and love.audio.getVolume()==0,'muted and unfocused')
 end
 local function open(species)
  print('[DEX PARITY] opening '..species)
  while game.stack:top() do game.stack:pop() end
  local list=Screens.push(game,gen2 and 'Gen2PokedexMenu' or 'PokedexMenu')
  print('[DEX PARITY] list constructed')
  for i,row in ipairs(gen2 and list.rows or list.modernDexEntries) do
   if (row.species or row.def.id)==species then list.index=i;list.scroll=math.max(0,i-3);break end
  end
  if gen2 then list:ensureVisible() end
  return list
 end
 love.window.setMode(1280,720,{resizable=true,vsync=0})
 print('[DEX PARITY] window ready')
 for _,ratio in ipairs({'16:9','4:3'}) do
  opts['pokedex.aspect_ratio']=ratio
  local list=open('BEEDRILL');shot('list-'..ratio:gsub(':','x'))
  local entry
  if gen2 then
   press(list,'a');check(list.modernGen2Actions~=nil,'index opens actions');shot('actions-'..ratio:gsub(':','x'))
   press(list,'a');entry=list
  else entry=Screens.push(game,'DexEntryMenu','BEEDRILL') end
  U.wait(3)
  local state=entry.modernGen2Presentation or entry
  check(state.modernDexTabbed,'entry uses top tabs')
  for i,page in ipairs(state.modernDexPages) do
   state.modernDexPage=i
   shot(page.id..'-'..ratio:gsub(':','x'))
   if page.id=='moves' then
    check(#(state.modernMoveRows or {})>0,'native learnset is available')
    press(entry,'a');shot('move-detail-'..ratio:gsub(':','x'));press(entry,'b')
    check(not state.modernMoveDetail,'B returns to move list')
   end
  end
  if gen2 then
   state.modernDexPage=1;U.wait(2)
   press(entry,'down');check(state.modernInfoScroll>0,'Down scrolls complete field notes')
   shot('notes-scrolled-'..ratio:gsub(':','x'))
   press(entry,'right');check(state.modernDexPage==2,'Right changes tab without confirmation')
   press(entry,'left');check(state.modernInfoScroll==0,'returning to INFO resets notes')
   press(entry,'b');check(entry.view=='list','B returns to index')
   press(entry,'select');check(entry.view=='search','Select opens native search');press(entry,'b')
   press(entry,'start');check(entry.view=='option','Start opens native options');press(entry,'b')
   press(entry,'a');press(entry,'down');press(entry,'a')
   check(entry.view=='area','AREA action retains native map');shot('area-'..ratio:gsub(':','x'))
   press(entry,'b');check(entry.view=='list','AREA returns to index')
  end
 end
 if gen2 then
  opts['pokedex.aspect_ratio']='16:9'
  local menu=open('EEVEE');press(menu,'a');press(menu,'a');U.wait(2)
  local state=menu.modernGen2Presentation
  for i,page in ipairs(state.modernDexPages) do if page.id=='family' then state.modernDexPage=i end end
  shot('family-eevee');press(menu,'up');shot('family-umbreon')
  check(state.modernDexFamily[state.modernFamilyCursor].def.id=='UMBREON','Up wraps to Umbreon')
  press(menu,'a');U.wait(2);check(menu:current().species=='UMBREON','A opens selected family member')
  game.save.pokedex.seen.UMBREON=nil;game.save.pokedex.caught.UMBREON=nil;game.save.pokedex.owned.UMBREON=nil
  menu=open('EEVEE');press(menu,'a');press(menu,'a');U.wait(2);state=menu.modernGen2Presentation
  for i,page in ipairs(state.modernDexPages) do if page.id=='family' then state.modernDexPage=i end end
  press(menu,'up');shot('family-undiscovered');press(menu,'a')
  check(menu:current().species=='EEVEE','unseen relative cannot be opened')
  opts['pokedex.theme']='dark';shot('family-dark');opts['pokedex.theme']='light'
  opts['pokedex.aspect_ratio']='4:3';shot('family-portrait',480,900)
  press(menu,'b');press(menu,'a');press(menu,'a');shot('info-portrait')
  opts['pokedex.responsive']=false;shot('info-native',800,720)
  press(menu,'right');shot('stats-native')
  opts['pokedex.responsive']=true
  local catch=Screens.push(game,'Gen2PokedexMenu',{entrySpecies='RAICHU',newEntry=true,onClose=function() game.stack:pop() end})
  shot('new-entry',1280,720)
  check(not catch.modernGen2Presentation.modernDexTabbed,'new catches retain standalone INFO')
  press(catch,'b');U.wait(2);check(catch.page==2,'native catch sequence advances to page 2')
  press(catch,'b');check(game.stack:top()~=catch,'native catch sequence closes normally')
  while game.stack:top() do game.stack:pop() end
  game.save.options.modOptions=game.save.options.modOptions or {}
  local saved=game.save.options.modOptions.modern_ui_suite or {}
  game.save.options.modOptions.modern_ui_suite=saved
  opts['pokedex.enabled']=false;saved['pokedex.enabled']=false;Screens.invalidate()
  local native=Screens.build(game,'Gen2PokedexMenu')
  check(not native.modernPokedexGeneration,'OFF restores native Pokedex')
  opts['pokedex.enabled']=true;saved['pokedex.enabled']=true;Screens.invalidate()
  local restored=Screens.build(game,'Gen2PokedexMenu')
  check(restored.modernPokedexGeneration==2,'ON restores shared presentation')
 end
 print('[DISCORD QA] PASS '..checks..' Pokedex parity checks');love.event.quit(0)
end
