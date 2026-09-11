package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local active=true
local full='Contact may paralyze the foe. This extra sentence must survive provider pagination.'
local page={gender='♀',heldItem='BERRY',abilityId='STATIC',ability='STATIC',description={'Contact may'}}
package.loaded['mods.Kanto-Reforged.ui.summary_ui']={GEN2_ABILITY_PAGE=4,abilityPage=function() return page end}
package.loaded['mods.Kanto-Reforged.battle.ability_text']={describe=function() return full end}
package.loaded['src.render.Font']={width=function(s) return #s*8 end,split=function(s)
 local spans={};for i=1,#s do spans[i]={from=i,to=i} end;return spans end,
 spansFitting=function(_,w) return math.floor(w/8) end}
local api=dofile('mods/modern_ui_suite/core/summary_extensions.lua')({find=function() return active end})
local screen={page=4,mon={species='ELEKID'},game={data={}}}
local data=api.page(screen,2)
T.eq(data.description,full,'full ability description replaces first-page excerpt')
T.eq(data.gender,'F','gender uses supported font characters')
T.neq(data,page,'provider data is copied');T.eq(page.gender,'♀','provider data unchanged')
screen.page=5;T.eq(api.page(screen,2),nil,'unknown extra page uses native fallback')
screen.page=4;screen.mon.isEgg=true;T.eq(api.page(screen,2),nil,'eggs do not expose abilities')
screen.mon.isEgg=nil;active=false;T.eq(api.page(screen,2),nil,'disabled provider cannot leak page')
active=true;screen.modernKantoPage=4;T.check(api.page(screen,1)~=nil,'Gen1 appended provider page supported')
local lines=api.lines(full,80)
for _,line in ipairs(lines) do T.check(#line<=10,'description line fits card') end
T.eq(table.concat(lines):gsub(' ',''),full:gsub(' ',''),'wrapped description preserves all characters')
T.same(api.lines('SUPERCALIFRAGILISTIC',40),{'SUPER','CALIF','RAGIL','ISTIC'},'long words split safely')
T.same(api.lines('',80),{},'missing ability text is safe')
T.finish('suite_summary_extensions')
