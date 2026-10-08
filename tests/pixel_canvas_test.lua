-- ROM-free regression for mobile devices with fractional display density.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Font = require("src.render.Font")
local data = T.fixtures.fresh()
Font.load(data)
local G = love.graphics
local createCanvas, allocations = G.newCanvas, {}
local density = 2.755
G.newCanvas = function(w, h, options)
  local canvas = createCanvas(w, h, options)
  local dpi = options and options.dpiscale or density
  -- LOVE leaves logical dimensions unchanged, concealing the inflated atlas.
  canvas.getPixelDimensions = function()
    return math.floor(w*dpi+0.5), math.floor(h*dpi+0.5)
  end
  allocations[#allocations+1] = {canvas=canvas,w=w,h=h,dpi=dpi}
  return canvas
end
local game = {data=data,save={inventory={POTION=2},options={}},
  input={wasPressed=function()return false end,isDown=function()return false end}}
local mod = {path="mods/modern_ui_suite/components/modern_bag_ui",
  options={get=function()return nil end}}
function mod:read(name)
  local f=assert(io.open(self.path.."/"..name));local s=f:read("*a");f:close();return s
end
local menu = {game=game,rows={{id="POTION",name="POTION",count=2,showCount=true}},
  modernBagPockets={{key="all"}},modernBagPocketIndex=1,index=1,scroll=0}
function menu:total()return #self.rows+1 end
function menu:description()return "Test single-pixel strokes." end
function menu:ensureVisible()end
local presenter = dofile(mod.path.."/gen2_presentation.lua")(mod, {
  moneyText=function()return "¥0" end,
  category=function()return "MEDICINE" end,
  order=function()return {"POTION"} end,
})
for _,size in ipairs({{160,144},{192,144},{256,144},{160,300}}) do
  menu.modernBagWideWidth,menu.modernBagWideHeight=size[1],size[2]
  presenter.render(menu)
  local canvas = menu.modernGen2BagCanvas
  local w,h=canvas:getDimensions()
  T.same({canvas:getPixelDimensions()},{w,h},
    "Bag raster remains exact at "..size[1].."x"..size[2])
  local count=#allocations
  presenter.render(menu)
  T.eq(#allocations,count,"unchanged layout reuses its pixel buffer")
end
T.eq(#allocations,4,"all four Bag layouts allocate a tested buffer")
G.newCanvas=createCanvas
T.finish()
