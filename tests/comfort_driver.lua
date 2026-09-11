return function(game)
  local U=dofile(assert(os.getenv('PC_REPO'))..'/tests/drivers/util.lua')
  local Runtime=require('src.mods.Runtime')
  local Screens=require('src.ui.Screens')
  local Font=require('src.render.Font')
  local gen2=require('src.core.GameVersion').generation()==2
  local opts=game.mods.modOptions.modern_ui_suite
  local checks=0
  local function check(ok,label)checks=checks+1;assert(ok,label);print('[COMFORT] '..label)end
  local function clear()while game.stack:top()do game.stack:pop()end end
  local function press(menu,key)
    local old=game.input
    game.input=setmetatable({wasPressed=function(_,k)return k==key end,isDown=function()return false end},{__index=old})
    local ok,err=pcall(menu.update,menu,0);game.input=old;assert(ok,err)
  end
  local writes={}
  local draw=Font.draw
  Font.draw=function(text,...) writes[tostring(text)]=true;return draw(text,...)end
  local function shot(name)
    writes={};U.wait(3)
    check(U.shot(game,os.getenv('SHOT_DIR')..'/'..name..'.png'),'captured '..name)
    check(not love.window.hasFocus() and love.audio.getVolume()==0,'muted and unfocused')
  end
  love.window.setMode(1088,480,{resizable=true,vsync=0})
  opts['bag.shop_counts']=true
  game.save.inventory={POTION=8};game.save.bagOrder={'POTION'};game.save.money=10000
  clear()
  local shop
  if gen2 then
    shop=Screens.push(game,'Gen2MartMenu',{save=game.save})
    shop.entries={{id='POTION',name=game.data.items.POTION.name,price=game.data.items.POTION.price}}
    shop:enterBuy()
  else
    local root=require('src.ui.ShopMenu').new(game,{'POTION','ANTIDOTE'})
    game.stack:push(root);root.items[1].onSelect();shop=game.stack:top()
  end
  check(shop.modernShopCount,'native shop controller is decorated')
  shot('shop-owned');check(writes['OWN 8'],'selected item count is shown')
  press(shop,'a');shot('shop-quantity')
  press(gen2 and shop or game.stack:top(),'b')
  check(game.save.inventory.POTION==8,'cancel purchase retains inventory')
  press(shop,'a')
  if gen2 then
    press(shop,'a')
    -- Native confirmation consumes one press after its text is complete.
    shop.typer=nil;press(shop,'a')
  else
    press(game.stack:top(),'a');press(game.stack:top(),'a');U.wait(20)
  end
  check(game.save.inventory.POTION==9,'native purchase adds exactly one item')
  if gen2 then shop.message=nil;shop.confirm=nil;shop.typer=nil
  else while game.stack:top()~=shop do game.stack:pop()end end
  shot('shop-after-purchase');check(writes['OWN 9'],'count refreshes after purchase')
  opts['bag.shop_counts']=false;shot('shop-disabled');check(not writes['OWN 9'],'setting disables count immediately')
  clear()
  game.mods.exports.modern_ui_suite.settings.open(game)
  local hub=game.stack:top()
  check(hub.items[12].id=='sprite_help','single sprite-help entry')
  hub.onChoose(hub.items[12],hub)
  local help=game.stack:top()
  check(help~=hub,'sprite help opens native text')
  U.wait(45)
  shot('sprite-info')
  clear()
  if not gen2 then
    opts['bag.skin']='classic_pocket';opts['bag.aspect_ratio']='16:9'
    local bag=Screens.push(game,'BagMenu',{})
    for i=1,6 do shot('pocket-label-'..i);press(bag,'right')end
  end
  clear()
  opts['start_menu.area_names']=true
  if gen2 then game.phase='play';game.world.mapSign=nil;game.world.mapSetup=nil;game.world.textbox=nil
  else game.stack:push(game.overworld,'PALLET_TOWN',5,8,'down',{via='boot'})end
  Runtime.emit('map.entered',{game=game,mapId='ROUTE_29',map={def={name='Route 29'}},via='warp'})
  shot('area-name');check(writes['Route 29'],'area name appears in the overworld')
  Runtime.call('input.step',function()end,game,2.1)
  shot('area-expired');check(not writes['Route 29'],'area name expires')
  Font.draw=draw
  print('[DISCORD QA] PASS '..checks..' comfort checks');love.event.quit(0)
end
