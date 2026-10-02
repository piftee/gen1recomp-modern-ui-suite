-- Public summary controls; disposable, muted native profiles only.
return function(game)
  local U = dofile(os.getenv('PC_REPO') .. '/tests/drivers/util.lua')
  local Screens = require('src.ui.Screens')
  local gen2 = require('src.core.GameVersion').generation() == 2
  local Mon = require(gen2 and 'src.battle.gen2.Mon' or 'src.pokemon.Pokemon')
  local checks = 0
  local function check(ok, label) assert(ok, label); checks = checks + 1 end
  local mon = Mon.new(game.data, 'PIKACHU', 25)
  local first = {id='THUNDERSHOCK', pp=7, ppUps=2, maxPp=48, qaTag='first'}
  local second = {id='GROWL', pp=13, ppUps=1, maxPp=48, qaTag='second'}
  mon.moves = {first, second}
  game.save.party = {mon}
  local function open()
    while game.stack:top() do game.stack:pop() end
    local menu = gen2 and Screens.push(game, 'Gen2SummaryMenu', {save=game.save,mon=mon})
      or Screens.push(game, 'SummaryMenu', mon)
    menu.page = gen2 and require('src.ui.gen2.SummaryMenu').GREEN_PAGE or 2
    menu.whiteHold = 0
    return menu
  end
  local function press(menu, key)
    local input, previous = game.input, game.input.wasPressed
    input.wasPressed = function(_, candidate) return candidate == key end
    menu:update(1/60)
    input.wasPressed = previous
    U.wait(30)
  end
  local function index(menu) return gen2 and menu.moveIndex or menu.modernMoveIndex end
  local function held(menu) return gen2 and menu.swapFrom or menu.modernSwapFrom end
  for _, size in ipairs({{1280,720,'wide'},{640,576,'compact'},{480,900,'portrait'}}) do
    love.window.setMode(size[1],size[2],{resizable=true,vsync=0})
    local menu = open(); U.wait(30)
    press(menu,'select')
    if gen2 then press(menu,'a') end
    check(held(menu)==1, size[3]..' picks first move')
    local horizontal = gen2 and (menu.modernPartyWideWidth or menu.modernPartyLastWideWidth or 160)>=196
      or not gen2 and menu:modernSummaryLayoutInfo().moveColumns==2
    press(menu,horizontal and 'right' or 'down')
    check(index(menu)==2,size[3]..' navigation reaches second move')
    check(U.shot(game,os.getenv('SHOT_DIR')..'/swap-'..size[3]..'.png'),'capture held move')
    press(menu,'a')
    check(mon.moves[1]==second and mon.moves[2]==first,'whole move entries exchanged')
    check(mon.moves[2].pp==7 and mon.moves[2].ppUps==2
      and mon.moves[2].qaTag=='first','PP and metadata travel with move')
    check(not held(menu),'swap finishes')
    if gen2 then press(menu,'a') else press(menu,'select') end
    check(held(menu)==2,'can pick swapped move')
    press(menu,'b')
    check(not held(menu) and index(menu)==2,'B cancels without leaving screen')
    check(mon.moves[1]==second and mon.moves[2]==first,'cancellation preserves moves')
    menu = open(); U.wait(10)
    check(mon.moves[1]==second and mon.moves[2]==first,'reopening retains order')
    local Serializer = require('src.core.SaveSerializer')
    local restored = assert(Serializer.decode(Serializer.encode({party={mon}})))
    check(restored.party[1].moves[1].id=='GROWL'
      and restored.party[1].moves[2].pp==7
      and restored.party[1].moves[2].ppUps==2,'save roundtrip retains order and PP')
    mon.moves={first,second}
  end
  if not gen2 then
    local menu=open(); U.wait(10)
    menu.modernMoveIndex=3; press(menu,'select')
    check(not held(menu),'empty slot cannot start swap')
    menu.modernMoveIndex=1; press(menu,'select')
    menu.modernMoveIndex=3; press(menu,'a')
    check(held(menu)==1 and #mon.moves==2,'empty destination cannot delete a move')
    press(menu,'select'); check(not held(menu),'Select cancels')
    menu.modernMoveIndex=1; press(menu,'a')
    check(menu.modernMoveDetail,'A still opens move information')
    press(menu,'b'); check(not menu.modernMoveDetail,'B returns from information')
  end
  local raw = assert(require('src.link.Json').decode(assert(love.filesystem.read('mods/modern_ui_suite/manifest.json'))))
  local manifest = require('src.mods.Manifest').validate(raw,'mods/modern_ui_suite')
  local ribbon
  for _, spec in ipairs(manifest.optionalSpecs) do if spec.id=='kanto_ribbons' then ribbon=spec end end
  local Targets=require('src.mods.ModTargets')
  check(ribbon and Targets.specApplies(ribbon,'red',1),'Ribbons optional ordering retained')
  local verdict = require('src.mods.LauncherMods').checkDependencies(manifest,
    {mods={modern_ui_suite=true}},gen2 and 'crystal' or 'red',{manifest})
  check(not verdict.hasIssues,'absent optional Ribbons does not block loading')
  check(#manifest.dependencySpecs==0,'companions remain optional')
  check(not love.window.hasFocus() and love.audio.getVolume()==0,'silent background run')
  print('[DISCORD QA] PASS '..checks..' summary move-order checks')
  love.event.quit(0)
end
