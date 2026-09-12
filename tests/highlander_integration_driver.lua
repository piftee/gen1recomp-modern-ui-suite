return function(game)
  local U=dofile(assert(os.getenv("PC_REPO")).."/tests/drivers/util.lua")
  local R=require("src.mods.Runtime")
  local GV=require("src.core.GameVersion")
  local gen2=GV.generation()==2
  local api=game.mods.exports.modern_ui_suite
  local opts=game.mods.modOptions.modern_ui_suite
  local checks=0
  local function check(ok,label)assert(ok,label);checks=checks+1;print("[INTEGRATION] "..label)end
  local function clear()while game.stack:top()do game.stack:pop()end end
  local function shot(name)
    U.wait(3);check(U.shot(game,os.getenv("SHOT_DIR").."/"..name..".png"),"capture "..name)
    check(not love.window.hasFocus() and love.audio.getVolume()==0,"muted and unfocused")
  end
  clear()
  local provider=assert(game.mods.exports.crystal_animated_sprites_with_shiny_visuals)
  game.save.modData=game.save.modData or {};game.save.modData.modern_ui_suite={}
  game.save.options.crystalTrainers="both";game.save.options.crystalPlayerSprite="red.png"
  opts["qol.force_crystal_settings"]=true
  local Oak=require(gen2 and "src.ui.gen2.OakSpeech" or "src.ui.OakSpeech")
  local speech=Oak.new(game,gen2 and {} or function()end)
  local steps=speech:buildSteps()
  if GV.get()~="crystal" then
    check(steps[1].id=="highlander_gender","new game offers hero choice with provider")
    speech:recordAnswer(steps[1],2,"GIRL","girl")
    local selected=gen2 and "kris_flip.png" or "leaf_flip.png"
    check(provider.playerSprite()==selected and game.save.options.crystalPlayerSprite==selected,"girl applies provider portrait")
    check(game.save.options.crystalTrainers=="all","selection enables all provider trainers")
    check(speech._highlanderSprite==selected,"intro loads selected provider artwork")
    provider.applyOption("crystalPlayerSprite","red.png")
    check(provider.playerSprite()==selected,"force prevents conflicting provider setting")
    clear();game.stack:push(speech)
    speech.pic=speech.playerPic;speech.picColors=nil;speech.picTrueColor=true
    speech.busy=true
    shot("girl-intro")
    opts["qol.force_crystal_settings"]=false;api.crystalIntegration.apply(game)
    check(provider.playerSprite()=="red.png" and game.save.options.crystalTrainers=="both","opt-out restores previous provider choices")
    check(speech:buildSteps()[1].id~="highlander_gender","opt-out retains original intro")
    opts["qol.force_crystal_settings"]=true
    speech:recordAnswer(steps[1],1,"BOY","boy")
    check(provider.playerSprite()==(gen2 and "gold_flip.png" or "red.png"),"boy applies matching provider portrait")
  else
    local count=0;for _,step in ipairs(steps)do if step.id=="highlander_gender" then count=count+1 end end
    check(count==0,"Crystal keeps native gender intro")
    local picNow=speech.playerPicNow
    speech:recordAnswer({id="gender",saveKey="gender"},2,"GIRL","female")
    check(speech.playerPicNow==picNow and speech._highlanderSprite==nil,
      "Crystal gender answer leaves native portrait controller intact")
    check(game.save.modData.modern_ui_suite.highlanderGender==nil,
      "Crystal native gender does not create a forced provider selection")
  end
  if gen2 then
    clear()
    game.save.party={require("src.battle.gen2.Mon").new(game.data,"SQUIRTLE",30),require("src.battle.gen2.Mon").new(game.data,"PIDGEY",25)}
    local w=game.world
    local oldMap,oldFacing,oldBusy,oldMoving=w.map,w.facingObject,w.busy,w.player.moving
    w.map={id="VioletGym"};w.facingObject=function()return {def={sprite="SPRITE_FALKNER"}}end
    w.busy=function()return false end;w.player.moving=false
    game.save.player.badges={ZEPHYR=true};opts["qol.rematch_anyone"]=true
    w:interactBody()
    local prompt=game.stack:top();check(prompt and type(prompt.choice)=="function","defeated Gen2 gym leader offers rematch")
    -- Let startScriptedBattle and Battle.new construct a real battle, while
    -- bypassing only its delayed visual transition in this assertion.
    local captured
    local oldStart=w.startBattle
    w.startBattle=function(self,args,done)
      captured=require("src.battle.gen2.Battle").new({data=game.data,save=game.save,party=game.save.party,trainer=args.trainer})
    end
    prompt.choice(true);w.startBattle=oldStart
    check(captured and #captured.enemyParty>0,"Gen2 rematch constructs native trainer party")
    for _,mon in ipairs(captured.enemyParty)do
      check(mon.level==25 and mon.hp==mon.maxHp and mon.maxHp>25,"Gen2 rematch regenerates level and stats")
      check(type(mon.moves[1])=="table" and mon.moves[1].pp>0,"Gen2 rematch has native moves and PP")
    end
    w.map,w.facingObject,w.busy,w.player.moving=oldMap,oldFacing,oldBusy,oldMoving
  end
  print("[DISCORD QA] PASS "..checks.." Highlander integration checks");love.event.quit(0)
end
