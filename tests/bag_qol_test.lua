-- Standalone: luajit mods/modern_ui_suite/tests/bag_qol_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Font = require("src.render.Font")
local Strings = require("src.core.Strings")

local data = T.fixtures.fresh()
data.items.LONG_ITEM = {
  id = "LONG_ITEM", name = "LONG ITEM", price = 1,
  description = table.concat({
    "This deliberately oversized description proves that every leading line",
    "which fits can remain still while all remaining words move through the",
    "last available line and can eventually be read without truncation.",
  }, " "),
}
data.items.SHORT_ITEM = {
  id = "SHORT_ITEM", name = "SHORT ITEM", price = 1,
  description = "A short readable description.",
}

local run = T.sdk.loadMod("mods/modern_ui_suite", { data = data, dev = true })
T.eq(#run.errors, 0,
  "suite loads for Bag QoL checks (" .. tostring(run.errors[1]) .. ")")
Strings.load(run.data)
Font.load(run.data)

local stack = { states = {} }
function stack:push(state) self.states[#self.states + 1] = state end
function stack:pop() return table.remove(self.states) end
function stack:top() return self.states[#self.states] end

local input = { pressed = {} }
function input:wasPressed(key) return self.pressed[key] == true end
function input:isDown() return false end

local game = {
  data = run.data,
  save = {
    inventory = { LONG_ITEM = 1, SHORT_ITEM = 1 },
    bagOrder = { "LONG_ITEM", "SHORT_ITEM" },
    money = 999999, player = { name = "RED" }, party = {}, flags = {},
    options = {},
  },
  mods = run.loader,
  stack = stack,
  input = input,
}

local screen = assert(run.data.screens.BagMenu).new(game, {})
stack:push(screen)
local originalPixels = love.graphics.getPixelDimensions
love.graphics.getPixelDimensions = function() return 1280, 720 end

local modernOK, modernErr = pcall(screen.draw, screen)
T.check(modernOK, "modern Bag QoL draws: " .. tostring(modernErr))
local modern = screen:modernBagQolInfo()
T.eq(modern.money, "¥999999", "money keeps the engine's exact yen format")
T.eq(modern.headerCash, "¥999999",
  "modern Bag replaces its redundant BAG label with money")
T.check(modern.header.leftRight <= modern.header.titleX,
  "modern maximum money does not collide with the pocket title")
T.check(modern.header.titleRight <= modern.header.capacityLeft,
  "modern pocket title does not collide with capacity")
T.eq(modern.descriptionOverflow, true,
  "modern long descriptions activate the overflow path")
T.check(modern.descriptionStaticLines >= 1,
  "modern overflow preserves fitting leading lines")
T.check(type(modern.descriptionTail) == "string"
    and modern.descriptionTail:find("eventually", 1, true),
  "the scrolling tail retains the final description words")

screen:update(2)
screen:draw()
modern = screen:modernBagQolInfo()
T.check(modern.descriptionOffset > 0,
  "modern overflow advances from elapsed time after its initial hold")

screen.index = 2
screen:draw()
modern = screen:modernBagQolInfo()
T.eq(modern.descriptionOverflow, false,
  "a fitting modern description remains static")
T.eq(modern.descriptionOffset, 0,
  "changing the selected item resets the modern description")

screen.modernBagPrompt = "How many?"
screen:draw()
modern = screen:modernBagQolInfo()
T.eq(modern.descriptionOffset, 0,
  "quantity and confirmation prompts never inherit marquee motion")
screen.modernBagPrompt = nil

run.loader.modOptions.modern_ui_suite =
  run.loader.modOptions.modern_ui_suite or {}
run.loader.modOptions.modern_ui_suite["bag.skin"] = "classic_pocket"
screen.index = 1
local pocketOK, pocketErr = pcall(screen.draw, screen)
T.check(pocketOK, "Pocket Bag QoL draws: " .. tostring(pocketErr))
local pocket = screen:modernBagQolInfo()
T.eq(pocket.headerCash, "¥999999",
  "Pocket Bag replaces its redundant POCKET label with money")
T.check(pocket.header.leftRight <= pocket.header.titleX,
  "Pocket maximum money does not collide with the pocket title")
T.check(pocket.header.titleRight <= pocket.header.capacityLeft,
  "Pocket title does not collide with capacity")
T.eq(pocket.descriptionOverflow, true,
  "Pocket Bag long descriptions use the same complete overflow path")

love.graphics.getPixelDimensions = function() return 320, 480 end
local portraitOK, portraitErr = pcall(screen.draw, screen)
T.check(portraitOK, "portrait Pocket Bag QoL draws: " .. tostring(portraitErr))
local portrait = screen:modernBagQolInfo()
T.eq(portrait.headerCash, "¥999999",
  "portrait Pocket Bag keeps the exact maximum-money header")
T.check(portrait.header.leftRight <= portrait.header.titleX,
  "portrait money and title remain separated")
T.check(portrait.header.titleRight <= portrait.header.capacityLeft,
  "portrait title and capacity remain separated")

love.graphics.getPixelDimensions = originalPixels
run.release()
T.finish("modern_ui_suite Bag QoL")
