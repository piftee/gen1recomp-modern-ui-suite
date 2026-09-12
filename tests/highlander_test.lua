package.path="./?.lua;./?/init.lua;"..package.path
local T=require("tests.modkit")
local R=require("src.mods.Runtime")
local run=T.sdk.loadMod("mods/modern_ui_suite",{data=T.fixtures.fresh(),dev=true})
T.eq(#run.errors,0,"Highlander suite loads")
local api=run.loader.exports.modern_ui_suite
local opts={}
run.loader.modOptions.modern_ui_suite=opts
local function setting(key,value) opts[key]=value end
for _,key in ipairs({"always_boosted_exp","modern_exp_share","decapitalize","sparkling_hidden","infinite_safari","rematch_anyone"}) do
 T.eq(api.highlander.on(key),false,key.." stays opt-in")
end
setting("qol.modern_exp_share",true)
local party={{hp=10},{hp=10},{hp=10},{hp=0},{hp=10,isEgg=true}}
local shares={}
R.call("battle.exp_award",function()error("native split unexpectedly called")end,
 {battle={party=party},alive={party[1],party[2]},participants=2,
 applyShare=function(m,n)shares[m]=n end})
T.eq(shares[party[1]],1,"first participant receives full undivided EXP")
T.eq(shares[party[2]],1,"second participant receives full undivided EXP")
T.eq(shares[party[3]],2,"bench receives half EXP")
T.eq(shares[party[4]],nil,"fainted member is excluded")
T.eq(shares[party[5]],nil,"egg is excluded")
local native=false
R.call("battle.exp_award",function()native=true end,{battle={kind="link"},applyShare=function()error("link share changed")end})
T.check(native,"link progression remains native")
setting("qol.always_boosted_exp",true)
local ctx={traded=false,battle={linkBattle=true}}
T.eq(R.call("exp.gain",function(c)return c.traded end,ctx),false,"link EXP remains native")
ctx.battle=nil
T.eq(R.call("exp.gain",function(c)return c.traded end,ctx),true,"nontraded Pokemon receive boost")
T.eq(ctx.traded,false,"boost never writes traded status")
local C=api.highlander.decapitalize
T.eq(C("HP PP PC TM HM EXP ID"),"HP PP PC TM HM EXP ID","acronyms preserved")
T.eq(C("PIKACHU\v<PLAYER>\fPOKéMON"),"Pikachu\v<PLAYER>\fPokémon","ROM tokens and controls preserved")
local moves=api.components.pokemoves.exports
local data={moves={BITE={name="BITE"},FLAMETHROWER={name="FLAMETHROWER"}},pokemon={
 GROWLITHE={evolutions={{method="item",species="ARCANINE"}},learnset={{level=50,move="FLAMETHROWER"}}},
 ARCANINE={level1Moves={"BITE"},learnset={}},}}
local list=moves.relearnList(data,{species="ARCANINE",level=50,moves={{id="BITE"}}})
T.eq(#list,1,"relearner filters already known moves")
T.eq(list[1].id,"FLAMETHROWER","stone evolution retains eligible pre-evolution move")
T.eq(#moves.relearnList(data,{species="ARCANINE",level=49,moves={{id="BITE"}}}),0,"future move remains unavailable")
-- A custom evolution graph cannot loop forever or duplicate candidates.
data.pokemon.ARCANINE.evolutions={{species="GROWLITHE"}}
T.eq(#moves.relearnList(data,{species="ARCANINE",level=50,moves={}}),2,"cyclic provider graph is bounded")
local scaled=api.rematches.scaledSpecies
local evoData={pokemon={A={evolutions={{method="EVOLVE_LEVEL",into="B",level=16}}},B={evolutions={}}}}
T.eq(scaled(evoData,"B",5),"A","Gen2 level evolution scales down")
T.eq(scaled(evoData,"A",20),"B","Gen2 level evolution scales up")
-- Per-game palettes are separate from progress-save palettes.
local components=dofile("mods/modern_ui_suite/core/components.lua")
local live={}
local Settings=dofile("mods/modern_ui_suite/core/settings.lua")({id="modern_ui_suite",options={get=function(_,k)return live[k]end}},components)
Settings:registerSchema("modern_start_menu_ui",{{key="theme",default="map"},{key="theme_scope",default="game"}})
local function game(version)
 return {save={version=version,options={}},mods={modOptions={modern_ui_suite=live}}}
end
local red,blue=game("red"),game("blue")
Settings.activeGame=red;Settings:set(red,"modern_start_menu_ui","theme","red")
Settings.activeGame=blue;Settings:set(blue,"modern_start_menu_ui","theme","blue")
Settings.activeGame=red;T.eq(Settings:get("modern_start_menu_ui","theme"),"red","red palette survives blue choice")
Settings.activeGame=blue;T.eq(Settings:get("modern_start_menu_ui","theme"),"blue","blue palette is independent")
Settings:set(blue,"modern_start_menu_ui","theme_scope","save")
Settings:set(blue,"modern_start_menu_ui","theme","gold")
T.eq(Settings:get("modern_start_menu_ui","theme"),"gold","save palette is used")
Settings.activeGame=red
T.check(Settings:get("modern_start_menu_ui","theme")~="gold","another save never inherits save-specific palette")
Settings:set(red,"modern_start_menu_ui","theme_scope","game")
T.eq(Settings:get("modern_start_menu_ui","theme"),"red","per-game choice restored after changing scope")
-- No physical controller is touched by this simulated rumble backend.
local values={enabled=true,intensity=0.35};local events={};local pulses={}
local pad={isVibrationSupported=function()return true end,
 setVibration=function(_,low,high,duration)pulses[#pulses+1]={low,high,duration};return true end}
local original=love.joystick
love.joystick={getJoysticks=function()return {pad}end}
local rumble={options={define=function()end,get=function(_,k)return values[k]end,enabled=function()return values.enabled end},
 events={on=function(_,k,f)events[k]=f end,always=function(_,k,f)events[k]=f end},exports={}}
dofile("mods/modern_ui_suite/components/controller_rumble/main.lua")(rumble)
events["pokemon.caught"]()
T.eq(pulses[1][3],0.22,"rumble pulse has a hardware expiry")
values.enabled=false;events["mod.options_changed"]()
T.eq(pulses[2][1],0,"disabling stops an owned rumble immediately")
events["pokemon.caught"]();T.eq(#pulses,2,"disabled rumble never starts")
love.joystick=original
-- Voice calls can fall back to the chip cry without changing game audio data.
local GV=require("src.core.GameVersion");local get=GV.get
GV.get=function()return "yellow"end
setting("qol.pikachu_sound","original")
local Sound=require("src.core.Sound");local cry=Sound.playCry
local calls=0
Sound.playCry=function(d,s)
 calls=calls+1
 if calls>2 then error("voice recursion")end
 return Sound.playPikaCry(d,1) or "chip"
end
T.eq(Sound.playPikaCry({},1),"chip","direct Yellow voice becomes a chip cry")
T.eq(calls,1,"Pikachu fallback is recursion-safe")
Sound.playCry=cry;GV.get=get
T.finish("Highlander gameplay, settings and controls")
