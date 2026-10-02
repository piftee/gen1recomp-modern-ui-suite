-- Battle Art + G9; original geometric test artwork, no distributed sprites.
return function(game)
  local U=dofile(os.getenv('PC_REPO')..'/tests/drivers/util.lua')
  local Screens=require('src.ui.Screens')
  local Mon=require('src.pokemon.Pokemon')
  local suite=game.mods.modOptions.modern_ui_suite
  game.mods.modOptions['g9-battle-sprites']=game.mods.modOptions['g9-battle-sprites'] or {}
  local opts=game.mods.modOptions['g9-battle-sprites']
  require('src.render.PaletteFX').setMode('redpp')
  suite['party.enabled']=false
  local checks=0
  local function check(ok,label) assert(ok,label);checks=checks+1 end
  local function open(species)
    while game.stack:top() do game.stack:pop() end
    local mon=Mon.new(game.data,species,30);game.save.party={mon}
    local s=Screens.push(game,'SummaryMenu',mon);s.whiteHold=0
    return s
  end
  local s=open('ALAKAZAM')
  check(not s.modernPartySummary,'party component is disabled')
  local native=s.sprite
  local draw=love.graphics.draw
  local originals=0
  love.graphics.draw=function(img,...)
    if img==native then originals=originals+1 end
    return draw(img,...)
  end
  local function observe(label,expectOriginal)
    U.wait(90);originals=0;U.wait(30)
    check((originals>0)==expectOriginal,label..' original picture visibility')
    local path=os.getenv('SHOT_DIR')..'/'..label..'.png'
    check(U.shot(game,path),'capture '..label)
    if not expectOriginal then
      local file=assert(io.open(path,'rb'));local bytes=file:read('*a');file:close()
      local image=love.image.newImageData(love.filesystem.newFileData(bytes,'capture.png'))
      local colored=0
      for y=0,image:getHeight()-1,3 do for x=0,image:getWidth()-1,3 do
        local r,g,b=image:getPixel(x,y)
        if (math.abs(r-240/255)<.02 and math.abs(g-45/255)<.02 and math.abs(b-100/255)<.02)
          or (math.abs(r-25/255)<.02 and math.abs(g-210/255)<.02 and math.abs(b-225/255)<.02) then colored=colored+1 end
      end end
      check(colored>50,label..' provider RGB actually visible')
    end
  end
  observe('g9-managed',false)
  opts.summary_sprites=false;observe('summary-off',true)
  local cached=s.__battleArtOriginalSprite
  opts.summary_sprites=true;observe('summary-on',false)
  check(s.__battleArtOriginalSprite==cached,'Battle Art cache restored after managed draw')
  opts.enable_battle_sprites=false;observe('master-off',true)
  opts.enable_battle_sprites=true;opts.dex_sprites=false;observe('dex-off',false)
  s=open('BULBASAUR');native=s.sprite;observe('missing-art',true)
  check(not love.window.hasFocus() and love.audio.getVolume()==0,'silent background test')
  love.graphics.draw=draw
  print('[DISCORD QA] PASS '..checks..' native summary overlap checks')
  love.event.quit(0)
end
