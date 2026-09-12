return function(game)
  local U=dofile(assert(os.getenv("PC_REPO")).."/tests/drivers/util.lua")
  local R=require("src.mods.Runtime")
  local S=require("src.ui.Screens")
  local GV=require("src.core.GameVersion")
  local gen2=GV.generation()==2
  local api=game.mods.exports.modern_ui_suite
  local opts=game.mods.modOptions.modern_ui_suite
  local checks=0
  local function check(ok,label)checks=checks+1;assert(ok,label);print("[MECHANICS] "..label)end
  local function clear()while game.stack:top()do game.stack:pop()end end
  local function shot(name)
    U.wait(3);check(U.shot(game,os.getenv("SHOT_DIR").."/"..name..".png"),"capture "..name)
    check(not love.window.hasFocus() and love.audio.getVolume()==0,"muted and unfocused")
  end
  local function press(menu,key)
    local old=game.input
    game.input=setmetatable({wasPressed=function(_,k)return key==k end,isDown=function()return false end},{__index=old})
    local ok,err=pcall(menu.update,menu,0);game.input=old;assert(ok,err)
  end
  local Mon=require(gen2 and "src.battle.gen2.Mon" or "src.pokemon.Pokemon")
  local party={Mon.new(game.data,"SQUIRTLE",30),Mon.new(game.data,"PIDGEY",25)}
  game.save.party=party
  if gen2 then
    for _,m in ipairs(party)do m.otId=game.save.player.id end
    party[2].item="EXP_SHARE"
  else game.save.inventory.EXP_ALL=1 end
  opts["qol.modern_exp_share"]=true;opts["qol.always_boosted_exp"]=false
  local battle,screen
  local xp=gen2 and "experience" or "exp"
  local before={party[1][xp],party[2][xp]}
  clear()
  if gen2 then
    battle=require("src.battle.gen2.Battle").new({data=game.data,save=game.save,party=party,wild=Mon.new(game.data,"RATTATA",5)})
    battle:awardExperience(battle.enemy)
    local def=game.data.pokemon.RATTATA
    check(party[1][xp]-before[1]==Mon.experienceGain(def,5,1,false,{}),"Gen2 modern share removes held-item halving")
    check(party[2][xp]-before[2]==Mon.experienceGain(def,5,2,false,{}),"Gen2 bench receives half without extra held-item award")
    screen=S.push(game,"Gen2BattleState",{save=game.save,battle=battle,onDone=function()end})
    screen.slideFrame=require("src.ui.gen2.BattleAnimView").SLIDE_FRAMES
    screen.showPlayerTrainer,screen.showEnemyTrainer=false,false
    screen.showEnemyHud,screen.showPlayerHud=true,true
    screen.ballRows,screen.queue={},{};screen.anim,screen.typer,screen.messagePages=nil,nil,nil
    screen.phase="menu"
  else
    battle=require("src.battle.BattleState").newWild(game,"RATTATA",5,{onFinish=function()end})
    battle:awardExp()
    local E=require("src.battle.Experience")
    check(party[1].exp-before[1]==E.gainFor(game.data.pokemon.RATTATA,5,false,1,false),"Gen1 participant receives full EXP despite EXP.ALL")
    check(party[2].exp-before[2]==E.gainFor(game.data.pokemon.RATTATA,5,false,2,false),"Gen1 bench receives half EXP despite EXP.ALL")
    game.stack:push(battle)
    for _=1,700 do if battle.phase=="menu" then break end;U.tap(game,"a")end
    check(battle.phase=="menu","real battle reaches commands")
    screen=battle
  end
  opts["battle_hud.enemy_hp_counter"]=true
  shot("enemy-counter")
  opts["battle_hud.enemy_hp_counter"]=false
  shot("enemy-counter-off")
  if gen2 then
    party[1].moves={{id="CUT",pp=30,maxPp=30},{id="TACKLE",pp=35,maxPp=35},{id="GROWL",pp=40,maxPp=40},{id="TAIL_WHIP",pp=30,maxPp=30}}
    local _,reason,entry=Mon.learnMove(party[1],"SURF",game.data)
    check(reason=="full","Gen2 learning needs a slot")
    screen.pendingLearn={index=1,move=entry,moveName=game.data.moves.SURF.name}
    screen.phase="choose-forget";screen.messageTimer=0;screen.forgetIndex=1
    opts["pokemoves.forgettable_hms"]=true
    press(screen,"a")
    check(party[1].moves[1].id=="SURF","Gen2 battle can forget HM")
    clear()
    party[1].moves[1]={id="CUT",pp=30,maxPp=30}
    local done
    game:learnMoveOn(party[1],"SURF",function(ok)done=ok end)
    local ask=game.stack:top();game.stack:pop();ask.choice(true)
    U.wait(150)
    local list=game.stack:top()
    check(list.screenId=="Gen2MoveDeleter","Gen2 field learning opens native move list")
    list.onChoose(1)
    check(party[1].moves[1].id=="SURF","Gen2 field can forget HM")
    for _=1,250 do if done then break end;U.tap(game,"a")end
    check(done==true,"Gen2 field learning completes native callback")
    game.save.inventory.TM_ROAR=1;opts["pokemoves.tms_forever"]=true
    game:consumeItem("TM_ROAR")
    check(game.save.inventory.TM_ROAR==1,"Gen2 reusable TM is retained")
  else
    opts["pokemoves.tms_forever"]=true
    local Effects=require("src.inventory.ItemEffects")
    party[1].moves={{id="TACKLE",pp=35}}
    local result=Effects.use(game.data,game.save,"TM_WATER_GUN",party[1])
    check(result=="learnkept","Gen1 reusable TM uses native nonconsuming learning result")
    opts["qol.infinite_safari"]=true;game.save.safari={steps=1,balls=2}
    local ow=game.overworld
    clear();game.stack:push(ow,"PEWTER_GYM",4,9,"up",{via="boot"})
    game.save.safari={steps=1,balls=2}
    local inZone=ow.inSafariStepZone;ow.inSafariStepZone=function()return true end
    check(ow:safariStep()==false and game.save.safari.steps==1,"Safari last step cannot expire while unlimited")
    opts["qol.infinite_safari"]=false
    local ended=false;local over=ow.safariGameOver;ow.safariGameOver=function()ended=true end
    ow:safariStep();check(ended,"Safari original expiry restored")
    ow.inSafariStepZone=inZone;ow.safariGameOver=over;game.save.safari=nil
    clear();game.stack:push(ow,"PEWTER_GYM",4,9,"up",{via="boot"})
    local npc
    for _,n in ipairs(ow.npcs)do if n.def.trainerClass=="OPP_BROCK" then npc=n end end
    check(npc~=nil,"real Brock NPC available")
    game.save.defeatedTrainers[npc.id]=true
    opts["qol.rematch_anyone"]=true
    ow:talkTo(npc)
    local prompt=game.stack:top();check(type(prompt.choice)=="function","defeated gym leader offers rematch")
    local captured;local push=ow.pushBattle;ow.pushBattle=function(_,b)captured=b end
    prompt.choice(true);ow.pushBattle=push
    check(captured and captured.rematch,"Yes constructs native trainer rematch")
    for _,m in ipairs(captured.enemyParty)do check(m.level==25,"trainer party scales to weakest level")end
    local after=ow.afterBattle;ow.afterBattle=function()end
    local reward=ow.checkVictoryRewards;ow.checkVictoryRewards=function()error("must not replay rewards")end
    captured.onFinish("win")
    ow.afterBattle=after;ow.checkVictoryRewards=reward
    check(not game.save.flags.EVENT_BEAT_BROCK,"rematch completion preserves story flags")
    if GV.get()=="yellow" then
      opts["qol.pikachu_sound"]="original"
      local Sound=require("src.core.Sound")
      check(Sound.playPikaCry(game.data,1)~=nil,"Yellow direct voice call resolves regular chip cry")
      check(Sound.playCry(game.data,"PIKACHU")~=nil,"Yellow standard Pikachu cry does not recurse")
    end
  end
  print("[DISCORD QA] PASS "..checks.." Highlander mechanics checks");love.event.quit(0)
end
