-- Run with National Dex, G9, and original geometric sprite fixtures.
return function(game)
  local U=dofile(os.getenv('PC_REPO')..'/tests/drivers/util.lua')
  local Screens=require('src.ui.Screens')
  local Runtime=require('src.mods.Runtime')
  local gen2=require('src.core.GameVersion').generation()==2
  local Mon=require(gen2 and 'src.battle.gen2.Mon' or 'src.pokemon.Pokemon')
  local suite=game.mods.modOptions.modern_ui_suite
  game.mods.modOptions['g9-battle-sprites']=game.mods.modOptions['g9-battle-sprites'] or {}
  local opts=game.mods.modOptions['g9-battle-sprites']
  local api=game.mods.exports['g9-battle-sprites']
  local checks,drawn,recolored,tracking=0,0,0,false
  local images,known={},{}
  local pictureHeight=0
  local function check(ok,label) assert(ok,label);checks=checks+1 end
  local originalCall,originalDraw=Runtime.call,love.graphics.draw
  Runtime.call=function(hook,nextFn,...)
    local result=originalCall(hook,nextFn,...)
    if hook=='battle.mon_pic' and result and result.typeOf and result:typeOf('Image') then known[result]=true end
    return result
  end
  local originalSummary=api.drawSummaryFrame
  if originalSummary then
    api.drawSummaryFrame=function(...)
      tracking=true
      local ok,result=pcall(originalSummary,...)
      tracking=false
      assert(ok,result)
      return result
    end
  end
  love.graphics.draw=function(img,...)
    if tracking or known[img] then
      drawn=drawn+1;images[img]=true
      local args={...}
      pictureHeight=img:getHeight()*math.abs(args[5] or args[4] or 1)
      if love.graphics.getShader() then recolored=recolored+1 end
    end
    return originalDraw(img,...)
  end
  if gen2 then require('src.render.GbcPalette').setMode('gbc')
  else require('src.render.PaletteFX').setMode('redpp') end
  suite.menu_sprite_source='battle_art'
  local mon=Mon.new(game.data,'STARLY',3)
  mon.nickname='BIRB';mon.shiny=false;mon.gender='male'
  game.save.party={mon}
  while game.stack:top() do game.stack:pop() end
  local summary=gen2 and Screens.push(game,'Gen2SummaryMenu',{save=game.save,mon=mon})
    or Screens.push(game,'SummaryMenu',mon)
  local function observe(label,expected,capture)
    drawn,recolored,images=0,0,{}
    U.wait(90)
    check((drawn>0)==expected,label..' artwork visibility')
    check(recolored==0,label..' preserves provider RGB')
    check(not love.window.hasFocus() and love.audio.getVolume()==0,'silent background test')
    if capture then check(U.shot(game,os.getenv('SHOT_DIR')..'/'..label..'.png'),'capture '..label) end
    check(mon.__g9bsLogged==nil,'provider does not mutate saved mon')
  end
  love.window.setMode(1280,720,{resizable=true,vsync=0})
  observe('stats-normal',true,true)
  local count=0;for _ in pairs(images) do count=count+1 end
  check(count>1,'summary animates provider frames')
  if originalSummary then
    local full=pictureHeight
    opts.summary_size=50;observe('half-size',true)
    check(math.abs(pictureHeight-full/2)<.01,'provider summary size is respected')
    opts.summary_size=100
  end
  opts.dex_sprites=false;observe('dex-disabled',true)
  opts.summary_sprites=false;observe('summary-disabled',false)
  opts.summary_sprites=true;opts.enable_battle_sprites=false;observe('master-disabled',false)
  opts.enable_battle_sprites=true
  mon.shiny=true;mon.gender='female'
  observe('stats-shiny-female',true,true)
  opts.animate_sprites=false;observe('animation-disabled',true)
  count=0;for _ in pairs(images) do count=count+1 end
  check(count==1,'animation off holds one frame')
  summary.page=gen2 and require('src.ui.gen2.SummaryMenu').GREEN_PAGE or 2
  observe('moves',true,true)
  love.window.setMode(480,900,{resizable=true,vsync=0})
  observe('portrait',true,true)
  love.window.setMode(640,576,{resizable=true,vsync=0})
  observe('compact',true,true)
  local original=summary.mon
  summary.mon=Mon.new(game.data,'LATIAS',5)
  -- No LATIAS art in a missing-art test would fall back; the runner also
  -- supplies it for the Dex regressions, so use an unprovided native species.
  summary.mon=Mon.new(game.data,'BULBASAUR',5)
  observe('native-fallback',false,true)
  summary.mon=original
  love.graphics.draw=originalDraw;Runtime.call=originalCall
  if originalSummary then api.drawSummaryFrame=originalSummary end
  print('[DISCORD QA] PASS '..checks..' summary portrait checks');love.event.quit(0)
end
