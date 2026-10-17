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
  love.window.setMode(1280, 720, { resizable = true,vsync=0 })
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
  print("[POPUP QA] starting battle")
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
  print("[POPUP QA] battle pushed; waiting for GPU")
  check(staged.arena(), "native battle.started stages a real Route 29 arena")
  for _ = 1, 120 do
    U.wait(1)
    if staged.shot() then break end
  end
  assert(staged.shot() and staged.shot().canvas, "actual GPU arena canvas is ready")
  assert(api.battleStage.state(screen) and not api.battleStage.state(battle),
    "release contract expects the screen, not the underlying battle model")
  print("[POPUP QA] GPU ready")
  options["battle_hud.enemy_hp_counter"]=true
  local backplates=api.lib.require("UiBackplates")
  backplates.arenaFill:sync("OFF");backplates.textboxFill:sync("OFF")
  local enemy=screen:activeMon("enemy")
  local maximum=enemy.maxHp or enemy.stats.hp
  local meterBounds,caughtBounds,popupPoint
  local enemyHud,bottom=screen.drawEnemyHud,screen.drawBottom
  screen.drawEnemyHud=function(self,...)
    local result=enemyHud(self,...)
    local x,y=love.graphics.transformPoint(32,19)
    local ex,ey=love.graphics.transformPoint(80,26)
    meterBounds={x=x,y=y,w=ex-x,h=ey-y}
    x,y=love.graphics.transformPoint(8,10)
    ex,ey=love.graphics.transformPoint(16,18)
    caughtBounds={x=x,y=y,w=ex-x,h=ey-y}
    return result
  end
  screen.drawBottom=function(self,...)
    local result=bottom(self,...)
    local b=self.modernStagedPopupBounds
    if b then
      local x,y=love.graphics.transformPoint(b.x+9,b.y+18)
      popupPoint={x=x,y=y}
    end
    return result
  end
  local function shot(name)
    U.wait(3)
    local path=os.getenv("SHOT_DIR").."/"..name..".png"
    check(U.shot(game,path),"capture "..name)
    check(not love.window.hasFocus() and love.audio.getVolume()==0,"silent background rendering")
    local file=assert(io.open(path,"rb"));local bytes=file:read("*a");file:close()
    return love.image.newImageData(love.filesystem.newFileData(bytes,"probe.png"))
  end
  local function whitePixels(image,b)
    local count=0
    for y=math.ceil(b.y),math.floor(b.y+b.h)-1 do
      for x=math.ceil(b.x),math.floor(b.x+b.w)-1 do
        local r,g,blue=image:getPixel(x,y)
        if r>0.95 and g>0.95 and blue>0.95 then count=count+1 end
      end
    end
    return count
  end
  local pressed
  local wasPressed,isDown=game.input.wasPressed,game.input.isDown
  game.input.wasPressed=function(_,key)return key==pressed end
  game.input.isDown=function()return false end
  local function tap(key)pressed=key;nativeUpdate(screen,0);pressed=nil end
  for _,layout in ipairs({"og","wide"})do
    game.save.options.battleLayout=layout
    for _,size in ipairs({{"landscape",1280,720},{"portrait",480,900}})do
      love.window.setMode(size[2],size[3],{resizable=true,vsync=0})
      local tag=layout.."-"..size[1]
      screen.phase,screen.caughtMark="menu",true
      for _,ratio in ipairs({1,0.4,0.1,0})do
        screen.shownHp.enemy=math.floor(maximum*ratio)
        local image=shot(tag.."-hp-"..math.floor(ratio*100))
        check(screen.modernStagedEnemyMeter,"enemy meter draws in its own HUD transform")
        check(whitePixels(image,meterBounds)>meterBounds.w*meterBounds.h/15,
          "actual HP digits stay white at "..ratio)
        check(screen.modernStagedCaughtOutlined,"native caught tile has outline styling")
        check(whitePixels(image,caughtBounds)>caughtBounds.w*caughtBounds.h/15,
          "actual caught icon has a light face")
        image:release()
      end
      screen.caughtMark=false
      local image=shot(tag.."-not-caught")
      check(not screen.modernStagedCaughtOutlined,"uncaught species has no caught marker")
      image:release()
      for _,phase in ipairs({"stats-box","ask-shift"})do
        screen.phase,screen.messageTimer=phase,0
        screen.statsBoxMon=phase=="stats-box" and game.save.party[1] or nil
        screen.shiftIndex=1
        local image=shot(tag.."-"..phase)
        check(screen.modernStagedPopupBounds and popupPoint,"native popup has solid bounds")
        local solid=0
        for y=math.ceil(popupPoint.y),math.ceil(popupPoint.y)+3 do
          for x=math.ceil(popupPoint.x),math.ceil(popupPoint.x)+3 do
            local r,g,b=image:getPixel(x,y)
            if math.abs(r-0.10)<0.015 and math.abs(g-0.12)<0.015 and math.abs(b-0.16)<0.015 then solid=solid+1 end
          end
        end
        image:release()
        check(solid==16,"GPU popup has an opaque background over the arena")
        if phase=="stats-box" then
          tap("a");check(screen.statsBoxMon==nil,"native A dismisses stat popup")
        else
          tap("down");check(screen.shiftIndex==2,"native switch Yes/No navigation works")
          tap("b");check(screen.phase~="ask-shift","native B declines switching")
        end
      end
    end
  end
  options["battle_hud.enabled"]=false
  screen.phase,screen.statsBoxMon="stats-box",game.save.party[1]
  local image=shot("hud-disabled");image:release()
  check(not screen.modernStagedPopupBounds,"HUD OFF leaves the provider's popup style unchanged")
  game.input.wasPressed,game.input.isDown=wasPressed,isDown
  print("[DISCORD QA] PASS "..checks.." staged popup and contrast checks")
  love.event.quit(0)
end
