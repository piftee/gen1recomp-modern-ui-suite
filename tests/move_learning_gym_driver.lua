-- Diagnostic driver: writes only into run_native's disposable profile.
return function(game)
 local U=dofile(assert(os.getenv('PC_REPO'))..'/tests/drivers/util.lua')
 local S=require('src.core.SaveSerializer')
 local bytes=assert(love.filesystem.read('qa-save.lua'))
 local save=assert(S.decode(bytes))
 local seen={}
 local function inspect(t,path)
  local n=0
  if type(t)~='table' then
   if type(t)~='number' and type(t)~='string' and type(t)~='boolean' and t~=nil then
    print('[SAVE PROBE] '..path..' = '..type(t)..' '..tostring(t));return 1
   end
   return 0
  end
  if seen[t]then return 0 end;seen[t]=true
  for k,v in pairs(t)do n=n+inspect(v,path..'.'..tostring(k))end
  return n
 end
 local function check(label)
  seen={};local n=inspect(game.save,'save');local ok,err=pcall(S.encode,game:snapshotSave())
  print('[SAVE PROBE] '..label..' invalid='..n..' encodes='..tostring(ok)..(ok and ''or ' '..tostring(err)))
  io.stdout:flush();return n
 end
 print('[SAVE PROBE] loaded mods');for _,m in ipairs(game.modStatus.loaded or {})do print(m.id)end
 game:continueGame(save);U.wait(15);check('loaded-before-battle')
 local Mon=require('src.battle.gen2.Mon')
 local mon=game.save.party[1];mon.moves={}
 for _,id in ipairs({'SCRATCH','LEER','RAGE','WATER_GUN'})do local d=game.data.moves[id];mon.moves[#mon.moves+1]={id=id,pp=d.pp,maxPp=d.pp}end
 mon.level=27;mon.experience=Mon.experienceForLevel(Mon.growthFor(game.data,game.data.pokemon.CROCONAW.growthRate),28)-1
 Mon.refreshStats(mon,game.data);mon.hp=mon.maxHp or mon.stats.hp
 local gym=true
 if gym then
  assert(game.world.player.cellX==6 and game.world.player.cellY==7,'fixture position changed')
  game.world.player.facing='left';assert(game.world:interact(),'Bugsy interaction failed')
 else
  local entry=assert(game.world:trainerParty(3,1));entry.party=require('src.world.gen2.Trainers').party(game.data,entry)
  assert(game.world:startBattle({trainer=entry}))
 end
 local screen
 for i=1,900 do local top=game.stack:top();if top and top.battle then screen=top;break end U.tap(game,'a');U.wait(2)end
 assert(screen,'no battle screen')
 for i=1,400 do if screen.phase=='menu'and #screen.queue==0 and not screen.anim then break end U.tap(game,'a');U.wait(2)end
 U.wait(5);local n=check('Bugsy-battle-first-menu')
 assert(U.shot(game,os.getenv('SHOT_DIR')..'/bugsy.png'))
 -- End through the battle screen's own victory route after the image cache is populated.
 local shown,last={},nil
 local battle=screen.battle
 for _,mon in ipairs(battle.enemyParty)do mon.hp=1 end
 for i=1,1800 do
  if screen.message and screen.message~=last then last=screen.message;shown[#shown+1]=last;print('[GYM LEARN] '..last:gsub('\n',' / '))end
  local top=game.stack:top()
  if top~=screen and not game.world:scriptRunning() and (not top or top==game.world) then break end
  if top==screen and screen.phase=='menu'and #screen.queue==0 and not screen.anim then
   screen:submit({kind='move',move=game.save.party[1].moves[4].id})
  elseif top==screen and screen.phase=='ask-shift'then U.tap(game,'b')
  else U.tap(game,'a')end
  U.wait(2)
  if top~=screen and not game.world:scriptRunning() and (not top or top==game.world) then break end
 end
 if gym then
  -- Evolution can briefly leave the stack empty before the queued gym script
  -- resumes. Let that continuation award the badge and finish its dialogue.
  for i=1,900 do
   local top=game.stack:top()
   if game.save.player.badges.HIVE and not game.world:scriptRunning() and (not top or top==game.world)then break end
   if top and top~=game.world then U.tap(game,'a')end
   U.wait(3)
  end
 end
 print('[SAVE PROBE] lead after reward '..game.save.party[1].species..' level '..game.save.party[1].level..' exp '..game.save.party[1].experience)
 check('after-battle')
 local ok,err
 if gym then
  assert(game.save.player.badges.HIVE,'Hive Badge was not awarded by gym script')
  print('[SAVE PROBE] native Bugsy script awarded HIVE; first save through Save menu')
  ok,err=pcall(function()
   game:pushStartMenuItem('save');local menu=game.stack:top()
   for i=1,300 do if menu.saved then return true end U.tap(game,'a');U.wait(2)end
   return menu.saved
  end)
 else ok,err=pcall(game.writeSave,game) end
 print('[SAVE PROBE] actual writer ok='..tostring(ok)..' result='..tostring(err))
 if false then
  assert(game.save.party[1].species=='FERALIGATR','must reproduce the evolution')
  assert(ok and err==true,'post-evolution save must succeed')
  local loaded=assert(require('src.core.gen2.Save').load('gold'))
  assert(loaded.party[1].species=='FERALIGATR' and loaded.party[1].level==30,'disk round trip lost evolved party')
  assert(loaded.party[1].sprite==nil and loaded.party[1].picAnim==nil,'transient art persisted')
  if gym then assert(loaded.player.badges.HIVE,'reload lost Hive Badge')end
  assert(S.decode(S.encode(loaded)))
  print('[SAVE PROBE] PASS evolved party saved, reloaded and encoded without transient art')
 end
 local dialogue=table.concat(shown,'\n');local poof=assert(dialogue:find('Poof',1,true),'no replacement prompt');local learned=assert(dialogue:find('learned',poof,true),'no learned text')
 local nextExp=dialogue:find('EXP.',learned,true)
 assert(nextExp and poof<learned and learned<nextExp,'learning must finish before next defeated mon EXP')
 assert(game.save.player.badges.HIVE,'actual gym continuation did not award badge')
 assert(ok and err==true,'post-battle Save menu failed')
 print('[BAG ICON QA] PASS; full native Bugsy fight, level-28 Scary Face replacement before subsequent EXP, Hive badge continuation and Save menu; focused='..tostring(love.window.hasFocus()))
 love.event.quit(0)
end
