package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local generation, clock, opened = 2, 0, 0
package.loaded["src.core.GameVersion"] = { generation = function() return generation end }
local sources = { ["ba/sheet"] = { 32, 16 } }
local function pixels(w, h)
  local data = { w = w, h = h }
  function data:getDimensions() return self.w, self.h end
  function data:clone() return pixels(self.w, self.h) end
  function data:paste(_, _, _, x, y, cw, ch) self.crop = {x,y,cw,ch} end
  function data:mapPixel() end
  return data
end
love = { timer = { getTime = function() return clock end }, image = {}, graphics = {} }
function love.image.newImageData(w, h)
  if type(w) == "string" then
    opened = opened + 1
    local shape = assert(sources[w], "missing source " .. w)
    return pixels(shape[1], shape[2])
  end
  return pixels(w, h)
end
function love.graphics.newImage(data)
  return { data = data, setFilter = function() end }
end
local function setting(value) return { value = value, get = function(self) return self.value end } end
local def = { image = "sheet", width = 16, height = 16, columns = 2, frames = 2, durations = {100,200} }
local active, variant, owner = {}, nil, true
local art = {
  setting = setting("animated"), frontAnimationSetting = setting("gen5"),
  ownsSpeciesArt = function() return owner end,
  displayMode = function() return "color" end,
  prepareData = function(data, mode) return {data=data,mode=mode} end,
  image = function(_, side, mon) return {side=side,mon=mon,static=true} end,
  generationFrontImage = function(_, gen, mon) return {gen=gen,mon=mon} end,
}
local animation = { definitionFor = function(mon) variant = mon; return def end }
local lib = { mod = { assets = { path = function(_, rel) return "ba/" .. rel end } },
  require = function(name) return name == "BattleArt" and art or animation end }
active.BATTLE_ART_VOXEL_GEN2 = { exports = { battleArt = art, lib = lib } }
active.BATTLE_ART_VOXEL_FORK = { exports = { lib = lib } }
local selected = "battle_art"
local mod = {
  options = { get = function() return selected end },
  find = function(id) return active[id] end,
}
local resolver = dofile("mods/modern_ui_suite/core/battle_portraits.lua")(mod)
local game = {data={pokemon={CHARIZARD={}}}, mods={mods={},modOptions={},fs={read=function() end}},save={options={}}}
local mon = { species="CHARIZARD", dvs={attack=2,defense=10,speed=10,special=10} }
local first = resolver(game, mon)
T.same(first.data.crop, {0,0,16,16}, "first logical atlas cell")
T.eq(variant.mon, mon, "actual mon (including shiny DVs) reaches Battle Art")
T.eq(variant.dvs, mon.dvs, "DVs also reach legacy battler shape")
clock = .11
local second = resolver(game, mon)
T.same(second.data.crop, {16,0,16,16}, "duration clock advances to second cell")
T.eq(opened, 1, "atlas source is decoded once")
T.eq(resolver(game,mon,false), first, "thumbnail ignores animation clock")
clock=.31
T.eq(resolver(game,mon),first,"animation wraps using provider durations")
art.displayMode=function() return "gray" end
T.eq(resolver(game,mon).mode,"gray","display setting refreshes frame")
generation=1
T.check(resolver(game,mon)~=nil,"legacy Battle Art lib export is supported")
active.BATTLE_ART_VOXEL_FORK=nil; active.BATTLE_ART_VOXEL_GEN2=nil
T.eq(resolver(game,mon),nil,"disabled providers do not leak cached artwork")
active.BATTLE_ART_VOXEL_FORK={exports={lib=lib}}
owner=false; T.eq(resolver(game,mon),nil,"MODDED ownership preserves fallback")
owner=true
art.setting.value="rom"; T.eq(resolver(game,mon),nil,"ROM selection preserves fallback")
art.setting.value="static"; T.check(resolver(game,mon).static,"static delegates to provider image API")
art.setting.value="animated"; art.frontAnimationSetting.value="gen1"
T.eq(resolver(game,mon).gen,"gen1","Gen 1 single-image selection")
art.frontAnimationSetting.value="gen2"; def=nil
T.eq(resolver(game,mon).gen,"gen2","missing Gen 2 animation uses provider static fallback")
art.frontAnimationSetting.value="gen5"
T.eq(resolver(game,mon),nil,"missing definition falls back")
def={image="missing",width=8,height=8,columns=1,frames=2}
local before=opened
T.eq(resolver(game,mon),nil,"missing image does not break menu")
T.eq(resolver(game,mon),nil,"missing image repeat remains safe")
T.eq(opened,before+1,"failed image decode is cached")
def={image="sheet",width=33,height=16,columns=1,frames=1}
T.eq(resolver(game,mon),nil,"out-of-bounds crop falls back")
def={image="sheet",autoColumns=2}
T.same(resolver(game,mon,false).data.crop,{0,0,16,16},"automatic columns crop one frame")
def={image="sheet",cells={{x=8,y=2,width=7,height=9}}}
T.same(resolver(game,mon).data.crop,{8,2,7,9},"explicit cells preserve offsets")
def={image="sheet",autoColumns=3}
T.eq(resolver(game,mon),nil,"non-divisible columns are rejected")
def={image="sheet",autoColumns=2}
selected="default"; T.eq(resolver(game,mon),nil,"Default does not override existing renderer")
selected="crystal"; T.eq(resolver(game,mon),nil,"missing Crystal is optional")
selected="hgss"; T.eq(resolver(game,mon),nil,"retired HGSS choice uses Default even with Battle Art available")
selected="battle_art"
T.eq(resolver(game,{species="CHARIZARD",isEgg=true}),nil,"eggs never reveal their hidden species art")
T.eq(resolver(game,{}),nil,"empty slot retains placeholder")
lib.require=function() error("provider unavailable") end
T.eq(resolver(game,mon),nil,"provider failure cannot crash menus")
T.finish("suite_menu_sprites")
