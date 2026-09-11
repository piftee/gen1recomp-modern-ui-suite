-- Real native learning controller: rendered list and resulting party moves.
return function(game)
  local U=dofile(assert(os.getenv('PC_REPO'))..'/tests/drivers/util.lua')
  local Mon=require('src.battle.gen2.Mon')
  local Battle=require('src.battle.gen2.Battle')
  local View=require('src.ui.gen2.BattleAnimView')
  local Screens=require('src.ui.Screens')
  local Forget=require('src.ui.gen2.ForgetMoveList')
  local opts=game.mods.modOptions.modern_ui_suite
  local checks=0
  local function check(ok,label) checks=checks+1;assert(ok,label);print('[MOVE LEARN] '..label) end
  local function press(menu,key)
    local old=game.input
    game.input=setmetatable({wasPressed=function(_,k)return k==key end,isDown=function()return false end},{__index=old})
    local ok,err=pcall(menu.update,menu,0);game.input=old;assert(ok,err)
  end
  local base={'TACKLE','GROWL','SMOKESCREEN','EMBER'}
  local function setup(hm)
    while game.stack:top() do game.stack:pop() end
    local mon=Mon.new(game.data,'CYNDAQUIL',20)
    mon.moves={}
    for i,id in ipairs(base) do mon.moves[i]={id=id,pp=10,maxPp=20} end
    if hm then mon.moves[2]={id='CUT',pp=15,maxPp=30} end
    game.save.party={mon}
    local battle=Battle.new({data=game.data,save=game.save,party=game.save.party,wild=Mon.new(game.data,'PIDGEY',15)})
    local screen=Screens.push(game,'Gen2BattleState',{save=game.save,battle=battle,onDone=function()end})
    screen.slideFrame=View.SLIDE_FRAMES
    screen.showPlayerTrainer,screen.showEnemyTrainer=false,false
    screen.showEnemyHud,screen.showPlayerHud=true,true
    screen.ballRows,screen.queue={},{}
    screen.anim,screen.typer,screen.messagePages=nil,nil,nil
    local learned,reason,entry=Mon.learnMove(mon,'FLAME_WHEEL',game.data)
    check(not learned and reason=='full','full move set requests a replacement')
    screen.pendingLearn={index=1,move=entry,moveName=game.data.moves.FLAME_WHEEL.name}
    screen.phase,screen.messageTimer,screen.forgetChoice='ask-forget',0,1
    press(screen,'a')
    check(screen.phase=='choose-forget','YES opens the native forget selector')
    U.wait(90) -- allow the native question's text reveal to release input
    return screen,mon
  end
  local original=Forget.draw
  local drawn
  Forget.draw=function(moves,cursor,data,palette)
    drawn={moves=moves,cursor=cursor};return original(moves,cursor,data,palette)
  end
  local function shot(name)
    drawn=nil;U.wait(3)
    check(U.shot(game,os.getenv('SHOT_DIR')..'/'..name..'.png'),'captured '..name)
    check(drawn and #drawn.moves==4,'all four existing moves are drawn')
    check(not love.window.hasFocus() and love.audio.getVolume()==0,'muted and unfocused')
  end
  opts['battle_hud.enabled']=true
  for _,slot in ipairs({2,3,4}) do
    local screen,mon=setup()
    love.window.setMode(1280,720,{resizable=true,vsync=0})
    for i=2,slot do press(screen,'down') end
    shot('choose-slot-'..slot)
    check(drawn.cursor==slot,'visible cursor matches slot '..slot)
    for i,id in ipairs(base) do check(mon.moves[i].id==id,'no replacement before confirmation '..i) end
    press(screen,'a')
    for i,id in ipairs(base) do check(mon.moves[i].id==(i==slot and 'FLAME_WHEEL' or id),'only chosen slot changes '..i) end
  end
  for _,size in ipairs({{'compact',800,720},{'portrait',480,900}}) do
    local screen,mon=setup()
    love.window.setMode(size[2],size[3],{resizable=true,vsync=0})
    press(screen,'up');shot('wrap-'..size[1]);check(drawn.cursor==4,'Up wraps to last slot')
    press(screen,'b');check(screen.phase=='stop-learning','B opens stop-learning confirmation')
    U.wait(90)
    screen.messageTimer=0
    press(screen,'a')
    for i,id in ipairs(base) do check(mon.moves[i].id==id,'cancellation preserves slot '..i) end
  end
  local screen,mon=setup(true)
  love.window.setMode(1280,720,{resizable=true,vsync=0})
  press(screen,'down');press(screen,'a')
  check(mon.moves[2].id=='CUT' and screen.phase=='choose-forget','HM cannot be overwritten')
  screen.messageTimer=0;shot('hm-protected')
  opts['battle_hud.enabled']=false
  screen=setup();shot('hud-off')
  -- TM/tutor/rare-candy learning outside battle uses a separate native
  -- MoveDeleter overlay; prove that the wide Bag leaves it visible too.
  while game.stack:top() do game.stack:pop() end
  opts['bag.aspect_ratio']='16:9';opts['bag.skin']='modern'
  Screens.push(game,'Gen2PackMenu',{save=game.save})
  local fieldMon=Mon.new(game.data,'CYNDAQUIL',20)
  fieldMon.moves={}
  for i,id in ipairs(base) do fieldMon.moves[i]={id=id,pp=10,maxPp=20} end
  game:learnMoveOn(fieldMon,'FLAME_WHEEL',function()end)
  local picker
  for _=1,400 do
    local top=game.stack:top()
    if top.forget and top.list then picker=top;break end
    press(top,'a');U.wait(2)
  end
  check(picker~=nil,'field learning opens native move selector')
  press(picker,'down');press(picker,'down');press(picker,'down')
  shot('field-learning-slot-4')
  check(drawn.cursor==4,'field selector shows slot four')
  press(picker,'a')
  for i,id in ipairs(base) do check(fieldMon.moves[i].id==(i==4 and 'FLAME_WHEEL' or id),'field learning changes only selected slot '..i) end
  Forget.draw=original
  print('[DISCORD QA] PASS '..checks..' Gen 2 learning checks');love.event.quit(0)
end
