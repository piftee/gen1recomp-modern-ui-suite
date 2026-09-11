return function(game)
  local U=dofile(assert(os.getenv('PC_REPO'))..'/tests/drivers/util.lua')
  local Mon=require('src.battle.gen2.Mon')
  local Battle=require('src.battle.gen2.Battle')
  local View=require('src.ui.gen2.BattleAnimView')
  local Screens=require('src.ui.Screens')
  local opts=game.mods.modOptions.modern_ui_suite
  local checks=0
  local function check(ok,label) checks=checks+1;assert(ok,label);print('[BATTLE VIEWPORT] '..label) end
  while game.stack:top() do game.stack:pop() end
  if game.world and game.world.setMap then
    if not game.world.maps then assert(game.world:load()) end
    assert(game.world:setMap('ROUTE_29',12,8,'down'))
  end
  game.save.party={Mon.new(game.data,'QUILAVA',22)}
  local mon=game.save.party[1]
  mon.moves={}
  for _,id in ipairs({'EMBER','QUICK_ATTACK','LEER','SMOKESCREEN'}) do mon.moves[#mon.moves+1]={id=id,pp=20,maxPp=30} end
  local battle=Battle.new({data=game.data,save=game.save,party=game.save.party,wild=Mon.new(game.data,'RATTATA',11)})
  local screen=Screens.push(game,'Gen2BattleState',{save=game.save,battle=battle,onDone=function()end})
  screen.slideFrame=View.SLIDE_FRAMES
  screen.showPlayerTrainer,screen.showEnemyTrainer=false,false
  screen.showEnemyHud,screen.showPlayerHud=true,true
  screen.ballRows,screen.queue={},{}
  screen.anim,screen.typer,screen.messagePages=nil,nil,nil
  for _,ratio in ipairs({'fill','16:9','4:3'}) do
    opts['battle_hud.aspect_ratio']=ratio
    for _,size in ipairs({{1088,480},{480,900}}) do
      love.window.setMode(size[1],size[2],{resizable=true,vsync=0})
      for _,mode in ipairs({'white','black','world'}) do
        game.options.battleBg=mode
        for _,phase in ipairs({'menu','moves'}) do
          screen.phase=phase;screen.messageTimer=0;screen.menuIndex=1;screen.moveIndex=2
          screen.message='What will you do?'
          U.wait(3)
          local name=ratio:gsub(':','x')..'-'..size[1]..'-'..mode..'-'..phase
          check(U.shot(game,os.getenv('SHOT_DIR')..'/'..name..'.png'),'captured '..name)
          local v=screen.modernBattleViewport
          check(v and v.width==screen:panelSize(),'surround uses the rendered panel width')
          check(screen:battlePanelScale(size[1],size[2])==v.scale,'surround and prompts share the render scale')
          if ratio~='fill' then check(v.width==(ratio=='4:3' and 192 or 256),'selected aspect ratio is applied') end
          check(v.x>=0 and v.y>=0 and v.x+v.width*v.scale<=size[1],'viewport fits the display')
          check(not love.window.hasFocus() and love.audio.getVolume()==0,'muted and unfocused')
        end
      end
    end
  end
  opts['battle_hud.aspect_ratio']='4:3'
  love.window.setMode(480,900,{resizable=true,vsync=0})
  for _,mode in ipairs({'disabled','text-only'}) do
    opts['move_colors.battle_colors']=mode~='disabled'
    opts['move_colors.text_only']=mode=='text-only'
    screen.phase='moves';U.wait(3)
    check(U.shot(game,os.getenv('SHOT_DIR')..'/native-moves-'..mode..'.png'),'captured native moves '..mode)
    check(screen.modernBattleViewport.width==192,'native move list retains selected ratio')
    check(not love.window.hasFocus() and love.audio.getVolume()==0,'muted and unfocused')
  end
  opts['move_colors.battle_colors']=true;opts['move_colors.text_only']=false
  screen.phase='menu'
  local prompt=require('src.render.TextBox').new(game,'Choose a Pokemon.')
  game.stack:push(prompt);U.wait(2)
  local original,passes=screen.drawSceneBody,0
  screen.drawSceneBody=function(self,...)passes=passes+1;return original(self,...)end
  love.graphics.push('all');game:drawScene(love.graphics.getDimensions());love.graphics.pop()
  screen.drawSceneBody=original
  check(passes==1,'transparent prompt does not draw a second battle scene')
  check(U.shot(game,os.getenv('SHOT_DIR')..'/battle-prompt.png'),'captured native prompt')
  game.stack:pop()
  print('[DISCORD QA] PASS '..checks..' battle viewport checks');love.event.quit(0)
end
