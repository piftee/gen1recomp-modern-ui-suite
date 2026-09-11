return function(game)
  local U=dofile(assert(os.getenv('PC_REPO'))..'/tests/drivers/util.lua')
  local Screens=require('src.ui.Screens')
  local opts=game.mods.modOptions.modern_ui_suite
  local checks=0
  local function check(ok,label) checks=checks+1;assert(ok,label);print('[ITEM PC] '..label) end
  local function press(menu,key)
    local old=game.input
    game.input=setmetatable({wasPressed=function(_,k)return k==key end,isDown=function()return false end},{__index=old})
    local ok,err=pcall(menu.update,menu,0);game.input=old;assert(ok,err)
  end
  local function singlePass(menu)
    local rectangle,count=love.graphics.rectangle,0
    love.graphics.rectangle=function(mode,x,y,w,h,...)
      if mode=='fill' and x==0 and y==0 and h==16 then count=count+1 end
      return rectangle(mode,x,y,w,h,...)
    end
    love.graphics.push('all')
    game:drawScene(love.graphics.getDimensions())
    love.graphics.pop()
    love.graphics.rectangle=rectangle
    check(count==1,'withdraw header drawn once, observed '..count)
  end
  game.save.pcItems={RARE_CANDY=99,EXP_SHARE=1,OLD_ROD=1,IRON=5}
  game.save.inventory={}
  opts['bag.skin']='modern'
  for _,house in ipairs({false,true}) do
    while game.stack:top() do game.stack:pop() end
    local menu=Screens.push(game,'Gen2ItemPcMenu',{save=game.save,house=house})
    menu.message=nil;menu.repeatSfx=nil
    menu:setPhase('withdraw');menu:rebuild()
    for _,size in ipairs({{'wide',1280,720,'16:9'},{'4x3',1088,480,'4:3'},{'compact',800,720,'fill'},{'phone',480,900,'fill'}}) do
      opts['bag.aspect_ratio']=size[4]
      love.window.setMode(size[2],size[3],{resizable=true,vsync=0})
      U.wait(3)
      check(U.shot(game,os.getenv('SHOT_DIR')..'/'..(house and 'house-' or 'center-')..size[1]..'.png'),'captured '..size[1])
      singlePass(menu)
      check(not love.window.hasFocus() and love.audio.getVolume()==0,'muted and unfocused')
    end
    for i,row in ipairs(menu.rows) do if row.id=='RARE_CANDY' then menu.listIndex=i end end
    press(menu,'a')
    check(menu.qtyState~=nil,'withdraw opens quantity')
    press(menu,'b')
    check(game.save.pcItems.RARE_CANDY==99,'cancel preserves stored items')
    press(menu,'a');press(menu,'a')
    check(game.save.inventory.RARE_CANDY==1 and game.save.pcItems.RARE_CANDY==98,'withdraw transfers exactly one item')
    menu.message=nil;menu.typer=nil
    game.save.inventory={POTION=3};game.save.bagOrder={'POTION'}
    menu:enterDeposit()
    check(menu.pack~=nil,'deposit opens native Pack chooser')
    for _,ratio in ipairs({'16:9','fill'}) do
      opts['bag.aspect_ratio']=ratio
      U.wait(3)
      check(U.shot(game,os.getenv('SHOT_DIR')..'/'..(house and 'house-' or 'center-')..'deposit-'..ratio:gsub(':','x')..'.png'),'captured deposit '..ratio)
    end
    menu:offerToDeposit('POTION',3)
    check(menu.qtyState~=nil,'deposit opens quantity')
    check(U.shot(game,os.getenv('SHOT_DIR')..'/'..(house and 'house-' or 'center-')..'deposit-quantity.png'),'captured deposit quantity')
    press(menu,'b');check(game.save.inventory.POTION==3,'cancel deposit preserves inventory')
    menu:offerToDeposit('POTION',3);press(menu,'a')
    check(game.save.inventory.POTION==2 and game.save.pcItems.POTION==1,'deposit transfers exactly one item')
    menu.message=nil;menu.typer=nil;menu.pack=nil
    menu:setPhase('toss');menu:rebuild()
    for i,row in ipairs(menu.rows) do if row.id=='RARE_CANDY' then menu.listIndex=i end end
    press(menu,'a');press(menu,'a')
    check(menu.confirm~=nil,'toss asks for confirmation')
    check(U.shot(game,os.getenv('SHOT_DIR')..'/'..(house and 'house-' or 'center-')..'toss-confirm.png'),'captured toss confirmation')
    press(menu,'b');check(game.save.pcItems.RARE_CANDY==98,'cancel toss preserves stored items')
    game.save.pcItems.RARE_CANDY=99;game.save.pcItems.POTION=nil;game.save.inventory={}
  end
  print('[DISCORD QA] PASS '..checks..' item PC checks');love.event.quit(0)
end
