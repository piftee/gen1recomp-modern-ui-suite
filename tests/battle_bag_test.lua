-- Headless: luajit mods/modern_ui_suite/tests/battle_bag_test.lua [mod path]
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Font = require("src.render.Font")
local Palette = require("src.render.PaletteFX")
local Bag = require("src.inventory.Bag")
local data = T.fixtures.fresh()
for _, id in ipairs({"MASTER_BALL", "POKE_BALL", "GREAT_BALL", "POTION", "ANTIDOTE"}) do
  data.items[id] = {id=id, name=id:gsub("_", " "), price=200}
end
local run = T.sdk.loadMod(arg[1] or "mods/modern_ui_suite", {data=data, dev=true})
T.eq(#run.errors, 0, "suite loads for battle Bag regression")
Font.load(run.data)
run.loader.modOptions.modern_ui_suite = run.loader.modOptions.modern_ui_suite or {}
local opts = run.loader.modOptions.modern_ui_suite
opts["bag.open_on"], opts["bag.hide_all"] = "items", true
local stack = {states={}}
function stack:push(state) self.states[#self.states+1] = state end
function stack:top() return self.states[#self.states] end
function stack:pop() return table.remove(self.states) end
local game = {data=run.data, mods=run.loader, stack=stack,
  input={wasPressed=function() return false end},
  save={inventory={MASTER_BALL=2, POKE_BALL=3, GREAT_BALL=1, POTION=4, ANTIDOTE=2},
    bagOrder={"MASTER_BALL", "POKE_BALL", "GREAT_BALL", "POTION", "ANTIDOTE"},
    money=3000, party={}, flags={}, options={}, player={name="RED"}}}
local battle = {kind="wild", throwBall=function(self,id) self.thrown=id end}
local function open(options)
  local menu = run.data.screens.BagMenu.new(game, options or {battle=battle})
  stack:push(menu)
  return menu
end
local function key(menu) return menu.modernBagPockets[menu.modernBagPocket].key end
local function selected(menu) return menu.items[menu.index] and menu.items[menu.index].value end
local function pocket(menu,wanted)
  for _=1,6 do if key(menu)==wanted then return end; menu:modernBagSwitchPocket(1) end
  error("missing pocket " .. wanted)
end
local menu = open()
T.eq(key(menu), "items", "first open respects OPEN ON")
pocket(menu,"balls")
menu.index = 2
menu.onChoose(menu.items[menu.index], menu)
T.eq(battle.thrown, "POKE_BALL", "native item callback throws selected ball")
T.eq(game.save.inventory.POKE_BALL, 2, "native item use consumes one ball")
T.eq(stack:top(), nil, "native item use closes Bag")
menu = open()
T.eq(key(menu), "balls", "battle Bag reopens in last pocket")
T.eq(selected(menu), "POKE_BALL", "battle Bag reopens on the used item")
-- Identity survives changes to the acquisition order while the Bag is closed.
menu:close()
game.save.bagOrder = {"POKE_BALL","GREAT_BALL","MASTER_BALL","POTION","ANTIDOTE"}
menu = open()
T.eq(selected(menu), "POKE_BALL", "selection follows item ID after reorder")
menu.index = 2
menu.onChoose(menu.items[menu.index], menu)
T.eq(game.save.inventory.GREAT_BALL, nil, "last ball is consumed")
menu = open()
T.eq(key(menu), "balls", "depletion retains the pocket")
T.eq(selected(menu), "MASTER_BALL", "depletion selects nearest remaining row")
-- Each tab remembers its own cursor across newly constructed menus.
pocket(menu,"medicine"); menu.index = 2; menu:close()
menu = open({})
T.eq(key(menu), "medicine", "field Bag shares session selection")
T.eq(selected(menu), "ANTIDOTE", "field Bag remembers selected medicine")
pocket(menu,"balls")
T.eq(selected(menu), "MASTER_BALL", "other pocket cursor survives reopening")
menu:close()
-- A changed opening preference is authoritative on the next open.
opts["bag.open_on"] = "medicine"
menu = open()
T.eq(key(menu), "medicine", "changed OPEN ON resets the opening pocket")
menu:close()
-- Stable pocket keys survive tab reordering and hidden All tabs.
opts["bag.hide_all"] = false
menu = open(); pocket(menu,"all"); menu:close()
opts["bag.hide_all"], opts["bag.pocket_order"] = true, {"key","balls","medicine","items"}
menu = open()
T.eq(key(menu), "medicine", "hidden remembered tab falls back to OPEN ON")
menu:close()
-- Long filtered lists retain the viewport, clamped after inventory shrinks.
for i=1,12 do
  local id = "QA_ITEM_" .. i
  run.data.items[id] = {id=id,name="QA ITEM " .. i,price=1}
  Bag.add(game.save,id,1,run.data)
end
menu = open(); pocket(menu,"items")
menu.index, menu.scroll = 10, 5
menu:close(); menu = open()
T.eq(selected(menu), "QA_ITEM_10", "long list restores selected item")
T.eq(menu.scroll, 5, "long list restores scroll position")
menu:close()
for i=2,12 do Bag.remove(game.save,"QA_ITEM_" .. i,1) end
menu = open()
T.eq(menu.index, 1, "shortened inventory clamps cursor")
T.eq(menu.scroll, 0, "shortened inventory clamps scroll")
-- Only covered UI marks are cleared; world marks and later overlays survive.
for _, skin in ipairs({"modern","classic_pocket"}) do
  opts["bag.skin"] = skin
  Palette.clearTrueColor()
  Palette.setPass("world"); Palette.markTrueColor(5,5,16,16)
  Palette.setPass("ui"); Palette.markTrueColor(88,8,8,8)
  Palette.markTrueColor(144,73,8,7)
  menu:draw()
  T.eq(#Palette.trueColorRects("ui"), 0, skin .. " removes covered battle RGB regions")
  T.eq(#Palette.trueColorRects("world"), 1, skin .. " preserves world RGB regions")
  Palette.markTrueColor(32,40,8,8)
  T.eq(#Palette.trueColorRects("ui"), 1, skin .. " permits later overlay RGB regions")
end
menu:close()
local previous = game.save
game.save = {inventory=previous.inventory, bagOrder=previous.bagOrder,
  money=3000,party={},flags={},options={},player={name="BLUE"}}
menu = open()
T.eq(key(menu), "medicine", "another loaded save uses its own opening selection")
T.finish("battle Bag colour isolation and selection memory")
