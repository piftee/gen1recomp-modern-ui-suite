-- Standalone: luajit mods/modern_ui_suite/tests/gen2_pokedex_layout_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Font = require("src.render.Font")
Font.load(T.fixtures.fresh())

local savedModules = {}
local function stub(name, value)
  savedModules[name] = package.loaded[name]
  package.loaded[name] = value
end

local input = { pressed = {} }
function input:wasPressed(key) return self.pressed[key] == true end

local NativePokedex = {}
function NativePokedex.new(game)
  local menu = {
    game = game, save = game.save, data = game.data,
    pokemon = game.data.pokemon, dex = { entries = game.data.dexEntries },
    rows = {}, index = 1, scroll = 0, view = "entry", page = 1,
    entryAction = 1, gfx = {}, nativeUpdates = 0,
  }
  function menu:rebuild()
    self.rows = {}
    local dex = self.save.pokedex or {}
    for _, species in ipairs(self.data.order) do
      local entry = self.data.dexEntries[species]
      self.rows[#self.rows + 1] = {
        species = species, dex = entry.dex,
        seen = dex.seen and dex.seen[species] == true,
        caught = dex.caught and dex.caught[species] == true,
      }
    end
  end
  function menu:current() return self.rows[self.index] end
  function menu:ensureVisible() self.scroll = math.max(0, self.index - 6) end
  function menu:totals()
    local seen, caught = 0, 0
    for _, row in ipairs(self.rows) do
      if row.seen then seen = seen + 1 end
      if row.caught then caught = caught + 1 end
    end
    return seen, caught
  end
  function menu:monName(species) return self.pokemon[species].name end
  function menu:picFor() return nil end
  function menu:questionMark() return nil end
  function menu:playCry(species) self.lastCry = species end
  function menu:printEntry() self.printed = (self.printed or 0) + 1 end
  function menu:optionRows() return {} end
  function menu:searchTypeName() return "-----" end
  function menu:update() self.nativeUpdates = self.nativeUpdates + 1 end
  function menu:drawPanel() self.nativeDraws = (self.nativeDraws or 0) + 1 end
  menu:rebuild()
  return menu
end

stub("src.ui.gen2.PokedexMenu", NativePokedex)
stub("src.ui.gen2.Chrome", {
  paletteGlyphs = function() return nil end,
  wrap = function(text) return { tostring(text or "") } end,
})
stub("src.render.GbcPalette", { available = function() return false end })
stub("src.world.gen2.Palettes", { monColors = function() return nil end })

stub("src.ui.gen2.PartyMenu", {drawIcon=function() end})
local pokemon, entries, order, seen, caught = {}, {}, {}, {}, {}
for i=1,7 do
  local id="FORM"..i
  order[i],seen[id],caught[id]=id,true,true
  pokemon[id]={id=id,dex=i,name=id,types={"BUG","POISON"},evolutions={},
    baseStats={hp=60,attack=70,defense=50,speed=40,specialAttack=80,specialDefense=90},
    levelMoves={{level=1,move="TEST"}}}
  entries[id]={dex=i,kind="TEST",height=303,weight=650,
    text="FIRST NATIVE PAGE WITH A LONG DESCRIPTION TO SCROLL THROUGH.",
    text2="SECOND NATIVE PAGE REMAINS FULLY AVAILABLE."}
end
for i=2,7 do pokemon.FORM1.evolutions[i-1]={method="EVOLVE_LEVEL",level=i*10,into="FORM"..i} end
local game={input=input,data={pokemon=pokemon,dexEntries=entries,order=order,
  moves={TEST={id="TEST",name="TEST",type="BUG",power=20,pp=10}}},
  save={pokedex={seen=seen,caught=caught}}}
