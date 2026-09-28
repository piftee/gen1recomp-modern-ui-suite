-- The private runner installs the Translation Mod Generator's entrypoint,
-- Fusion Pixel Japanese font, and original test catalogs. None are packaged.
return function(game)
  local U=dofile(os.getenv('PC_REPO')..'/tests/drivers/util.lua')
  local Screens=require('src.ui.Screens')
  local F=require('src.render.Font')
  local Strings=require('src.core.Strings')
  local utf8=require('utf8')
  local gen2=require('src.core.GameVersion').generation()==2
  local Mon=require(gen2 and 'src.battle.gen2.Mon' or 'src.pokemon.Pokemon')
  local checks,lookups,seen,invalid=0,{},{},{}
  local function check(ok,label) assert(ok,label);checks=checks+1 end
  local function clear() while game.stack:top() do game.stack:pop() end end
  local originalLookup,originalEncode=Strings.lookup,F.encode
  Strings.lookup=function(source,...)
    lookups[source]=true
    return originalLookup(source,...)
  end
  F.encode=function(text)
    seen[text]=true
    local _,bad=utf8.len(text)
    if bad then invalid[text]=true end
    return originalEncode(text)
  end
  if gen2 then require('src.render.GbcPalette').setMode('gbc')
  else require('src.render.PaletteFX').setMode('redpp') end
  check(F.ttfActive(),'translation font is active')
  check(game.data.pokemon.BULBASAUR.name=='テストテストテスト','provider patched species record')
  local mon=Mon.new(game.data,'BULBASAUR',5)
  -- ダ ends in 0x80: a Lua byte class containing the gender symbols used to
  -- strip that byte and leave an invalid UTF-8 nickname on Gen 1's cards.
  mon.nickname='テストダ'
  mon.moves={{id='TACKLE',pp=30,maxPp=35}}
  game.save.party={mon}
  game.save.pokedex.seen.BULBASAUR=true
  local owned=game.save.pokedex.caught or game.save.pokedex.owned
  owned.BULBASAUR=true
  require('src.inventory.Bag').add(game.save,'POTION',2,game.data)
  -- These are original QA labels, not copied cartridge translations.
  game.data.strings.ATTACK='テスト';game.data.strings.DEFENSE='テスト'
  game.data.strings.SPEED='テスト';game.data.strings.SPECIAL='テスト'
  Strings.load(game.data)
  local function capture(label)
    U.wait(5)
    check(next(invalid)==nil,'all text remains valid UTF-8 on '..label)
    check(not love.window.hasFocus() and love.audio.getVolume()==0,'silent background test')
    check(U.shot(game,os.getenv('SHOT_DIR')..'/'..label..'.png'),'capture '..label)
  end
  for _,size in ipairs({{'wide',1280,720},{'compact',640,576},{'portrait',480,900}}) do
    love.window.setMode(size[2],size[3],{resizable=true,vsync=0})
    clear();seen={};lookups={};invalid={}
    local summary=gen2 and Screens.push(game,'Gen2SummaryMenu',{save=game.save,mon=mon})
      or Screens.push(game,'SummaryMenu',mon)
    capture(size[1]..'-stats')
    check(lookups.STATS and lookups.ATTACK and lookups.DEFENSE,'summary requests catalog labels')
    check(seen['テストダ'],'summary preserves entire Japanese nickname')
    check(seen['テスト'],'translated labels reach the font')
    check(not seen.ATK and not seen.DEF,'compact cards retain supplied stat translations')
    if not gen2 then
      check(seen.GRASS and seen.POISON,'types go individually through provider lookup')
      check(not seen['GRASS / POISON'],'combined type does not bypass translation')
    end
    summary.page=gen2 and require('src.ui.gen2.SummaryMenu').GREEN_PAGE or 2
    capture(size[1]..'-moves')
    check(lookups.MOVES,'moves title requests catalog label')
    clear();seen={}
    Screens.push(game,gen2 and 'Gen2PartyMenu' or 'PartyMenu',gen2 and {save=game.save} or {})
    capture(size[1]..'-party')
    check(seen['テストダ'],'party preserves entire Japanese nickname')
    clear();Screens.push(game,gen2 and 'Gen2PackMenu' or 'BagMenu',gen2 and {save=game.save,world={}} or {})
    capture(size[1]..'-bag')
    check(seen['テストテスト'],'localized item names reach the font')
    clear();Screens.push(game,gen2 and 'Gen2PokedexMenu' or 'PokedexMenu')
    capture(size[1]..'-dex')
  end
  F.encode=originalEncode;Strings.lookup=originalLookup
  print('[DISCORD QA] PASS '..checks..' translation compatibility checks');love.event.quit(0)
end
