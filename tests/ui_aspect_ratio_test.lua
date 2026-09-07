-- Headless: luajit mods/modern_ui_suite/tests/ui_aspect_ratio_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")
local Palette = require("src.render.PaletteFX")
local run = T.sdk.loadMod("mods/modern_ui_suite", {data=T.fixtures.fresh(), dev=true})
T.eq(#run.errors, 0, "suite loads with shared UI surfaces")
local stack = {states={}}
function stack:top() return self.states[#self.states] end
function stack:pop() return table.remove(self.states) end
function stack:push(screen)
  self.states[#self.states+1] = screen
  Runtime.emit("screen.pushed", {state=screen})
end
local mon = {species="FIXMON_A", nickname="LEAF", level=12, exp=1728, hp=35,
  stats={hp=35,attack=20,defense=18,speed=16,special=22}, moves={}}
local game = {data=run.data, mods=run.loader, stack=stack,
  input={wasPressed=function() return false end, isDown=function() return false end},
  save={options={}, inventory={}, bagOrder={}, pcItems={}, money=0,
    party={mon}, flags={}, pokedex={seen={},owned={}}, player={name="RED"}}}
Runtime.emit("game.ready", {game=game})
local opts = run.loader.modOptions.modern_ui_suite
local dimensions = love.graphics.getPixelDimensions
local constructors = {
  party=function() return run.data.screens.PartyMenu.new(game,{}) end,
  bag=function() return run.data.screens.BagMenu.new(game,{}) end,
  pc=function() return run.data.screens.BoxMenu.new(game,{}) end,
  pokedex=function() return run.data.screens.PokedexMenu.new(game,{}) end,
}
for _, window in ipairs({{1600,720},{1280,720},{480,900}}) do
  love.graphics.getPixelDimensions = function() return unpack(window) end
  for key, new in pairs(constructors) do
    for _, ratio in ipairs({{"16:9",256},{"4:3",192}}) do
      stack.states={}
      opts[key..".aspect_ratio"] = ratio[1]
      local screen = new(); stack:push(screen)
      T.same({screen:uiSize()}, {ratio[2],144}, key.." fits "..ratio[1].." on "..window[1].."x"..window[2])
      if key == "party" then
        local summary = run.data.screens.SummaryMenu.new(game,mon)
        stack:push(summary)
        T.same({summary:uiSize()}, {ratio[2],144}, "summary inherits the party ratio")
      end
    end
  end
end
love.graphics.getPixelDimensions = function() return 1600,720 end
opts["party.responsive"] = false
stack.states={}
local party=constructors.party();stack:push(party)
T.same({party:uiSize()}, {160,144}, "saved Widescreen OFF still selects native size")
opts["party.responsive"] = true
opts["party.aspect_ratio"] = "16:9"
local message={game=game, draw=function() end}
stack:push(message)
T.same({message:uiSize()}, {256,144}, "transparent follower message retains the party surface")
stack:pop()
local rectangles, translated = {}, nil
local rectangle, translate = love.graphics.rectangle, love.graphics.translate
love.graphics.rectangle=function(...) rectangles[#rectangles+1]={...} end
love.graphics.translate=function(x,y) translated={x,y} end
local evo = {game=game,isOpaque=true,draw=function()
  Palette.markTrueColor(52,8,56,56)
end, sgbPalettes=function() return {{x=0,y=0,w=160,h=144,colors={}},
  {x=52,y=8,w=56,h=56,colors={}}} end}
stack:push(evo)
Palette.clearTrueColor();Palette.setPass("world");Palette.markTrueColor(1,2,3,4)
Palette.setPass("ui");Palette.markTrueColor(9,9,9,9)
evo:draw()
T.same(rectangles[1], {"fill",0,0,256,144}, "evolution covers the whole party surface")
T.same(translated,{48,0},"native evolution art is centered")
T.eq(#Palette.trueColorRects("world"),1,"child fill preserves world colour marks")
T.same(Palette.trueColorRects("ui")[1],{colors=false,x=100,y=8,w=56,h=56},"child art marks shift and covered party marks disappear")
local zones=evo:sgbPalettes(game)
T.same({zones[1].x,zones[1].y,zones[1].w,zones[1].h},{0,0,256,144},"evolution paper palette fills the surround")
T.eq(zones[2].x,100,"evolution sprite palette follows centered art")
local nested={game=game,draw=function() end};stack:push(nested)
T.same({nested:uiSize()},{256,144},"a prompt above evolution keeps its surface")
stack:pop();stack:pop()
T.eq(stack:top(),party,"closing evolution returns to the same party controller")
T.same({party:uiSize()},{256,144},"closing evolution retains the ratio")
local TextBox=require("src.render.TextBox")
local keptText=0
local intro=setmetatable({game=game,draw=function() keptText=keptText+1 end},TextBox)
stack:push(intro)
local transparent={game=game,screenId="EvolutionState",draw=function() end}
stack:push(transparent);rectangles={};transparent:draw()
T.eq(transparent.isOpaque,true,"new native transparent evolution gains a full-page boundary")
T.same(rectangles[1],{"fill",0,0,256,144},"transparent evolution covers the party across the aspect ratio")
T.eq(keptText,1,"transparent evolution retains its real intro TextBox exactly once")
stack:pop();stack:pop()
local battle={game=game,isBattle=true,draw=function() end};stack:push(battle)
T.eq(battle.uiSize,nil,"a gameplay boundary is not claimed by an old menu")
local other={game=game,draw=function() end};stack:push(other)
T.eq(other.uiSize,nil,"prompts above a newer battle are not claimed")
game.save.options.faithfulRes=3
T.same({party:uiSize()},{160,144},"Faithful Ratio remains authoritative over fixed menu ratios")
game.save.options.faithfulRes=nil
love.graphics.rectangle,love.graphics.translate=rectangle,translate
love.graphics.getPixelDimensions=dimensions

-- Exercise Game2's wide-plus-native-stack contract without a display/audio.
local Surface=dofile("mods/modern_ui_suite/core/ui_surfaces.lua")(
  {events={on=function() end}}, {get=function(_,_,key) if key=="aspect_ratio" then return "16:9" end end})
local draws=0
local wide={game=game,draw=function() draws=draws+1 end,
  drawWidescreen=function() draws=draws+1 end}
Surface.guardWideDraw(wide)
local prompt={};stack.states={wide,prompt}
wide:drawWidescreen(1600,720);wide:draw()
T.eq(draws,1,"Gen2 follower prompt draws one party instead of wide and native duplicates")
stack:pop();wide:draw()
T.eq(draws,2,"the guard leaves subsequent native draws active")
wide:drawWidescreen(1600,720);wide:draw()
T.eq(draws,4,"direct drawing works when no overlay is on the stack")
for _, ratio in ipairs({{"16:9",256},{"4:3",192}}) do
  local S=dofile("mods/modern_ui_suite/core/ui_surfaces.lua")(
    {events={on=function() end}}, {get=function(_,_,key) if key=="aspect_ratio" then return ratio[1] end end})
  for _, dims in ipairs({{1600,720},{480,900},{128,100}}) do
    local w,h,s=S.geometry({},wide,dims[1],dims[2],320,144,5)
    T.same({w,h},{ratio[2],144},"Gen2 fixed layout uses the requested ratio")
    T.check(w*s<=dims[1] and h*s<=dims[2],"fixed Gen2 layout fits both axes")
  end
end
T.finish("UI aspect ratios and child composition")
