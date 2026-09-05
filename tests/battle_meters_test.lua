package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Growth = require("src.pokemon.Growth")
local M = dofile("mods/modern_ui_suite/components/battle_info_hud/meters.lua")()
local data = T.fixtures.fresh()
local species = next(data.pokemon)
local def = data.pokemon[species]
local base = Growth.expForLevel(def.growthRate, 28, data.growth_rates)
local mon = {species=species,level=28,stats={hp=83},hp=69,exp=base+188}
local battler = {mon=mon,shownHP=40}
local hp,max,ratio = M.values(data,battler,"HP")
T.eq(hp,40,"animated HP is displayed instead of the final saved value")
T.eq(max,83,"maximum HP stays exact")
T.eq(ratio,40/83,"fill follows the same animated value as its readout")
battler.shownHP=0
T.eq(M.values(data,battler,"HP"),0,"zero does not fall through to saved HP")
battler.shownHP=1000
T.eq(M.values(data,battler,"HP"),83,"transient overshoot stays within the meter")
local current,needed,fraction,capped=M.values(data,battler,"XP")
T.eq(current,188,"EXP readout measures progress within the current level")
T.eq(needed,Growth.expForLevel(def.growthRate,29,data.growth_rates)-base,"EXP denominator uses live growth data")
T.eq(M.readout(188,2169,false,48),"188/2169","ordinary values are exact, without rounded K amounts")
for _, pair in ipairs({{0,1},{69,83},{99999,100000},{999999,999999},{1000000,1500000}}) do
  T.check(M.width(M.readout(pair[1],pair[2],false,48)) <= 44,"large values stay inside a native-width bar")
end
mon.level=data.constants.levelCap or 100
local _,_,full,atCap=M.values(data,battler,"XP")
T.eq(full,1,"level cap gives a full EXP bar")
T.eq(M.readout(0,0,atCap,48),"MAX","level cap has no misleading zero denominator")
T.eq(mon.hp,69,"meter calculation never mutates saved HP")
T.eq(mon.exp,base+188,"meter calculation never mutates EXP")
T.finish("battle_meters")
