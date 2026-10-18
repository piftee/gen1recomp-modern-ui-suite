-- Pure Lua: the real compatibility installer around native-contract doubles.
local root=arg[1] or 'mods/modern_ui_suite'
local generation=2
package.loaded['src.core.GameVersion']={generation=function()return generation end}
local Battle={}
function Battle:resolveForget(valid)
 if not valid then return false end
 for _,text in ipairs({'1, 2','forgot','learned'})do self.events[#self.events+1]={text=text}end
 return true
end
function Battle:takeEvents() local out=self.events;self.events={};return out end
local Screen={}
function Screen:pushAll(events)for _,v in ipairs(events or {})do self.queue[#self.queue+1]=v end end
function Screen:pushFront(events)for i=#(events or {}),1,-1 do table.insert(self.queue,1,events[i])end end
package.loaded['src.battle.gen2.Battle']=Battle
package.loaded['src.ui.gen2.BattleState']=Screen
local install=assert(loadfile(root..'/core/move_learning_order.lua'))()
install()
local function fixture()return setmetatable({events={}},{__index=Battle}),setmetatable({queue={{text='next EXP'},{text='trainer'}}},{__index=Screen})end
local function order(s)local t={}for _,v in ipairs(s.queue)do t[#t+1]=v.text end return table.concat(t,',')end
local b,s=fixture();assert(b:resolveForget(true));s:pushAll(b:takeEvents());assert(order(s)=='1, 2,forgot,learned,next EXP,trainer')
b,s=fixture();b:resolveForget(true);s:pushFront(b:takeEvents());assert(order(s)=='1, 2,forgot,learned,next EXP,trainer')
b,s=fixture();b.events={{text='earlier'}};b:resolveForget(true);s:pushAll(b:takeEvents());assert(order(s)=='next EXP,trainer,earlier,1, 2,forgot,learned')
b,s=fixture();assert(not b:resolveForget(false));s:pushAll(b:takeEvents());assert(order(s)=='next EXP,trainer')
b,s=fixture();s:pushAll({{text='normal'}});assert(order(s)=='next EXP,trainer,normal')
b,s=fixture();b:resolveForget(true);local e=b:takeEvents();s:pushAll(e);s.queue={};s:pushAll(e);assert(order(s)=='1, 2,forgot,learned')
local installed=Battle.resolveForget;install();assert(Battle.resolveForget==installed)
generation=1;Battle._modernLearningOrder=nil;install();assert(Battle.resolveForget==installed and not Battle._modernLearningOrder)
print('PASS 8 learning-order cases: companion append, native prepend, pre-existing events, invalid selection, normal events, one-shot batch, idempotence, Gen I')