local registered,requested
local mod={path="mods/modern_ui_suite/components/modern_pokedex_ui", exports={},
  read=function(self,name)
    local f=assert(io.open(self.path.."/"..name,"rb"));local text=f:read("*a");f:close();return text
  end,
  options={get=function() end}, log={info=function() end},
  content={screens={get=function() end,register=function(_,_,record) registered=record end}},
  suite={battlePortrait=function(_,id)
    requested[#requested+1]=id
    return {getDimensions=function() return 56,56 end}
  end}}
assert(loadfile(mod.path.."/gen2.lua"))()(mod)
local menu=registered.new(game)
local originalDraw=Font.draw
local rendered={}
Font.draw=function(value,x,y) rendered[#rendered+1]={text=tostring(value),x=x,y=y} end
local function draw(width)
  requested,rendered={},{}
  menu.modernPokedexWideWidth=width
  menu:drawPanel()
  local text={};for _,v in ipairs(rendered) do text[#text+1]=v.text end
  return table.concat(text,"|")
end
local function press(key)
  input.pressed={[key]=true};menu:update(1/60);input.pressed={}
end
for _,width in ipairs({160,192,256,384}) do
  menu.view="entry";menu.index=1;menu.modernGen2Presentation=nil
  local text=draw(width)
  local state=menu.modernGen2Presentation
  T.check(state.modernDexTabbed,"Gen 2 entry uses Gen 1 tabs")
  local tabs={};for _,page in ipairs(state.modernDexPages) do tabs[#tabs+1]=page.id end
  T.same(tabs,{"info","stats","family","moves"},"same tab order as Gen 1")
  T.check(text:find("NOTES",1,true)~=nil,"separate notes card is rendered")
  T.eq(state.def.dexEntry.heightFt,3,"native height converted without losing inches")
  T.eq(state.def.dexEntry.heightIn,3,"native inches retained")
  T.eq(state.def.dexEntry.weight,650,"Gen 1 measurement formatting receives tenths of pounds")
  T.check(state.def.dexEntry.text:find("SECOND NATIVE PAGE",1,true)~=nil,"both native prose pages retained")
  press("down");T.eq(state.modernInfoScroll,math.min(1,math.max(0,#state.modernInfoLines-state.modernInfoVisible)),"Down scrolls overflowing field notes")
  press("a");T.eq(menu.lastCry,"FORM1","INFO A plays cry without flipping descriptions")
  press("right");text=draw(width)
  T.eq(state.modernDexPages[state.modernDexPage].id,"stats","Right changes tab immediately")
  T.check(text:find(width>=240 and "SP.ATK" or "SPA",1,true)~=nil,"Gen 2 Special Attack is present")
  T.check(text:find(width>=240 and "SP.DEF" or "SPD",1,true)~=nil,"Gen 2 Special Defense is present")
  if width<240 then
    for _,item in ipairs(rendered) do
      if item.text=="SPD" then T.check(item.y+8<=128,"sixth compact stat clears its lower border") end
    end
  end
  press("right");draw(width)
  T.eq(#requested,7,"family grid renders every known relative together")
  press("up");draw(width)
  T.eq(state.modernFamilyCursor,7,"Up wraps the whole family as in Gen 1")
  press("a");draw(width)
  T.eq(menu:current().species,"FORM7","A opens selected relative")
  T.eq(menu.modernGen2Presentation.modernDexPage,1,"relative starts on INFO")
  press("left");draw(width)
  T.eq(menu.modernGen2Presentation.modernDexPages[menu.modernGen2Presentation.modernDexPage].id,
    "moves","Left wraps to MOVES")
  press("a");draw(width)
  T.check(menu.modernGen2Presentation.modernMoveDetail,"A opens move detail")
  press("b");T.check(not menu.modernGen2Presentation.modernMoveDetail,"B returns to move list")
  press("b");T.eq(menu.view,"list","B returns to index")
  T.eq(menu:current().species,"FORM7","index retains the viewed relative")
  T.eq(menu.scroll,2,"native list uses shared five-row scroll budget")
  press("a");T.check(menu.modernGen2Actions~=nil,"index A opens actions")
  draw(width);press("a");T.eq(menu.view,"entry","DATA action opens tabbed entry")
end
seen.FORM7,caught.FORM7=nil,nil
menu:rebuild();menu.index=1;menu.view="entry";menu.modernGen2Presentation=nil
local text=draw(256);press("right");press("right");draw(256);press("up");text=draw(256)
T.check(text:find("UNDISCOVERED",1,true)~=nil,"unseen relative stays hidden")
for _,id in ipairs(requested) do T.check(id~="FORM7","unseen sprite is never requested") end
press("a");T.eq(menu:current().species,"FORM1","unseen relative cannot be opened")
press("b");press("select");T.eq(menu.view,"search","SELECT opens search as the shared footer says")
menu.view="list";press("start");T.eq(menu.view,"option","native ordering/Unown tools remain accessible")
menu.view="entry";menu.newEntry=true;menu.page=1;menu.modernGen2Presentation=nil;draw(256)
T.check(not menu.modernGen2Presentation.modernDexTabbed,"new catches use Gen 1's standalone presentation")
local before=menu.nativeUpdates;press("b")
T.eq(menu.nativeUpdates,before+1,"native catch completion remains authoritative")
menu.newEntry=false;menu.view="results";menu.index=1;menu.scroll=0
menu.rows={menu.rows[1]};menu.searchResults=true
text=draw(256)
T.check(text:find("CAUGHT 006/007",1,true)~=nil,"search keeps global caught totals")
T.check(text:find("FOUND 001",1,true)~=nil,"search footer reports matched count")
Font.draw=originalDraw
for name,value in pairs(savedModules) do package.loaded[name]=value end
T.finish("modern_ui_suite shared Gen 2 Pokedex")
