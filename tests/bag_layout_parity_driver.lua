return function(game)
  local U=dofile(assert(os.getenv('PC_REPO'))..'/tests/drivers/util.lua')
  local Screens=require('src.ui.Screens')
  local Bag=require('src.inventory.Bag')
  local gen2=require('src.core.GameVersion').generation()==2
  local opts=game.mods.modOptions.modern_ui_suite
  local checks=0
  local function check(ok,label)checks=checks+1;assert(ok,label);print('[BAG PARITY] '..label)end
  local function press(menu,key)
    local old=game.input
    game.input=setmetatable({wasPressed=function(_,k)return k==key end,isDown=function()return false end},{__index=old})
    local ok,err=pcall(menu.update,menu,0);game.input=old;assert(ok,err)
  end
  local function shot(name,w,h)
    if w then love.window.setMode(w,h,{resizable=true,vsync=0})end
    U.wait(3)
    check(U.shot(game,os.getenv('SHOT_DIR')..'/'..name..'.png'),'captured '..name)
    check(not love.window.hasFocus() and love.audio.getVolume()==0,'muted and unfocused')
  end
  local function clear()while game.stack:top() do game.stack:pop() end end
  game.save.inventory={};game.save.bagOrder=nil;game.save.money=999999
  local seed={'POTION','ANTIDOTE','SUPER_POTION','HYPER_POTION','REVIVE','FULL_HEAL','RARE_CANDY','REPEL','ESCAPE_ROPE','FIRE_STONE','NUGGET','POKE_BALL','GREAT_BALL','BICYCLE','OLD_ROD'}
  for _,id in ipairs(seed)do check(Bag.add(game.save,id,7,game.data),'seeded '..id)end
  local tm
  for id,def in pairs(game.data.items)do if type(def)=='table' and (def.machine or def.teaches) and id:find('TM') then tm=id;break end end
  if tm then check(Bag.add(game.save,tm,2,game.data),'seeded a machine')end
  opts['bag.skin']='modern';opts['bag.open_on']='all';opts['bag.aspect_ratio']='16:9'
  local function open(extra)
    clear();return Screens.push(game,gen2 and 'Gen2PackMenu' or 'BagMenu',extra or (gen2 and {save=game.save,world={useFieldItem=function()end}} or {}))
  end
  local bag=open()
  for i=1,6 do
    shot('pocket-'..i,1280,720)
    local l=bag:modernBagLayoutInfo()
    check(l.width==256 and l.listX==4 and l.listY==39 and l.rows==6,'Gen 1 geometry in pocket '..i)
    check(l.showDetails and l.detailX==142,'right detail card in pocket '..i)
    check(bag:modernBagQolInfo().headerCash=='¥999999','maximum money remains exact')
    press(bag,'right')
  end
  local function select(id)
    for i,row in ipairs(gen2 and bag.rows or bag.items)do if (row.id or row.value)==id then bag.index=i;break end end
    if gen2 then bag:ensureVisible()end
  end
  select('POTION');press(bag,'a');shot('actions')
  if gen2 then
    check(bag.submenu~=nil,'native actions open')
    for i,id in ipairs(bag.submenu.rows)do if id=='toss' then bag.submenu.index=i end end
    press(bag,'a');shot('toss-quantity')
    check(bag.qtyState~=nil,'native toss quantity opens')
    press(bag,'up');press(bag,'a');shot('toss-confirm')
    check(bag.confirm~=nil,'native toss asks for confirmation')
    press(bag,'b');U.wait(2)
    check(game.save.inventory.POTION==7,'cancelled toss preserves inventory')
    bag=open();select('POTION')
    press(bag,'select');shot('reorder');check(bag.switching~=nil,'native reorder is armed')
    press(bag,'down');press(bag,'a');check(not bag.switching,'reorder finishes')
  else
    press(game.stack:top(),'b');bag=game.stack:top()
  end
  bag=open();press(bag,'start');shot('sort')
  if gen2 then check(bag.modernBagSortMenu~=nil,'Start opens native sorting');press(bag,'b')
  else press(game.stack:top(),'b')end
  opts['bag.aspect_ratio']='4:3';shot('compact',800,720)
  check(bag:modernBagLayoutInfo().width==192 and not bag:modernBagLayoutInfo().showDetails,'compact matches Gen 1')
  opts['bag.aspect_ratio']='fill';shot('portrait',480,900)
  check(bag:modernBagLayoutInfo().stacked,'portrait stacks list and details')
  -- Item with a long description retains every word in the shared marquee.
  opts['bag.aspect_ratio']='16:9';select('POTION')
  game.data.items.POTION.description=('This medicine restores health and preserves every word on a long journey. '):rep(4)..'FINAL WORDS'
  shot('description-start',1280,720)
  check(bag:modernBagQolInfo().descriptionOverflow,'long description scrolls')
  bag:update(3);shot('description-scroll')
  check(bag:modernBagQolInfo().descriptionOffset>0,'long description advances')
  if gen2 then
    -- Hit regions must be registered in the window transform, outside the
    -- shared grayscale canvas. First touch selects; second touch confirms.
    opts['bag.direct_touch']=true
    bag=open();shot('touch-ready')
    local function tap(x,y)
      local w,h=love.graphics.getDimensions()
      local scale=math.floor(math.min(w/256,h/144))
      x,y=(w-256*scale)/2+x*scale,(h-144*scale)/2+y*scale
      game:pointerEvent('pressed','touch','bag-parity',x,y,0,0,1)
      game:pointerEvent('released','touch','bag-parity',x,y,0,0,1)
    end
    tap(105,25);check(bag.modernBagPocketIndex==3,'touch opens Medicine icon')
    U.wait(2);tap(30,65);check(bag.index==2 and not bag.submenu,'touch selects visible second row')
    tap(30,65);check(bag.submenu~=nil,'second touch opens native actions')
    local pocket=bag.modernBagPocketIndex;tap(25,25)
    check(bag.modernBagPocketIndex==pocket,'modal blocks background pocket touches')
    local chosen
    bag=open({save=game.save,battle=true,pocket='ITEM',onChoose=function(id)chosen=id end})
    bag:modernBagSwitchPocket(3-bag.modernBagPocketIndex)
    select('POTION');press(bag,'a');shot('battle-actions')
    check(table.concat(bag.submenu.rows,',')=='use,quit','battle retains native USE/QUIT actions')
    press(bag,'a');check(chosen=='POTION','battle callback receives selected item')
    check(game.save.inventory.POTION==7,'presentation does not consume battle items')
    bag=open();select('POTION')
    for _=1,12 do press(bag,'down') end
    shot('scrolled-list')
    check(bag.scroll>0 and bag.index<=bag.scroll+bag:modernBagLayoutInfo().rows,'scroll matches all six rendered rows')
  end
  -- Empty all-items view and each empty pocket use the same empty-state card.
  game.save.inventory={};game.save.bagOrder=nil;bag=open();shot('empty')
  if gen2 then
    opts['bag.skin']='classic_pocket';bag=open();shot('native-pocket-skin')
    check(bag:modernBagLayoutInfo().layout=='native','Pocket skin remains native')
    opts['bag.skin']='modern'
    clear()
    local naming=Screens.push(game,'Gen2NamingScreen',{type='nickname',monName='CYNDAQUIL',onDone=function()end})
    shot('rename-empty');press(naming,'a');shot('rename-typed')
    check(naming.text=='A','rename still accepts a letter')
  end
  print('[DISCORD QA] PASS '..checks..' Bag parity checks');love.event.quit(0)
end
