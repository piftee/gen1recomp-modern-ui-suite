return function(game)
  local U=dofile(assert(os.getenv('PC_REPO'))..'/tests/drivers/util.lua')
  local Screens=require('src.ui.Screens')
  local gen2=require('src.core.GameVersion').generation()==2
  local suite=game.mods.exports.modern_ui_suite
  local opts=game.mods.modOptions.modern_ui_suite
  local checks=0
  local function check(ok,label) checks=checks+1;assert(ok,label);print('[SHINY DEX] '..label) end
  local function press(menu,key)
    local old=game.input
    game.input=setmetatable({wasPressed=function(_,k)return k==key end,isDown=function()return false end},{__index=old})
    local ok,err=pcall(menu.update,menu,0);game.input=old;assert(ok,err)
  end
  local function shot(name)
    U.wait(3);check(U.shot(game,os.getenv('SHOT_DIR')..'/'..name..'.png'),'captured '..name)
    check(not love.window.hasFocus() and love.audio.getVolume()==0,'muted and unfocused')
  end
  local function open()
    while game.stack:top() do game.stack:pop() end
    return Screens.push(game,gen2 and 'Gen2PokedexMenu' or 'PokedexMenu')
  end
  game.save.party={};game.save.boxes={}
  game.save.modData.modern_ui_suite=game.save.modData.modern_ui_suite or {}
  game.save.modData.modern_ui_suite.shinyDex={}
  game.save.pokedex.owned=game.save.pokedex.owned or {}
  for id in pairs(game.data.pokemon) do
    game.save.pokedex.seen[id]=true;game.save.pokedex.owned[id]=true
    if game.save.pokedex.caught then game.save.pokedex.caught[id]=true end
  end
  opts['pokedex.aspect_ratio']='4:3'
  love.window.setMode(1088,480,{resizable=true,vsync=0})
  local list=open();press(list,'right');shot('empty-shiny')
  check(#(gen2 and list.rows or list.modernDexEntries)==0,'ordinary catches do not fill shiny filter')
  press(list,'up');press(list,'down');press(list,'left')
  check(#(gen2 and list.rows or list.modernDexEntries)>100,'empty filter can return to all entries')
  suite.shinyDex.record(game,{species='EEVEE',shiny=true})
  suite.shinyDex.record(game,{species='VAPOREON',dvs={attack=14,defense=10,speed=10,special=10}})
  for _,ratio in ipairs({'4:3','16:9'}) do
    opts['pokedex.aspect_ratio']=ratio;list=open()
    local rows=gen2 and list.rows or list.modernDexEntries
    for i,row in ipairs(rows) do if (row.species or row.def.id)=='EEVEE' then list.index=i;list.scroll=math.max(0,i-3);break end end
    shot('all-'..ratio:gsub(':','x'))
    press(list,'right');shot('shiny-'..ratio:gsub(':','x'))
    rows=gen2 and list.rows or list.modernDexEntries
    check(#rows==2,'filter contains exactly two known shiny species')
    for _,row in ipairs(rows) do check(suite.shinyDex.has(game,row.species or row.def.id),'every filtered row has capture evidence') end
    press(list,'a');shot('actions-'..ratio:gsub(':','x'))
    local entry
    if gen2 then press(list,'a');entry=list else press(game.stack:top(),'a');entry=game.stack:top() end
    shot('entry-'..ratio:gsub(':','x'))
    check(gen2 and entry.view=='entry' or entry.modernPokedexEntry,'shiny result opens native entry')
    press(entry,'b');press(list,'left')
    check(#(gen2 and list.rows or list.modernDexEntries)>100,'all entries restored after entry return')
    press(list,'select');shot('search-'..ratio:gsub(':','x'))
    check(gen2 and list.view=='search' or list.modernDexSearchOpen,'search remains reachable')
  end
  print('[DISCORD QA] PASS '..checks..' shiny dex checks');love.event.quit(0)
end
