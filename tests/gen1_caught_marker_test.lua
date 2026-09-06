-- Headless: luajit mods/modern_ui_suite/tests/gen1_caught_marker_test.lua [mod path]
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local BattleState = require("src.battle.BattleState")
local Runtime = require("src.mods.Runtime")
local Font = require("src.render.Font")
local Assets = require("src.render.Assets")
local nativeHUD = BattleState.drawHUDs
local failNative, nativeMarkerCalls = false, 0
-- The checkout predates the engine's native caught-marker API. Exercise the
-- current engine contract here too, as enabled by Kanto Gear's visibility hook.
BattleState.drawHUDs = function(battle, ...)
  if battle.kind == "wild" and battle.game.save.pokedex.owned.FIXMON_B then
    battle:drawCaughtBall(72, 0)
  end
  if failNative then error("simulated native HUD error") end
  return nativeHUD(battle, ...)
end
BattleState.drawZonePass = function() return "native-zone" end
local root = arg[1] or "mods/modern_ui_suite"
local run = T.sdk.loadMod(root, {data=T.fixtures.fresh(), dev=true})
T.eq(#run.errors, 0, "HUD loads cleanly")
Font.load(run.data)
local game = {data=run.data, mods=run.loader,
  save={options={}, party={}, pokedex={owned={FIXMON_B=true}}}}
local battle = setmetatable({game=game, data=run.data, kind="wild", phase="menu",
  frame=1, enemy={name="FIXMON B", shownHP=20,
    mon={species="FIXMON_B", level=6, hp=20, stats={hp=20}}},
  colorMode=function() return false end,
  drawCaughtBall=function() nativeMarkerCalls = nativeMarkerCalls + 1 end,
}, {__index=BattleState})
local nativeMarker = battle.drawCaughtBall

local draws, rows, scissorWrites = {}, {}, 0
local g = love.graphics
local nativeRow = BattleState.drawBallRow
-- Crystal queues this call for a later overlay, outside the HUD's scissor.
battle.drawBallRow = function(_, ...)
  rows[#rows+1] = {...}
end
-- Battle Art suppresses scissors during HUD capture.
g.setScissor = function() scissorWrites = scissorWrites + 1 end
g.draw = function(img, quad, x, y)
  if type(img) == "table" and img.path then
    if img.path:match("/battle/caught_ball%.png$") then
      draws[#draws+1] = {img=img, x=quad, y=x}
    elseif img.path:match("/battle/balls%.png$") then
      draws[#draws+1] = {img=img, quad=quad, x=x, y=y}
    end
  end
end
for _, layout in ipairs({"classic", "wide", "shaking"}) do
  battle.wideLayout = function() return layout == "wide" end
  battle.fx = layout == "shaking" and {hudShakeX=2} or nil
  local function draw()
    draws, rows, scissorWrites = {}, {}, 0
    nativeMarkerCalls = 0
    if layout == "wide" then
      Runtime.call("battle.overlay", function() end, battle)
    else battle:drawHUDs(0) end
  end
  for _, case in ipairs({{"wild", true, 1}, {"wild", false, 0},
      {"trainer", true, 0}, {"link", true, 0}}) do
    battle.kind, game.save.pokedex.owned.FIXMON_B = case[1], case[2]
    draw()
    T.eq(#draws, case[3], layout .. " " .. case[1] .. " caught=" .. tostring(case[2]))
    T.eq(#rows, 0, "caught indicator never queues a party overlay")
    T.eq(nativeMarkerCalls, 0, "native marker cannot overlap the HUD marker")
    T.eq(battle.drawCaughtBall, nativeMarker, "native marker method restored after capture")
    T.eq(scissorWrites, 0, "caught indicator never replaces the caller's clip")
    if draws[1] then
      T.same({draws[1].img:getDimensions()}, {8,8}, "only one native ball tile is drawn")
    end
  end
end
-- The marker must appear only after the internal HP-palette pass, at the
-- shaken position. Repainting over an earlier marker can leave a double edge.
battle.kind, game.save.pokedex.owned.FIXMON_B = "wild", true
battle.wideLayout, battle.colorMode = function() return false end, function() return true end
battle.fx = {hudShakeX=2}
draws = {}
battle:drawHUDs(0)
T.eq(#draws, 0, "colorized background contains no caught marker")
T.eq(battle:drawZonePass("background", 3, 1), "native-zone", "native palette pass preserved")
T.eq(#draws, 1, "one marker draws after the palette pass")
T.eq(draws[1].x, 8 + Font.width(battle.enemy.name) + 2 + 5, "marker follows window and HUD shake")
T.eq(draws[1].y, 1, "marker follows vertical window shake")
failNative = true
T.raises(function() battle:drawHUDs(0) end, "simulated native HUD error", "capture errors propagate")
T.eq(battle.drawCaughtBall, nativeMarker, "capture errors restore the native marker method")
failNative = false
local owner = root == "mods/modern_ui_suite" and "modern_ui_suite" or "battle_info_hud"
local key = owner == "modern_ui_suite" and "battle_hud.enabled" or "enabled"
run.loader.modOptions[owner] = run.loader.modOptions[owner] or {}
run.loader.modOptions[owner][key] = false
nativeMarkerCalls, draws = 0, {}
battle:drawHUDs(0)
T.eq(nativeMarkerCalls, 1, "HUD OFF restores the companion's native caught marker")
T.eq(#draws, 0, "HUD OFF adds no marker")
run.loader.modOptions[owner][key] = true
-- Asset invalidation must not leave a stale image cached in the marker.
battle.kind, battle.wideLayout = "wild", function() return true end
game.save.pokedex.owned.FIXMON_B = true
draws = {}
Runtime.call("battle.overlay", function() end, battle)
local before = draws[1].img
Assets.invalidate()
Runtime.call("battle.overlay", function() end, battle)
T.check(draws[2].img ~= before, "caught marker follows refreshed assets")

-- The real party-row renderer still has six slots with the correct states.
draws = {}
nativeRow(battle, {{hp=20},{hp=10,status="PSN"},{hp=0}}, 64, 16, -8)
T.eq(#draws, 6, "trainer party row retains all six slots")
for i, tile in ipairs({0,1,2,3,3,3}) do
  T.eq(draws[i].quad.x, tile*8, "trainer slot " .. i .. " retains its status tile")
  T.eq(draws[i].x, 64-(i-1)*8, "trainer slot " .. i .. " retains its position")
end
T.finish("Gen 1 caught marker: " .. root)
