package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local events, hooks = {}, {}
local mod = {id="modern_ui_suite", events={on=function(_,name,fn) events[name]=fn end},
  hooks={wrap=function(_,name,fn) hooks[name]=fn end}}
local dex = dofile("mods/modern_ui_suite/core/shiny_dex.lua")(mod)
local function game()
  return {data={pokemon={EEVEE={dex=133},VAPOREON={dex=134},PIKACHU={dex=25},RAICHU={dex=26}}},
    save={party={},boxes={},pokedex={seen={PIKACHU=true},owned={PIKACHU=true}},flags={EVENT_GOT_EEVEE=true}}}
end
local a,b=game(),game()
local eevee={species="EEVEE",dvs={attack=14,defense=10,speed=10,special=10}}
local pika={species="PIKACHU",shiny=true}
events['game.ready']({game=a})
T.eq(dex.has(a,'PIKACHU'),false,'ordinary caught flags do not invent shiny history')
T.eq(dex.has(a,'EEVEE'),false,'gift flags do not invent shiny history')
a.save.party={eevee,pika}
T.eq(dex.reconcile(a),2,'owned shiny flag and cartridge DVs both backfill')
T.eq(dex.reconcile(a),0,'backfill is idempotent')
T.eq(dex.has(b,'EEVEE'),false,'collection does not leak to another save')
a.save.party={}
T.check(dex.has(a,'EEVEE'),'release preserves collection history')
events['pokemon.evolved']({mon={species='VAPOREON',dvs=eevee.dvs},fromSpecies='EEVEE',toSpecies='VAPOREON'})
T.check(dex.has(a,'VAPOREON'),'evolved shiny is registered')
events['trade.completed']({received={species='RAICHU',shiny=true}})
T.check(dex.has(a,'RAICHU'),'received shiny is registered before later evolution')
events['game.ready']({game=b})
events['pokemon.caught']({game=b,mon={species='PIKACHU',shiny=true}})
T.check(dex.has(b,'PIKACHU'),'native catch event records its own save')
T.eq(dex.has(b,'RAICHU'),false,'switching saves retains independent history')
local egg={species='EEVEE',shiny=true,isEgg=true}
b.save.dayCare={man={mon=egg}}
dex.reconcile(b)
T.eq(dex.has(b,'EEVEE'),false,'unhatched egg does not count')
egg.isEgg=false
hooks['input.step'](function()end,b,0.5)
T.check(dex.has(b,'EEVEE'),'hatched or daycare-owned shiny is discovered')
b.save.hallOfFame={teams={{{species='VAPOREON',shiny=true}}}}
hooks['save.write'](function()end,b)
T.check(dex.has(b,'VAPOREON'),'historical shiny proof is saved')
T.eq(dex.record(b,{species='MISSING',shiny=true}),false,'unknown species ignored')
T.eq(dex.record(b,{species='RAICHU',dvs={attack=1,defense=10,speed=10,special=10}}),false,'non-shiny DVs ignored')
T.eq(dex.has(b,'RAICHU'),false,'negative evidence never becomes a catch')
local Serializer=require('src.core.SaveSerializer')
local encoded=assert(Serializer.encode(b.save.modData))
b.save.modData=assert(Serializer.decode(encoded))
T.check(dex.has(b,'EEVEE') and dex.has(b,'VAPOREON'),'history survives save serialization')
T.finish('Shiny collection history')
