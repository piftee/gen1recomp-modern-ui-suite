package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Font = require("src.render.Font")
local Strings = require("src.core.Strings")
local MoveLearn = require("src.ui.MoveLearnMenu")
local data = T.fixtures.fresh()
local groups = {
  { "POKE_BALL", "GREAT_BALL", "ULTRA_BALL", "MASTER_BALL", "SAFARI_BALL" },
  { "POTION", "SUPER_POTION", "HYPER_POTION", "MAX_POTION", "FRESH_WATER",
    "SODA_POP", "LEMONADE", "FULL_RESTORE", "ANTIDOTE", "AWAKENING",
    "BURN_HEAL", "ICE_HEAL", "PARLYZ_HEAL", "FULL_HEAL", "REVIVE", "MAX_REVIVE",
    "ETHER", "MAX_ETHER", "ELIXER", "MAX_ELIXER", "HP_UP", "PP_UP", "PROTEIN",
    "IRON", "CARBOS", "CALCIUM", "RARE_CANDY" },
  { "X_ATTACK", "X_DEFEND", "X_SPEED", "X_SPECIAL", "X_ACCURACY", "DIRE_HIT",
    "GUARD_SPEC", "FIRE_STONE", "WATER_STONE", "THUNDER_STONE", "LEAF_STONE",
    "MOON_STONE", "REPEL", "SUPER_REPEL", "MAX_REPEL", "ESCAPE_ROPE", "POKE_DOLL", "NUGGET" },
  { "DOME_FOSSIL", "HELIX_FOSSIL", "OLD_AMBER", "OLD_ROD", "GOOD_ROD", "SUPER_ROD" },
}
local categories = { "balls", "medicine", "items", "key" }
for index, group in ipairs(groups) do
  for _, id in ipairs(group) do
    data.items[id] = { id = id, name = id, bagPocket = categories[index] }
  end
end
for _, spec in ipairs({ { "TM03", "TM", 3 }, { "TM11", "TM", 11 }, { "HM01", "HM", 1 } }) do
  data.items[spec[1]] = { name = spec[1], machine = { kind = spec[2], number = spec[3] } }
end
groups[5], categories[5] = { "TM03", "TM11", "HM01" }, "machines"
Font.load(data)
local run = T.sdk.loadMod("mods/modern_ui_suite", { data = data, dev = true })
T.eq(#run.errors, 0, "suite loads with follow-up fixes")
local stack = { states = {} }
function stack:top() return self.states[#self.states] end
function stack:push(s) self.states[#self.states + 1] = s end
local game = { data = run.data, mods = run.loader, stack = stack,
  input = { wasPressed = function() return false end, isDown = function() return false end },
  save = { money = 100, inventory = {}, bagOrder = {}, options = {}, player = { name = "RED" }, party = {} },
}
local opts = run.loader.modOptions.modern_ui_suite or {}
run.loader.modOptions.modern_ui_suite = opts
for _, skin in ipairs({ "modern", "classic_pocket" }) do
  opts["bag.skin"] = skin
  for gi, wanted in ipairs(groups) do
    game.save.inventory, game.save.bagOrder = {}, {}
    for i = #wanted, 1, -1 do
      game.save.inventory[wanted[i]] = i
      table.insert(game.save.bagOrder, wanted[i])
    end
    opts["bag.open_on"] = categories[gi]
    local bag = run.data.screens.BagMenu.new(game, {})
    local selected = bag.items[bag.index].value
    bag:modernBagSort("category", false)
    T.same(game.save.bagOrder, wanted, skin .. " orders " .. categories[gi])
    T.eq(bag.modernBagPockets[bag.modernBagPocket].key, categories[gi], "sort stays in selected tab")
    T.eq(bag.items[bag.index].value, selected, "sort retains selected item")
    local reversed = {}
    for i = #wanted, 1, -1 do table.insert(reversed, wanted[i]) end
    bag:modernBagSort("category", true)
    T.same(game.save.bagOrder, reversed, "descending reverses full within-pocket order")
    for i, id in ipairs(wanted) do T.eq(game.save.inventory[id], i, "quantity preserved: " .. id) end
  end
end

local presentation = run.loader.exports.modern_ui_suite.components.modern_start_menu_ui.exports.presentation
local translations = { ["POKéDEX"] = "ずかん", ["POKéMON"] = "ポケモン", ITEM = "どうぐ",
  SAVE = "レポート", OPTION = "せってい", MODS = "モッド", QUIT = "とじる" }
Strings.load({ strings = translations })
local expected = { ["POKéDEX"] = "pokedex", ["POKéMON"] = "party", ITEM = "bag",
  SAVE = "save", OPTION = "options", MODS = "mods", QUIT = "quit" }
for source, translated in pairs(translations) do
  local row = { label = translated }
  T.eq(presentation.iconFor(row, game), expected[source], "translated icon: " .. source)
  T.eq(presentation.isCustomItem(row, game), false, "translated built-in keeps default icon")
  T.eq(presentation.entryKeyFor(row), presentation.entryKeyFor({ label = source }), "order key survives translation")
end
T.check(presentation.entryKeyFor({ label = "ああ" }) ~= presentation.entryKeyFor({ label = "いい" }),
  "unrelated Japanese custom entries have distinct saved icon keys")
T.eq(presentation.iconFor({ id = "bag", label = "ずかん" }, game), "bag", "stable id precedes translation")
Strings.load(nil)

-- The installed engine uses row 7; the retained development engine uses row 5.
-- Observe actual native box placement, then assert every overlay stays inside it.
local patch = MoveLearn._typedMoveColorsPatch
local native = patch.original
local rect, marks = love.graphics.rectangle, {}
love.graphics.rectangle = function(mode, x, y, w, h)
  if mode == "fill" and x == 46 and w == 106 then marks[#marks + 1] = y end
end
local mon = { moves = {} }
for _, id in ipairs({ "FIX_CUT", "FIX_CUT", "FIX_CUT", "FIX_CUT" }) do
  mon.moves[#mon.moves + 1] = { id = id, pp = 10 }
end
local menu = MoveLearn.new(game, mon, "FIX_CUT", function() end)
menu.selecting = true
stack:push(menu)
for _, row in ipairs({ 5, 7 }) do
  patch.original = function() Font.drawBox(4, row, 16, 6); Font.drawBox(0, 12, 20, 6) end
  marks = {}
  menu:draw()
  T.eq(menu._typedMoveColorsLearnRowBase, row, "native forget-list border drives overlay")
  T.check(#marks >= 4, "all move cards render")
  for _, y in ipairs(marks) do T.check(y >= (row + 1) * 8 and y <= (row + 4) * 8, "card inside native move rows") end
end
patch.original = function() end
marks = {}; menu:draw()
T.eq(#marks, 0, "unknown layout skips tint instead of drawing misplaced names")
patch.original = function() error("native draw failure") end
local drawBox = Font.drawBox
T.eq(pcall(menu.draw, menu), false, "native errors propagate")
T.eq(Font.drawBox, drawBox, "native failure restores temporary layout observer")
patch.original, love.graphics.rectangle = native, rect
run.release()
T.finish("Discord follow-up regressions")
