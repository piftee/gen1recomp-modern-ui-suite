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
  local nameBounds
  local drawPlayerHud=screen.drawPlayerHud
  screen.drawPlayerHud=function(self,...)
    local result=drawPlayerHud(self,...)
    local sx,sy=love.graphics.transformPoint(80,56)
    local ex,ey=love.graphics.transformPoint(144,64)
    nameBounds={x=sx,y=sy,w=ex-sx,h=ey-sy}
    return result
  end
  local function readShot(path)
    local file=assert(io.open(path,"rb"));local bytes=file:read("*a");file:close()
    return love.image.newImageData(love.filesystem.newFileData(bytes,"probe.png"))
  end
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
  assert(U.shot(game, os.getenv("SHOT_DIR") .. "/menu.png"))
  screen.phase = "moves"
  screen.moveIndex = 1
  for _,size in ipairs({{"report",2048,1536},{"wide",1280,720},{"compact",800,720},{"portrait",480,900}})do
    love.window.setMode(size[2],size[3],{resizable=true,vsync=0})
    U.wait(4)
    check(U.shot(game,os.getenv("SHOT_DIR").."/"..size[1].."-moves.png"),"capture "..size[1])
    check(not love.window.hasFocus() and love.audio.getVolume()==0,"silent background rendering")
    check(screen.modernStagedHudOutlined,"staged status uses outlined light text over the terrain")
    local image=readShot(os.getenv("SHOT_DIR").."/"..size[1].."-moves.png")
    local white=0
    for y=math.ceil(nameBounds.y),math.floor(nameBounds.y+nameBounds.h)-1 do
      for x=math.ceil(nameBounds.x),math.floor(nameBounds.x+nameBounds.w)-1 do
        local r,g,b=image:getPixel(x,y)
        if r>0.95 and g>0.95 and b>0.95 then white=white+1 end
      end
    end
    image:release()
    check(white>nameBounds.w*nameBounds.h/12,"actual GPU HUD name uses visible white ink")
    if game.mods.exports.special_stat_split then
      check(screen.typedMoveColorsInfoCategory=="PHYSICAL","category belongs to the details footer")
      check(screen.typedMoveCategoryLegacySuppressed,"legacy category cannot cover a move card")
    end
  end
  if game.mods.exports.special_stat_split then
    local moves=screen:playerMoves()
    local oldId=moves[1].id
    for _,item in ipairs({{"WATER_GUN","SPECIAL"},{"LEER","STATUS"}})do
      moves[1].id=item[1];U.wait(2)
      check(U.shot(game,os.getenv("SHOT_DIR").."/category-"..item[2]..".png"),"capture "..item[2])
      check(screen.typedMoveColorsInfoCategory==item[2],"selected move category follows "..item[1])
    end
    moves[1].id=oldId
  end
  local function captureExp(name, expected)
    U.wait(2)
    local path=os.getenv("SHOT_DIR").."/"..name..".png"
    check(U.shot(game,path),"capture "..name)
    check(screen.modernStagedExpPixels==expected,"drawn EXP follows the native animated pixel count")
    local bounds=assert(screen.modernStagedExpBounds,"EXP has visible bounds")
    local image=readShot(path)
    local blue=0
    local y=math.floor(bounds.y+bounds.h/2)
    for x=math.floor(bounds.x),math.floor(bounds.x+bounds.w)-1 do
      local r,g,b=image:getPixel(x,y)
      if b>0.9 and r<0.4 and g>0.5 and g<0.8 then blue=blue+1 end
    end
    image:release()
    check(math.abs(blue-bounds.w*expected/64)<=2,"actual GPU EXP fill has the expected width")
  end
  screen.phase="resolving";screen.message=nil;screen.messageTimer=0
  for _,pixels in ipairs({0,32,64})do
    screen.shownExp=pixels;captureExp("exp-"..pixels,pixels)
  end
  local mon=game.save.party[1]
  local growth=Mon.growthFor(game.data,game.data.pokemon[mon.species].growthRate)
  mon.experience=Mon.experienceForLevel(growth,6)-1
  local first=screen:expPixels(mon,5,mon.experience)
  battle.events={};battle:awardExperience(battle.enemy)
  screen.queue=battle:takeEvents();screen.phase="resolving"
  screen.shownLevel,screen.shownExp=5,first
  screen.message,screen.typedText,screen.typer=nil,nil,nil
  screen.messageTimer,screen.waitSfxLeft,screen.waitSfx=0,nil,nil
  local pressed
  local wasPressed,isDown=game.input.wasPressed,game.input.isDown
  game.input.wasPressed=function(_,key)return key==pressed end
  game.input.isDown=function()return false end
  local grew,reset,increased,capturedAward=false,false,false,{}
  local previousLevel,previousPixels=5,first
  for frame=1,18000 do
    pressed=screen.phase=="ask-forget" and "b" or "a"
    nativeUpdate(screen,1/60)
    if screen.shownExp>previousPixels then increased=true end
    if screen.shownLevel>previousLevel then grew=true end
    if grew and screen.shownExp<previousPixels then reset=true end
    previousLevel,previousPixels=screen.shownLevel,screen.shownExp
    local key=tostring(screen.shownLevel).."-"..tostring(screen.shownExp)
    if screen.expAnim and (screen.shownExp==0 or screen.shownExp==32 or screen.shownExp==64)
        and not capturedAward[key] then
      pressed=nil;captureExp("award-"..key,screen.shownExp);capturedAward[key]=true
    end
    if screen.phase=="menu" then break end
  end
  pressed=nil;game.input.wasPressed,game.input.isDown=wasPressed,isDown
  check(increased and grew and reset,"real EXP award fills, levels up and resets the displayed bar")
  check(not screen.expAnim and screen.phase=="menu","EXP award finishes without stalling")
  check(screen.shownExp==screen:expPixels(mon,mon.level,mon.experience),"bar ends at the actual earned EXP")
  check(next(capturedAward),"actual award was captured while animating")
  print("[DISCORD QA] PASS "..checks.." staged layout and EXP checks")
  love.event.quit(0)
end
