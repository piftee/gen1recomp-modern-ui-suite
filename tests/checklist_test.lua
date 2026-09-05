-- Run from the engine root; pass "standalone" to exercise the three archives.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")
local Font = require("src.render.Font")
local data = T.fixtures.fresh()
for id, def in pairs({
  POTION = { name = "POTION" }, ANTIDOTE = { name = "ANTIDOTE" },
  ESCAPE_ROPE = { name = "ESCAPE ROPE" },
  POKE_BALL = { name = "POKé BALL", ball = "POKE_BALL" },
  TM_FIX = { name = "TM01", machine = { kind = "TM", move = "FIX_CUT" } },
  TOWN_MAP = { name = "TOWN MAP", keyItem = true },
  BERRY = { name = "BERRY", bagPocket = "berries" },
  BATTLE_TOOL = { name = "BATTLE TOOL", bagPocket = "battle" },
}) do def.id = id; data.items[id] = def end
Font.load(data)
local standalone = arg[1] == "standalone"
local paths = standalone and { "mods/modern_party_ui", "mods/modern_start_menu_ui", "mods/modern_bag_ui" }
  or { "mods/modern_ui_suite" }
local run = T.sdk.loadMods(paths, {data=data, dev=true})
T.eq(#run.errors, 0, "checklist mods load")
local stack = { states = {} }
function stack:push(screen) self.states[#self.states+1] = screen end
function stack:pop() return table.remove(self.states) end
function stack:top() return self.states[#self.states] end
local input = { pressed = {} }
function input:wasPressed(key) return self.pressed[key] == true end
function input:isDown() return false end
local function press(screen, key)
  input.pressed[key] = true; screen:update(0); input.pressed[key] = nil
end
local game = { data=run.data, mods=run.loader, stack=stack, input=input,
  save={options={}, inventory={}, bagOrder={}, money=100, party={}, player={name="RED"}},
  renderer={uiSize=function() return 256,144 end},
}
local writes = 0
game.writeOptions = function() writes = writes + 1 end
local function api(id)
  if standalone then return run.loader.exports[id] end
  return run.loader.exports.modern_ui_suite.components[id].exports
end
local function option(id, key, value)
  local owner = standalone and id or "modern_ui_suite"
  local prefixes = {modern_bag_ui="bag", modern_start_menu_ui="start_menu"}
  key = standalone and key or (prefixes[id] .. "." .. key)
  run.loader.modOptions[owner] = run.loader.modOptions[owner] or {}
  run.loader.modOptions[owner][key] = value
end
local function keys(pockets)
  local out={}; for _,p in ipairs(pockets) do out[#out+1]=p.key end
  return table.concat(out,",")
end
local bagApi = api("modern_bag_ui").pocketSettings
local bagScreen = run.data.screens.BagMenu
local order={"TOWN_MAP","POTION","ESCAPE_ROPE","TM_FIX","ANTIDOTE","POKE_BALL"}
for i,id in ipairs(order) do game.save.inventory[id]=i; game.save.bagOrder[i]=id end
for _, skin in ipairs({"modern","classic_pocket"}) do
  option("modern_bag_ui","skin",skin)
  for _, key in ipairs({"all","items","medicine","balls","machines","key"}) do
    option("modern_bag_ui","open_on",key)
    local bag=bagScreen.new(game,{})
    T.eq(bag.modernBagPockets[bag.modernBagPocket].key,key,skin .. " opens on " .. key)
    bag:modernBagSwitchPocket(1)
    local reopened=bagScreen.new(game,{})
    T.eq(reopened.modernBagPockets[reopened.modernBagPocket].key,key,"opening choice survives reopening")
  end
end
option("modern_bag_ui","skin","modern")
option("modern_bag_ui","open_on","all")
option("modern_bag_ui","hide_all",true)
local bag=bagScreen.new(game,{})
T.eq(#bag.modernBagPockets,5,"Hide All removes only the combined tab")
T.eq(bag.modernBagPockets[bag.modernBagPocket].key,"items","hidden opening choice falls back to Items")
T.eq(bag:modernBagCategoryFor("BERRY"),"medicine","Berries stay reachable without All")
T.eq(bag:modernBagCategoryFor("BATTLE_TOOL"),"items","battle items stay reachable without All")
local visited={}
for _=1,5 do
  for _,row in ipairs(bag.items) do visited[row.value]=true end
  bag:modernBagSwitchPocket(1)
end
for _,id in ipairs(order) do T.check(visited[id],id .. " is accessible with All hidden") end
bagApi.openOrder(game)
local editor=stack:top()
T.eq(#editor.items,5,"pocket editor lists the visible tabs")
press(editor,"select");press(editor,"down");press(editor,"b")
T.eq(editor.held,nil,"B cancels pocket pickup")
T.eq(stack:top(),editor,"cancelling pickup leaves pocket editor open")
editor.index=1;press(editor,"select");press(editor,"down");press(editor,"select")
T.eq(editor.items[1].value,"medicine","Select swaps two pocket positions")
T.check(writes>0,"completed pocket swap persists options")
press(editor,"b")
bag=bagScreen.new(game,{})
T.eq(keys(bag.modernBagPockets),"medicine,items,balls,machines,key","saved pocket order reaches live Bag")
T.eq(bag.modernBagPockets[bag.modernBagPocket].key,"items","Open On resolves keys after reordering")
option("modern_bag_ui","hide_all",false)
bag=bagScreen.new(game,{})
T.eq(#bag.modernBagPockets,6,"turning All back on restores exactly one tab")
-- Invalid saved entries must not duplicate or remove real pockets.
option("modern_bag_ui","pocket_order",{"key","key","removed","medicine"})
bag=bagScreen.new(game,{})
T.eq(keys(bag.modernBagPockets),"key,medicine,all,items,balls,machines","old or duplicate pocket keys are reconciled")
option("modern_bag_ui","pocket_order",nil)
option("modern_bag_ui","open_on","medicine")
bag=bagScreen.new(game,{})
bag:modernBagSort("category",false)
T.eq(bag.modernBagPockets[bag.modernBagPocket].key,"all","category sort reveals its result from a filtered pocket")
T.same(game.save.bagOrder,{"ESCAPE_ROPE","POTION","ANTIDOTE","POKE_BALL","TM_FIX","TOWN_MAP"},"ascending category groups use real item definitions")
bag:modernBagSort("category",true)
T.same(game.save.bagOrder,{"TOWN_MAP","TM_FIX","POKE_BALL","POTION","ANTIDOTE","ESCAPE_ROPE"},"descending category groups reverse without reversing their contents")
for i,id in ipairs(order) do T.eq(game.save.inventory[id],i,"sorting preserves " .. id .. " quantity") end

local startSettings=api("modern_start_menu_ui").settings
startSettings.openOrder(game)
T.eq(stack:top().items[1].label,"OPEN START ONCE","order editor explains how to discover the live set")
press(stack:top(),"b")
local actions, called={},nil
for i=1,12 do
  local index=i
  actions[i]={id="entry_"..i,label="ICON "..i,onSelect=function() called=index end}
end
local function startMenu(items)
  local copied={};for i,item in ipairs(items) do copied[i]=item end
  return Runtime.call("ui.start_menu.presentation",function(_,menu) return menu end,
    game,{game=game,items=copied,index=1,update=function() end,draw=function() end})
end
local start=startMenu(actions)
startSettings.openOrder(game);editor=stack:top()
T.eq(#editor.items,12,"icon editor includes every live action beyond seven")
editor.index=9;press(editor,"left")
T.eq(editor.items[8].value,"id:entry_9","Left moves the highlighted icon earlier")
T.eq(editor.index,8,"selection follows the moved icon")
press(editor,"right");T.eq(editor.items[9].value,"id:entry_9","Right moves the highlighted icon later")
press(editor,"left");press(editor,"b")
start=startMenu(actions)
T.eq(start.items[8],actions[9],"reopened Start retains item identity in saved order")
start.items[8].onSelect();T.eq(called,9,"reordered icon keeps its original action")
local changed={}
for _,item in ipairs(actions) do if item.id~="entry_3" then changed[#changed+1]=item end end
changed[#changed+1]={id="new_mod",label="NEW MOD",onSelect=function() end}
start=startMenu(changed);startSettings.openOrder(game);editor=stack:top()
T.eq(#editor.items,12,"live editor drops unavailable actions and includes new ones")
T.eq(editor.items[#editor.items].value,"id:new_mod","new actions remain reachable")
press(editor,"b")
start=startMenu(actions)
T.eq(#start.items,12,"returning actions appear exactly once")

local first={species="FIXMON_A",hp=0,stats={hp=20},level=5,moves={}}
local second={species="FIXMON_B",hp=20,stats={hp=20},level=5,moves={}}
game.save.party={first,second};game.partyMenuSavedIndex=1
local partyRecord=run.data.screens.PartyMenu
local roster=partyRecord.new(game,{})
stack:push(roster);press(roster,"select")
T.eq(roster.swapFrom,1,"Select picks up the current party slot")
press(roster,"right");press(roster,"b")
T.eq(roster.swapFrom,nil,"B cancels held party slot")
T.eq(stack:top(),roster,"B cancelling a hold keeps Party open")
T.eq(game.save.party[1],first,"cancellation leaves party unchanged")
roster.index=1;press(roster,"select");press(roster,"right");press(roster,"select")
T.eq(game.save.party[1],second,"Select drops the complete Pokémon record into the other slot")
T.eq(game.save.party[2],first,"Select swaps both records")
T.eq(roster.swapFrom,nil,"completed party swap releases the hold")
for _,opts in ipairs({{battle={},forceSwitch=true,onSwitch=function() end},
    {pickOnly=true,onSwitch=function() end},{tmhm={move="FIX_CUT"}}}) do
  local picker=partyRecord.new(game,opts);press(picker,"select")
  T.eq(picker.swapFrom,nil,"Select does not reorder battle/item/TM target lists")
end
game.save.party={first,second}
for _, count in ipairs({2,3}) do
  if count==3 then game.save.party[3]={species="FIXMON_C",hp=10,stats={hp=10},level=5,moves={}} end
  for index=1,count do
    local chosen
    local forced=partyRecord.new(game,{battle={},forceSwitch=true,onSwitch=function(mon) chosen=mon end})
    forced.index=index;stack:push(forced)
    press(forced,"down")
    T.check(forced.index~=index,"forced replacement Down escapes a singleton grid column")
    press(forced,"a")
    T.eq(chosen,game.save.party[forced.index],"replacement responds immediately after movement")
  end
end
run.release()
T.finish(standalone and "standalone checklist" or "suite checklist")
