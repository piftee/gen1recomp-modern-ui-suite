-- Integration against the unmodified Battle Art 2.1.0 release, with a fresh QA save.
return function(game)
  local U = dofile(assert(os.getenv("PC_REPO")) .. "/tests/drivers/util.lua")
  local Save = require("src.core.gen2.Save")
  local Mon = require("src.battle.gen2.Mon")
  local Battle = require("src.battle.gen2.Battle")
  local View = require("src.ui.gen2.BattleAnimView")
  local Screens = require("src.ui.Screens")
  local World = require("src.world.gen2.World")
  local api = assert(game.mods.exports.BATTLE_ART_VOXEL_GEN2, "Battle Art release must load")
  assert(api.version == "2.1.0")
  local staged = api.lib.require("OverworldBattle")
  local checks = 0
  local function check(ok, message)
    assert(ok, "BATTLE ART QA: " .. message)
    checks = checks + 1
  end
  love.window.setMode(1280, 720, { resizable = true })
  while game.stack:top() do game.stack:pop() end
  game.save = Save.newGame({ playerName = "VOXEL QA", trainerId = 4321 })
  game.save.options = game.options or game.save.options or {}
  game.save.options.musicVol, game.save.options.sfxVol, game.save.options.pikaVol = 0, 0, 0
  game.save.party = { Mon.new(game.data, "TOTODILE", 5) }
  local options = game.mods.modOptions.modern_ui_suite
  options["battle_hud.enabled"], options["move_colors.enabled"] = true, true
  local world = game.world or World.new(game)
  game.world = world
  if not world.maps then assert(world:load()) end
  assert(world:setMap("ROUTE_29", 12, 8, "down"), "real outdoor map loads")
  api.lib.require("Gen2WorldAdapter").prepareWorld(world)
  local battle = Battle.new({ data = game.data, save = game.save, party = game.save.party,
    wild = Mon.new(game.data, "SENTRET", 5), random = function() return 0 end })
  local screen = Screens.push(game, "Gen2BattleState", { save = game.save, battle = battle,
    onDone = function() end })
  screen.slideFrame = View.SLIDE_FRAMES
  screen.showPlayerTrainer, screen.showEnemyTrainer = false, false
  screen.showEnemyHud, screen.showPlayerHud = true, true
  screen.ballRows, screen.queue, screen.anim = {}, {}, nil
  screen.messageTimer, screen.phase = 0, "menu"
  screen.message, screen.typer = nil, nil
  local nativeUpdate = screen.update
  screen.update = function() end
  check(staged.arena(), "native battle.started stages a real Route 29 arena")
  for _ = 1, 120 do
    U.wait(1)
    if staged.shot() then break end
  end
  assert(staged.shot() and staged.shot().canvas, "actual GPU arena canvas is ready")
  assert(api.battleStage.state(screen) and not api.battleStage.state(battle),
    "release contract expects the screen, not the underlying battle model")
  local Font=require("src.render.Font")
  local backplates=api.lib.require("UiBackplates")
  backplates.arenaFill:sync("OFF")
  backplates.textboxFill:sync("OFF")
  local bounds,probe
  local bottom=screen.drawBottom
  screen.drawBottom=function(self,ox,...)
    local result=bottom(self,ox,...)
    if probe then
      local x=probe.menu and (10+(ox or 0))*8 or 8
      if probe.message and self.typedMoveColorsMessageOrigins then
        x=self.typedMoveColorsMessageOrigins[1] or x
      end
      local y=probe.y or 112
      local sx,sy=love.graphics.transformPoint(x,y)
      local ex,ey=love.graphics.transformPoint(x+Font.width(probe.text),y+8)
      bounds={x=sx,y=sy,w=ex-sx,h=ey-sy}
    end
    return result
  end
  local function reveal(text)
    screen.message,screen.typedText,screen.typer=text,nil,nil
    screen:syncTyper()
    if screen.typer then screen.typer.shown=screen.typer.total end
  end
  local function shot(name,requireOutline)
    U.wait(3)
    local path=os.getenv("SHOT_DIR").."/"..name..".png"
    check(U.shot(game,path),"capture "..name)
    check(not love.window.hasFocus() and love.audio.getVolume()==0,"silent background rendering")
    if requireOutline then
      check(screen.modernStagedDialogueOutlined,"dialogue owns the outlined text scope")
      local file=assert(io.open(path,"rb"));local bytes=file:read("*a");file:close()
      local image=love.image.newImageData(love.filesystem.newFileData(bytes,"probe.png"))
      local white,black=0,0
      for y=math.ceil(bounds.y),math.floor(bounds.y+bounds.h)-1 do
        for x=math.ceil(bounds.x),math.floor(bounds.x+bounds.w)-1 do
          local r,g,b=image:getPixel(x,y)
          if r>0.95 and g>0.95 and b>0.95 then white=white+1 end
          if r<0.05 and g<0.05 and b<0.05 then black=black+1 end
        end
      end
      image:release()
      check(white>bounds.w*bounds.h/12,"GPU text has a light face in "..name)
      check(black>bounds.w*bounds.h/30,"GPU text has a dark outline in "..name)
    end
  end
  for _,layout in ipairs({"og","wide"})do
    game.save.options.battleLayout=layout
    for _,size in ipairs({{"wide",1280,720},{"portrait",480,900}})do
      love.window.setMode(size[2],size[3],{resizable=true,vsync=0})
      screen.phase,screen.menuIndex="menu",1;reveal(nil)
      probe={text=screen:menuLabels()[1],menu=true}
      shot(layout.."-"..size[1].."-commands",true)
      screen.phase="resolving";reveal("TOTODILE used\nSCRATCH!")
      probe={text="TOTODILE used",message=true}
      shot(layout.."-"..size[1].."-dialogue",true)
    end
  end
  game.save.options.battleLayout="og"
  love.window.setMode(1280,720,{resizable=true,vsync=0})
  for _,mode in ipairs({"WHITE","HALF","BLACK","OFF"})do
    backplates.textboxFill:sync(mode)
    shot("fill-"..mode,true)
    check(backplates.textboxFill:get()==mode,"text styling preserves selected box fill")
  end
  options["move_colors.text_position"]="right"
  reveal("TOTODILE used\nSCRATCH!")
  shot("right-aligned-dialogue",true)
  check(screen.typedMoveColorsMessageOrigins[1]>8,"custom message alignment is retained")
  local typer,page=screen.typer,screen.typer.page
  screen.typer.shown=1;U.wait(2)
  check(screen.typer==typer and screen.typer.page==page and screen.typer.shown==1,
    "rendering retains native reveal count and page identity")
  screen.typer.shown=5;U.wait(2)
  check(screen.typer.shown==5,"drawing never completes partially revealed dialogue")
  screen.typer.shown=screen.typer.total
  options["move_colors.text_position"]="left"
  screen.typedMoveColorsMessageOrigins=nil
  local pressed
  local wasPressed,isDown=game.input.wasPressed,game.input.isDown
  game.input.wasPressed=function(_,key)return key==pressed end
  game.input.isDown=function()return false end
  local function tap(key)pressed=key;nativeUpdate(screen,0);pressed=nil end
  screen.phase,screen.messageTimer="menu",0;reveal(nil)
  tap("a");check(screen.phase=="moves","native FIGHT opens move selection")
  tap("b");check(screen.phase=="menu","native B returns to commands")
  local enemy=screen:activeMon("enemy")
  local oldName=enemy.nickname
  screen:askNickname(enemy);screen:syncTyper();screen.typer.shown=screen.typer.total
  screen.messageTimer=0;probe=nil
  shot("nickname-yes-no",false)
  check(screen.modernStagedDialogueOutlined,"Yes/No shares the outlined dialogue scope")
  tap("down");check(screen.nicknameIndex==2,"native Yes/No cursor moves")
  tap("b");check(enemy.nickname==oldName,"native B declines naming without changing the mon")
  screen.phase="resolving"
  screen:showPages("FIRST LINE\nSECOND LINE\nTHIRD LINE")
  screen:syncTyper();screen.typer.shown=screen.typer.total
  tap("a");nativeUpdate(screen,0);check(screen.messagePage==2,"native A advances dialogue pages")
  for _,mode in ipairs({{"hud-off",false,true},{"native",false,false}})do
    options["battle_hud.enabled"],options["move_colors.enabled"]=mode[2],mode[3]
    screen.phase="menu";reveal(nil);probe=nil
    shot(mode[1],false)
    check(not screen.modernStagedDialogueOutlined,"HUD OFF leaves provider text rendering native")
  end
  game.input.wasPressed,game.input.isDown=wasPressed,isDown
  print("[DISCORD QA] PASS "..checks.." staged dialogue checks")
  love.event.quit(0)
end
