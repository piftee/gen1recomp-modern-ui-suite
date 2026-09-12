return function(game)
  local U=dofile(assert(os.getenv("PC_REPO")).."/tests/drivers/util.lua")
  local R=require("src.mods.Runtime")
  local S=require("src.ui.Screens")
  local GV=require("src.core.GameVersion")
  local gen2=GV.generation()==2
  local api=assert(game.mods.exports.modern_ui_suite)
  local opts=game.mods.modOptions.modern_ui_suite
  local checks=0
  local function check(ok,label)checks=checks+1;assert(ok,label);print("[HIGHLANDER] "..label)end
  local function clear()while game.stack:top() do game.stack:pop()end end
  local function press(menu,key)
    local old=game.input
    game.input=setmetatable({wasPressed=function(_,k)return k==key end,isDown=function()return false end},{__index=old})
    local ok,err=pcall(menu.update,menu,0);game.input=old;assert(ok,err)
  end
  local function shot(name)
    U.wait(3);check(U.shot(game,os.getenv("SHOT_DIR").."/"..name..".png"),"capture "..name)
    check(not love.window.hasFocus() and love.audio.getVolume()==0,"muted and unfocused")
  end
  local function mon(species,level)
    if gen2 then return require("src.battle.gen2.Mon").new(game.data,species,level) end
    return require("src.pokemon.Pokemon").new(game.data,species,level)
  end
  love.window.setMode(1088,640,{resizable=true,vsync=0})
  clear()
  api.settings.open(game)
  local hub=game.stack:top()
  check(#hub.items==16,"all new settings pages present")
  shot("hub")
  for _,id in ipairs({"unlimited_pp","pokemoves","controller_rumble","full_control","modern_start_menu_ui"}) do
    for _,row in ipairs(hub.items) do
      if row.id==id then hub.onChoose(row,hub);shot("settings-"..id);game.stack:pop();break end
    end
  end
  local moves=api.components.pokemoves.exports
  local a=mon("ARCANINE",50)
  local available={};for _,row in ipairs(moves.relearnList(game.data,a)) do available[row.id]=true end
  check(available.FLAMETHROWER,"stone evolution can relearn pre-evolution Flamethrower at its level")
  a.level=5;available={};for _,row in ipairs(moves.relearnList(game.data,a))do available[row.id]=true end
  check(not available.FLAMETHROWER,"future pre-evolution moves remain gated by level")
  opts["pokemoves.move_relearning"]=true
  a.level=50;game.save.party={a}
  moves.openRelearn(game,a);shot("relearn");game.stack:pop()
  local input={isDown=function(_,k)return k=="b"end}
  opts["qol.running_shoes"]="hold"
  local function speed(ctx)return R.call("movement.speed",function(f)return f end,16,ctx)end
  check(speed({input=input})==8,"running shoes double walking speed")
  check(speed({input=input,onBike=true})==16,"running leaves bike speed alone")
  check(speed({input=input,surfing=true})==16,"running leaves surfing speed alone")
  opts["qol.running_shoes"]="off";check(speed({input=input})==16,"running switch restores walking")
  opts["qol.always_boosted_exp"]=true
  local expctx={traded=false}
  check(R.call("exp.gain",function(c)return c.traded end,expctx)==true,"boosted EXP reaches native computation")
  check(expctx.traded==false,"boost does not mutate traded status")
  opts["qol.always_boosted_exp"]=false
  check(R.call("exp.gain",function(c)return c.traded end,expctx)==false,"boost restores immediately")
  local party={mon("SQUIRTLE",10),mon("PIDGEY",8),mon("RATTATA",6)}
  party[3].hp=0
  local shares={}
  opts["qol.modern_exp_share"]=true
  R.call("battle.exp_award",function()error("native item split must be replaced")end,
    {battle={game={save={party=party}}},alive={party[1]},applyShare=function(m,n)shares[m]=n end})
  check(shares[party[1]]==1 and shares[party[2]]==2 and shares[party[3]]==nil,"modern EXP full/half and fainted exclusion")
  opts["qol.modern_exp_share"]=false
  local native=false;R.call("battle.exp_award",function()native=true end,{})
  check(native,"original EXP item path restored")
  check(api.highlander.decapitalize("PIKACHU HP <PLAYER>\nPOKéMON")=="Pikachu HP <PLAYER>\nPokémon","case option preserves tokens and acronyms")
  game.save.party=party
  local learner=party[1]
  learner.moves={{id="TACKLE",pp=35}}
  game.save.inventory.HM_SURF=1
  if gen2 then
    game.save.player.badges=game.save.player.badges or {};game.save.player.badges.FOG=true
  else game.save.inventory.SOULBADGE=1 end
  opts["pokemoves.no_learn_hms"]=true
  check(moves.firstLearner(game.data,game.save,"SURF")==learner,"owned HM plus badge and compatible party unlocks Surf")
  game.save.inventory.HM_SURF=nil
  check(moves.firstLearner(game.data,game.save,"SURF")==nil,"missing HM prevents field use")
  game.save.inventory.HM_SURF=1
  check(#learner.moves==1 and learner.moves[1].id=="TACKLE","no-learn never teaches a move")
  opts["pokemoves.forgettable_hms"]=true
  learner.moves={{id="CUT",pp=30},{id="TACKLE",pp=35},{id="GROWL",pp=40},{id="TAIL_WHIP",pp=30}}
  clear()
  if not gen2 then
    local page=S.push(game,"MoveLearnMenu",learner,"SURF",function()end)
    clear();game.stack:push(page);page.selecting=true;page.index=1
    press(page,"a")
    check(learner.moves[1].id=="SURF","native Gen 1 learn flow can forget an HM")
  else
    game:learnMoveOn(learner,"SURF",function()end)
    shot("hm-learning")
  end
  clear()
  opts["start_menu.pokebox"]=true
  local items=R.call("ui.start_menu.items",function(_,v)return v end,game,{})
  local box;for _,item in ipairs(items)do if item.id=="pokebox" then box=item end end
  check(box~=nil,"Pokebox action registered")
  box.onSelect();check(game.stack:top()~=nil,"Pokebox opens native storage registration")
  shot("pokebox");clear()
  local Input=require("src.core.Input")
  opts["fullctl.enabled"]=true
  Input:reset();Input:applyBindings({start={pad="x",key="q"},a={pad="start",key="z"}})
  check(Input.padBindings.start=="a" and Input.padBindings.x=="start","Start button can be assigned freely")
  check(Input.keyBindings.q=="start","keyboard remapping retained")
  opts["fullctl.analog_left"]=false;opts["fullctl.analog_right"]=true
  Input:gamepadaxis(nil,"leftx",1);check(not Input:isDown("right"),"left stick can be disabled")
  Input:gamepadaxis(nil,"rightx",1);check(Input:isDown("right"),"right stick independently moves")
  Input:gamepadaxis(nil,"rightx",0);check(not Input:isDown("right"),"right stick releases cleanly")
  opts["fullctl.enabled"]=false;Input:reset();Input:applyBindings(game.save.options.bindings)
  check(api.rematches.weakest({save={party=party}})==6,"rematch scales to weakest party level")
  check(api.rematches.scaledSpecies(game.data,"CHARIZARD",10)=="CHARMANDER","rematch evolution scales down")
  check(api.rematches.scaledSpecies(game.data,"CHARMANDER",50)=="CHARIZARD","rematch evolution scales up")
  print("[DISCORD QA] PASS "..checks.." Highlander checks");love.event.quit(0)
end
