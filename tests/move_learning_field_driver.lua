return function(game)
 local U=dofile(assert(os.getenv('PC_REPO'))..'/tests/drivers/util.lua')
 local S=require('src.core.SaveSerializer')
 local bytes=assert(love.filesystem.read('qa-save.lua'));game:continueGame(assert(S.decode(bytes)));U.wait(15)
 local TB=require('src.render.TextBox');local Choice=require('src.ui.ChoiceBox')
 local raw=TB.new;local textOf=setmetatable({},{__mode='k'})
 TB.new=function(g,text,...)local t=raw(g,text,...);textOf[t]=text;return t end
 local mon=game.save.party[1]
 local function seed()
  mon.moves={}
  for _,id in ipairs({'SCRATCH','LEER','RAGE','WATER_GUN'})do local d=assert(game.data.moves[id]);mon.moves[#mon.moves+1]={id=id,pp=d.pp,maxPp=d.pp}end
 end
 local function run(mode)
  seed();local done,learned=0,nil;local seen,last={},nil;local cancel=false;local declined=false
  game:learnMoveOn(mon,'ICE_PUNCH',function(ok)
   done=done+1;learned=ok;seen[#seen+1]='CALLBACK';game:say('QA: teaching continuation')
  end)
  for i=1,1500 do
   local top=game.stack:top();if not top then break end
   local text=textOf[top]
   if text and top.pages then
    local key=tostring(top)..':'..tostring(top.pageIndex)
    if key~=last then last=key;local page=table.concat(top.pages[top.pageIndex]or{},' / ');seen[#seen+1]=page end
   end
   local isList=top.mon==mon and top.onChoose and top.list
   if isList and mode=='cancel' and not cancel then cancel=true;U.tap(game,'b')
   elseif getmetatable(top)==Choice and mode=='decline' and not declined then declined=true;U.tap(game,'b')
   else U.tap(game,'a')end
   U.wait(2)
  end
  assert(not game.stack:top(),'teaching flow stuck '..mode)
  assert(done==1,'callback count '..mode)
  local joined=table.concat(seen,'\n')
  print('[FIELD '..mode..']\n'..joined)
  if mode=='accept' then
   assert(learned==true and mon.moves[1].id=='ICE_PUNCH')
   local poof=assert(joined:find('Poof',1,true));local forgot=assert(joined:find('forgot',poof,true));local learnedAt=assert(joined:find('learned',forgot,true));local cb=assert(joined:find('CALLBACK',1,true))
   assert(poof<forgot and forgot<learnedAt and learnedAt<cb,'field order')
  else
   assert(learned==false and mon.moves[1].id=='SCRATCH')
   assert(joined:find('Stop learning',1,true) and joined:find('did not learn',1,true) and not joined:find('Poof',1,true))
  end
 end
 run('accept');run('cancel');run('decline')
 -- Exercise the real TM party chooser and consumption continuation too.
 seed();local item
 for id,def in pairs(game.data.items)do
  if id:match('^TM_') and def.teaches=='ICE_PUNCH'then item=id;break end
 end
 assert(item,'ICE PUNCH machine missing');game.save.inventory[item]=1
 game:useFieldItem(item)
 for i=1,1500 do if not game.stack:top()then break end;U.tap(game,'a');U.wait(2)end
 assert(not game.stack:top() and mon.moves[1].id=='ICE_PUNCH','TM party flow failed')
 assert(game.save.inventory[item]==1,'enabled reusable TMs changed')
 print('[BAG ICON QA] PASS; TM teaching, field replacement order, cancel, decline, one continuation, reusable TM; focused='..tostring(love.window.hasFocus()))
 love.event.quit(0)
end
