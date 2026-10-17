-- Native battle regression. Use the isolated muted/nonactivating runner.
return function(game)
  local U=dofile(assert(os.getenv('PC_REPO'))..'/tests/drivers/util.lua')
  local Screens=require('src.ui.Screens')
  local Mon=require('src.battle.gen2.Mon')
  local Battle=require('src.battle.gen2.Battle')
  local View=require('src.ui.gen2.BattleAnimView')
  local Chrome=require('src.ui.gen2.Chrome')
  local opts=game.mods.modOptions.modern_ui_suite
  local checks=0
  local function check(ok,label)assert(ok,label);checks=checks+1 end
  local inStats,labels,values=false,{},{}
  local printLabel,printValue=Chrome.printThrough,Chrome.printRightThrough
  Chrome.printThrough=function(text,...)
    if inStats then labels[tostring(text)]=true end
    return printLabel(text,...)
  end
  Chrome.printRightThrough=function(text,x,y,...)
    if inStats then values[y]=tonumber(text) end
    return printValue(text,x,y,...)
  end
  local rows={{'ATTACK','attack'},{'DEFENSE','defense'},
    {'SPCL.ATK','specialAttack'},{'SPCL.DEF','specialDefense'},{'SPEED','speed'}}
  local cases={{'wide',1280,720,'16:9',true},{'compact',800,720,'4:3',true},
    {'native',640,576,'fill',true},{'portrait',480,900,'fill',true},
    {'plain-moves',1280,720,'16:9',false}}
  for _,case in ipairs(cases)do for _,hud in ipairs({true,false})do
    while game.stack:top()do game.stack:pop()end
    opts['battle_hud.enabled']=hud;opts['battle_hud.aspect_ratio']=case[4]
    opts['move_colors.enabled']=case[5];opts['qol.modern_exp_share']=false
    love.window.setMode(case[2],case[3],{resizable=true,vsync=0})
    local mon=Mon.new(game.data,'FERALIGATR',49)
    local def=game.data.pokemon.FERALIGATR
    local growth=Mon.growthFor(game.data,def.growthRate)
    mon.experience=Mon.experienceForLevel(growth,50)-1;mon.otId=game.save.player.id
    game.save.party={mon}
    local battle=Battle.new({data=game.data,save=game.save,party=game.save.party,
      wild=Mon.new(game.data,'RATICATE',20)})
    battle.events={};battle:awardExperience(battle.enemy)
    local screen=Screens.push(game,'Gen2BattleState',{save=game.save,battle=battle,onDone=function()end})
    screen.queue=battle:takeEvents();screen.phase='resolving';screen.slideFrame=View.SLIDE_FRAMES
    screen.showPlayerTrainer,screen.showEnemyTrainer=false,false
    screen.showPlayerHud,screen.showEnemyHud=true,false
    screen.shownLevel,screen.shownExp=49,mon.experience
    screen.messageTimer=0;screen.anim=nil;screen.ballRows={}
    local statsDraws,wrongMon=0,false
    local drawStats=screen.drawStatsBox
    screen.drawStatsBox=function(self,selected,...)
      statsDraws=statsDraws+1;wrongMon=wrongMon or selected~=mon
      inStats=true;local result=drawStats(self,selected,...);inStats=false
      return result
    end
    local pressed
    local auto=setmetatable({wasPressed=function(_,key)return key==pressed end,
      isDown=function()return false end},{__index=game.input})
    screen.game=setmetatable({input=auto},{__index=game})
    local sawLevel=false
    for frame=1,18000 do
      if screen.message and screen.message:find('grew',1,true)then sawLevel=true end
      if screen.phase=='stats-box'then break end
      pressed=screen.phase=='ask-forget' and 'b' or 'a';screen:update(1/60)
    end
    screen.game=game;pressed=nil
    check(sawLevel,'native level announcement ran')
    check(screen.phase=='stats-box' and screen.statsBoxMon==mon,'native level flow reaches stat confirmation')
    labels,values={},{};statsDraws=0;U.wait(3)
    local name=case[1]..(hud and '-hud' or '-native')
    check(U.shot(game,os.getenv('SHOT_DIR')..'/'..name..'.png'),'capture '..name)
    check(statsDraws>0 and not wrongMon,'native stats renderer draws the leveled member')
    local expected=Mon.stats(def.baseStats,mon.dvs,mon.level,mon.statExp)
    for i,row in ipairs(rows)do
      check(labels[row[1]],name..' displays '..row[1])
      check(values[i*2]==expected[row[2]],name..' displays the current '..row[2]..' value')
    end
    check(screen.phase=='stats-box','stats wait for player confirmation')
    check(mon.level==50,'award commits the correct level')
    check(not love.window.hasFocus() and love.audio.getVolume()==0,'muted background testing')
    U.tap(game,hud and 'a' or 'b');U.wait(2)
    check(screen.phase~='stats-box' and screen.statsBoxMon==nil,'A/B dismisses the native confirmation')
    screen.phase='menu';screen.message='What will you do?';statsDraws=0
    U.wait(2);check(statsDraws==0,'stats do not leak into the next command menu')
  end end
  Chrome.printThrough,Chrome.printRightThrough=printLabel,printValue
  print('[DISCORD QA] PASS '..checks..' level-up stat checks');love.event.quit(0)
end
