return function(game)
  local U=dofile(assert(os.getenv("PC_REPO")).."/tests/drivers/util.lua")
  local R=require("src.mods.Runtime")
  local gen2=require("src.core.GameVersion").generation()==2
  local Mon=require(gen2 and "src.battle.gen2.Mon" or "src.pokemon.Pokemon")
  local opts=game.mods.modOptions.modern_ui_suite
  local checks=0
  local function check(ok,label)assert(ok,label);checks=checks+1 end
  local gained={}
  local hooks=game.mods.events
  -- Test listener observes the same native amounts the UI summarizes.
  hooks:on("battle.exp_gained",function(ev)gained[ev.mon]=ev.gained end)
  opts["qol.modern_exp_share"]=true;opts["qol.always_boosted_exp"]=false
  local function award(mode)
    gained={}
    local party={}
    for i,id in ipairs({"SQUIRTLE","BULBASAUR","PIDGEY","PIKACHU"})do
      local mon=Mon.new(game.data,id,5)
      mon.otId=game.save.player.id
      mon.moves={{id="TACKLE",pp=35},{id="GROWL",pp=40},{id="TAIL_WHIP",pp=30},{id="CUT",pp=30}}
      party[i]=mon
    end
    if mode=="mixed" then party[3].otId=(game.save.player.id or 0)+1 end
    if mode=="fainted" then party[4].hp=0 end
    game.save.party=party
    local battle
    if gen2 then
      party[2].item="EXP_SHARE"
      battle=require("src.battle.gen2.Battle").new({data=game.data,save=game.save,party=party,wild=Mon.new(game.data,"RATICATE",20)})
    else
      game.save.inventory.EXP_ALL=1
      battle=require("src.battle.BattleState").newWild(game,"RATICATE",20,{onFinish=function()end})
    end
    local first={kind="message",text="BEFORE"};local last={text="AFTER"}
    if gen2 then battle.events={first}
    else battle.queue={first,last};battle.nextInsert=1 end
    local fighters={[party[1]]=true}
    if mode=="all-fought" or mode=="two-fought" then
      battle.participants={}
      for i,mon in ipairs(party)do
        if mode=="all-fought" or i==1 or i==3 then
          fighters[mon]=true;battle.participants[gen2 and i or mon]=true
        end
      end
    end
    if gen2 then battle:awardExperience(battle.enemy) else battle:awardExp()end
    local queue=gen2 and battle.events or battle.queue
    check(queue[1]==first,"earlier battle messages stay in place")
    if not gen2 then check(queue[#queue]==last,"later battle messages stay in place")end
    local summaries,summaryIndex=0
    local named,levels,moveChecks=0,0,0
    for i,row in ipairs(queue)do
      if row.modernPartyExp then summaries=summaries+1;summaryIndex=i end
      if row.text and row.text:find("gained",1,true) then named=named+1 end
      if row.kind=="level" or row.auto then levels=levels+1 end
      if row.kind=="choose-forget" or row.fn then moveChecks=moveChecks+1 end
    end
    if mode=="all-fought" then
      check(summaries==0,"no rest-of-party message when everyone fought")
      check(named==4,"every fighter retains native EXP announcement")
    else
      check(summaries==1,"one summary for the bench")
      check(named==(mode=="two-fought" and 2 or 1),"only fighters retain named EXP messages")
      check(levels>0 and moveChecks>0,"native level and move-learning work remains queued")
      for i,row in ipairs(queue)do
        if row.kind=="level" or row.auto or row.kind=="choose-forget" or row.fn then
          check(i>summaryIndex,"level commits and move prompts follow summary")
        end
        if gen2 and row.kind=="experience" then
          check(i>summaryIndex and row.text==nil,"EXP animation cannot show level text before summary")
        end
      end
      local low,high
      for i=2,#party do
        local n=not fighters[party[i]] and gained[party[i]]
        if n then low=math.min(low or n,n);high=math.max(high or n,n)end
      end
      local expected=low==high and tostring(low) or (low.."-"..high)
      check(queue[summaryIndex].text:find("got "..expected.." EXP!",1,true),"summary reports native per-member amount or range")
      if mode=="mixed" then check(high>low,"traded bonus remains applied")end
      if mode=="fainted" then check(gained[party[4]]==nil,"fainted bench member receives no EXP")end
    end
    for i,mon in ipairs(party)do
      if (mon.hp or 0)>0 then check(gained[mon] and gained[mon]>0,"eligible recipient retains native award")end
    end
    return battle,summaryIndex and queue[summaryIndex].text
  end
  local battle,summary=award("uniform")
  -- Verify the actual native font and text wrapping of the consolidated line.
  while game.stack:top()do game.stack:pop()end
  local text=require("src.render.TextBox").new(game,summary)
  game.stack:push(text);U.wait(90)
  check(U.shot(game,os.getenv("SHOT_DIR").."/party-exp-summary.png"),"capture party EXP message")
  check(not love.window.hasFocus() and love.audio.getVolume()==0,"muted and unfocused")
  game.stack:pop()
  if gen2 then
    -- Drive the native battle screen through the reordered events, including
    -- its EXP-bar lookahead, stats boxes and move-learning choices.
    local screen=require("src.ui.gen2.BattleState").new(game,{battle=battle})
    screen.queue=battle:takeEvents();screen.phase="resolving";screen.slideFrame=999
    screen.shownLevel=5;screen.shownExp=0;screen.showPlayerTrainer=false
    screen.showPlayerHud=true;screen.showEnemyHud=false
    local input=setmetatable({wasPressed=function(_,key)
      return key==(screen.phase=="ask-forget" and "b" or "a")
    end,isDown=function()return false end},{__index=game.input})
    screen.game=setmetatable({input=input},{__index=game})
    local summaryShown,levelShown,learnShown,animationShown,captured=false,false,false,false,false
    local showPages=screen.showPages
    screen.showPages=function(self,message,...)
      if message and message:find("The rest of your",1,true) then summaryShown=true end
      if message and message:find("grew",1,true) then
        assert(summaryShown,"native level text follows party summary");levelShown=true
      end
      return showPages(self,message,...)
    end
    game.stack:push(screen)
    for frame=1,15000 do
      if screen.expAnim then
        assert(summaryShown,"native EXP animation starts after party summary");animationShown=true
      end
      if screen.pendingLearn then learnShown=true end
      if not captured and screen.message and screen.message:find("party got",1,true)
          and not screen:syncTyper() then
        check(U.shot(game,os.getenv("SHOT_DIR").."/party-exp-battle.png"),"capture summary inside battle")
        captured=true
      end
      screen:update(1/60)
      if screen.phase=="menu" then break end
    end
    check(summaryShown and levelShown and learnShown and animationShown,"native EXP, level and learning screens all run")
    check(screen.phase=="menu" and #screen.queue==0,"native battle queue finishes without a stall")
    check(not screen.expAnim and screen.shownLevel==battle.player.level,"EXP bar reaches awarded level")
    check(captured,"native summary renders before advancing")
    game.stack:pop()
  end
  award("mixed");award("fainted");award("two-fought");award("all-fought")
  opts["qol.modern_exp_share"]=false
  local native=false
  R.call("battle.exp_award",function()native=true end,{})
  check(native,"disabled modern sharing keeps native message flow")
  print("[DISCORD QA] PASS "..checks.." party EXP summary checks");love.event.quit(0)
end
