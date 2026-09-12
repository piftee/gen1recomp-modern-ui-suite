-- Headless workspace regression checks; the native driver loads the real v0.2 companion.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Boxes = require("src.pokemon.Boxes")
local Pokemon = require("src.pokemon.Pokemon")
local run = T.sdk.loadMod("mods/modern_ui_suite", { data = T.fixtures.fresh(), dev = true })
T.eq(#run.errors, 0, "suite loads")
run.loader.modOptions.modern_ui_suite = {}
require("src.core.Strings").load(run.data)
local width, height = 256, 144
local input = { wasPressed = function() return false end }
local game = { data = run.data, input = input, writeSave = function() return true end,
  renderer = { uiSize = function() return width, height end },
  stack = { pop = function() end } }
local function press(screen, key)
  input.wasPressed = function(_, k) return k == key end
  screen:update(0)
  input.wasPressed = function() return false end
end
local function fresh(capacity, count)
  Boxes.CAPACITY, Boxes.COUNT = capacity, count
  game.save = { party = {}, boxes = {}, currentBox = 1, options = {}, player = {} }
  for i = 1, count do game.save.boxes[i] = {} end
  for i = 1, 6 do game.save.party[i] = Pokemon.new(run.data, "FIXMON_A", 20) end
  for i = 1, capacity do game.save.boxes[1][i] = Pokemon.new(run.data, "FIXMON_A", 20) end
  return run.data.screens.BoxMenu.new(game)
end
local function visible(screen)
  local l = screen:modernPCLayoutInfo()
  T.check(screen.boxIndex >= l.box.first and screen.boxIndex <= l.box.last,
    "selected slot stays inside visible rows")
  T.check(l.box.last - l.box.first < 20, "at most twenty native-size slots render")
  T.check(l.box.y + l.box.h <= l.party.y, "party remains below viewport")
  return l
end
for _, size in ipairs({ {160,144}, {192,144}, {256,144}, {160,256} }) do
  width, height = unpack(size)
  for _, capacity in ipairs({20, 21, 50}) do
    local screen = fresh(capacity, capacity == 20 and 14 or 50)
    local opts = run.loader.modOptions.modern_ui_suite
    for _, exclusive in ipairs({false, true}) do
      opts["pc.box_exclusive"] = exclusive
      for i = 1, capacity do
        screen.region, screen.boxIndex = "box", i
        visible(screen)
        press(screen, "down")
        if i <= math.floor((capacity - 1) / 5) * 5 then
          T.eq(screen.region, "box", "Down crosses viewport edge within box")
          T.eq(screen.boxIndex, math.min(i + 5, capacity), "Down reaches next storage row")
          visible(screen)
        else
          T.eq(screen.region, "party", "only final storage row enters party")
          press(screen, "up")
          T.check(screen.boxIndex > math.floor((capacity - 1) / 5) * 5, "party Up reaches final row")
          visible(screen)
        end
        screen.region, screen.boxIndex = "box", i
        press(screen, "up")
        if i > 5 then
          T.eq(screen.boxIndex, i - 5, "Up returns to previous storage row")
          visible(screen)
        else
          T.check(exclusive and screen.region == "party" or screen.boxSwitching,
            "top row retains established header/party navigation")
          if screen.boxSwitching then press(screen, "b") end
        end
      end
    end
  end
end
local screen = fresh(50, 50)
run.loader.modOptions.modern_ui_suite["pc.box_exclusive"] = false
press(screen, "select"); press(screen, "a")
for i = 1, 50 do
  screen.boxPickerIndex = i
  local p = screen:modernPCLayoutInfo().picker
  T.check(i >= p.first and i <= p.last, "every box can be displayed in picker")
  T.check(p.last - p.first < 16, "picker keeps readable four-row viewport")
  press(screen, "a")
  T.eq(game.save.currentBox, i, "every picker entry opens correct box")
  press(screen, "select"); press(screen, "a")
end
screen.boxPickerIndex = 48; press(screen, "down")
T.eq(screen.boxPickerIndex, 50, "incomplete final picker row remains reachable")
press(screen, "a"); press(screen, "select"); press(screen, "right")
T.eq(game.save.currentBox, 1, "header wraps 50 to 1")
press(screen, "left"); T.eq(game.save.currentBox, 50, "header wraps 1 to 50")

-- Expanded source boxes must also validate when the destination is the party.
local Batch = dofile("mods/modern_ui_suite/components/modern_pc_ui/batch.lua")
local save = game.save
local marks = {}
for i = 1, 6 do
  marks[i] = { mon = save.boxes[1][44+i], sourceList = save.boxes[1],
    sourceIndex = 44+i, sourceBox = 1, sourceRegion = "box" }
end
local oldParty = save.party[1]
local plan = assert(Batch.plan(save, marks, save.party, 1, 6, 50))
T.check(Batch.commit(save, plan), "six selected final-row mons can swap with party")
T.eq(save.party[1], marks[1].mon, "whole-party swap preserves selected order")
T.eq(save.boxes[1][45], oldParty, "outgoing party mon occupies expanded source slot")
T.eq(#save.boxes[1], 50, "expanded source remains full after swap")
for i = 1, 49 do save.boxes[50][i] = {} end
T.eq(Batch.plan(save, marks, save.boxes[50], 50, 50, 50), nil,
  "stale/oversized batch cannot mutate storage")
marks = {}
for i = 1, 2 do marks[i] = {mon=save.boxes[1][i], sourceList=save.boxes[1],
  sourceIndex=i, sourceBox=1, sourceRegion="box"} end
T.eq(Batch.plan(save, marks, save.boxes[50], 50, 50, 50), nil,
  "two mons cannot fit in one remaining slot")
T.eq(#save.boxes[50], 49, "refusal preserves destination")
Boxes.CAPACITY, Boxes.COUNT = 20, 12
run.release()
T.finish("expanded PC storage")
