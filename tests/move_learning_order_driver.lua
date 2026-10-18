-- Controlled fixtures in the real Gold runtime; never writes a player profile.
return function(game)
 local U=dofile(assert(os.getenv('PC_REPO'))..'/tests/drivers/util.lua')
 local S=require('src.core.SaveSerializer')
 local Mon=require('src.battle.gen2.Mon')
 local saveBytes=assert(love.filesystem.read('qa-save.lua'))
 game:continueGame(assert(S.decode(saveBytes)))
 U.wait(15)
 local mon=game.save.party[1]
 mon.moves={}
 for _,id in ipairs({'SCRATCH','LEER','RAGE','WATER_GUN'})do local d=assert(game.data.moves[id]);mon.moves[#mon.moves+1]={id=id,pp=d.pp,maxPp=d.pp}end
 mon.species='CROCONAW';mon.level=27
 local def=game.data.pokemon.CROCONAW
 mon.experience=Mon.experienceForLevel(Mon.growthFor(game.data,def.growthRate),28)-1
 Mon.refreshStats(mon,game.data);mon.hp=mon.maxHp or mon.stats.hp
 local entry=assert(game.world:trainerParty(3,1));entry.party=require('src.world.gen2.Trainers').party(game.data,entry)
 assert(game.world:startBattle({trainer=entry}))
 local screen
 for i=1,1000 do local t=game.stack:top();if t and t.battle then screen=t end;if screen and screen.phase=='menu' and #screen.queue==0 and not screen.anim then break end;U.tap(game,'a');U.wait(2)end
 assert(screen and screen.phase=='menu','battle did not open')
 local b=screen.battle
 b.events={};screen.queue={}
 b:giveExperiencePass(b.enemy,game.data.pokemon[b.enemy.species],{1},1,false)
 local got=false
 for _,ev in ipairs(b.events)do print('[LEARN EVENT] '..tostring(ev.kind)..' '..tostring(ev.text or ev.moveName));if ev.kind=='choose-forget'then got=true end end
 assert(got,'fixture did not naturally level into a full-set move')
 b:emit({kind='message',text='QA: next party EXP dialogue'})
 b:emit({kind='message',text='QA: trainer dialogue after learning'})
 screen:pushAll(b:takeEvents());screen.phase='resolving';screen:advanceQueue()
 local cancel=love.filesystem.getInfo('qa-cancel-learning')~=nil
 local seen,last={},nil
 for i=1,2400 do
  local msg=screen.message
  if msg and msg~=last then seen[#seen+1]=msg;print('[LEARN SHOWN] '..msg:gsub('\n',' / '));last=msg end
  if screen.phase=='choose-forget' and (screen.messageTimer or 0)<=0 then
   assert(U.shot(game,os.getenv('SHOT_DIR')..'/forget-list.png'))
   U.tap(game,cancel and 'b' or 'a')
  elseif screen.phase=='menu' and #screen.queue==0 then break
  else U.tap(game,'a')end
  U.wait(2)
 end
 local order=table.concat(seen,'\n')
 if cancel then
  assert(not order:find('Poof',1,true),'cancel must not forget')
  local decline=assert(order:find('did not learn',1,true));local after=assert(order:find('QA: next',1,true))
  assert(decline<after and mon.moves[1].id=='SCRATCH','cancel result order or moves changed')
  print('[BAG ICON QA] PASS; native battle B cancel, stop-learning confirmation, decline before continuation; focused='..tostring(love.window.hasFocus()))
  love.event.quit(0);return
 end
 local poof=assert(order:find('Poof',1,true),'poof missing')
 local learned=assert(order:find('learned',1,true),'learned missing')
 local after=assert(order:find('QA: next',1,true),'continuation missing')
 local correct=poof<learned and learned<after
 print('[LEARN ORDER] correct='..tostring(correct)..' mon='..mon.species..' level='..mon.level)
 assert(mon.moves[1].id=='SCARY_FACE','wrong move replacement')
 if love.filesystem.getInfo('qa-expect-learning-fixed')then assert(correct,'forget/learn must precede continuation')else assert(not correct,'baseline did not reproduce reported order')end
 local f=assert(io.open(os.getenv('SHOT_DIR')..'/dialogue.txt','w'));f:write(order);f:close()
 print('[BAG ICON QA] PASS; learning-order diagnostic; focused='..tostring(love.window.hasFocus()))
 love.event.quit(0)
end
