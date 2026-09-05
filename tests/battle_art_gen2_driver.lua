-- Integration against the unmodified Battle Art 2.1.0 release, with a fresh QA save.
return function(game)
  local U = dofile(assert(os.getenv("PC_REPO")) .. "/tests/drivers/util.lua")
  local Save = require("src.core.gen2.Save")
  local Mon = require("src.battle.gen2.Mon")
  local Battle = require("src.battle.gen2.Battle")
  local View = require("src.ui.gen2.BattleAnimView")
  local Screens = require("src.ui.Screens")
  local World = require("src.world.gen2.World")
  local api = assert(game.mods.exports.BATTLE_ART_VOXEL_GEN2, "Battle Art release must load")
  assert(api.version == "2.1.0")
  local staged = api.lib.require("OverworldBattle")
  local baseline = os.getenv("EXPECT_BASELINE") == "1"
  local checks = 0
  local function check(ok, message)
    assert(ok, "BATTLE ART QA: " .. message)
    checks = checks + 1
  end
  love.window.setMode(1280, 720, { resizable = true })
  while game.stack:top() do game.stack:pop() end
  game.save = Save.newGame({ playerName = "VOXEL QA", trainerId = 4321 })
  game.save.options = game.options or game.save.options or {}
  game.save.options.musicVol, game.save.options.sfxVol, game.save.options.pikaVol = 0, 0, 0
  game.save.party = { Mon.new(game.data, "CYNDAQUIL", 15) }
  local options = game.mods.modOptions.modern_ui_suite
  options["battle_hud.enabled"], options["move_colors.enabled"] = true, true
  local world = game.world or World.new(game)
  game.world = world
  if not world.maps then assert(world:load()) end
  assert(world:setMap("ROUTE_29", 12, 8, "down"), "real outdoor map loads")
  api.lib.require("Gen2WorldAdapter").prepareWorld(world)
  local battle = Battle.new({ data = game.data, save = game.save, party = game.save.party,
    wild = Mon.new(game.data, "SENTRET", 5), random = function() return 0 end })
  local screen = Screens.push(game, "Gen2BattleState", { save = game.save, battle = battle,
    onDone = function() end })
  screen.slideFrame = View.SLIDE_FRAMES
  screen.showPlayerTrainer, screen.showEnemyTrainer = false, false
  screen.showEnemyHud, screen.showPlayerHud = true, true
  screen.ballRows, screen.queue, screen.anim = {}, {}, nil
  screen.messageTimer, screen.phase = 0, "menu"
  screen.message, screen.typer = nil, nil
  local nativeUpdate = screen.update
  screen.update = function() end
  check(staged.arena(), "native battle.started stages a real Route 29 arena")
  for _ = 1, 120 do
    U.wait(1)
    if staged.shot() then break end
  end
  assert(staged.shot() and staged.shot().canvas, "actual GPU arena canvas is ready")
  assert(api.battleStage.state(screen) and not api.battleStage.state(battle),
    "release contract expects the screen, not the underlying battle model")
  assert(U.shot(game, os.getenv("SHOT_DIR") .. "/menu.png"))
  if baseline then
    assert(not screen.modernBattleYieldedTo3D and screen.modernBattleKeptIntact,
      "baseline reproduces suite's stock capture over the live 3D scene")
  else
    assert(screen.modernBattleYieldedTo3D, "suite must retain actual Battle Art compositor")
    assert(not screen.modernBattleKeptIntact, "suite must not flatten the arena")
  end
  screen.phase = "moves"
  assert(U.shot(game, os.getenv("SHOT_DIR") .. "/moves.png"))
  assert(staged.enabled(), "suite must not turn off 3D-BTL")
  if not baseline then
    local function capture(name)
      screen.modernBattleKeptIntact = nil
      U.wait(2)
      check(U.shot(game, os.getenv("SHOT_DIR") .. "/" .. name .. ".png"), name .. " captured")
      check(not love.window.hasFocus() and love.audio.getVolume() == 0,
        name .. " stayed silent and unfocused")
    end
    for _, mode in ipairs({ { "suite", true, true }, { "hud-only", true, false },
        { "typed-only", false, true }, { "both-off", false, false } }) do
      options["battle_hud.enabled"], options["move_colors.enabled"] = mode[2], mode[3]
      for _, size in ipairs({ { "wide", 1280, 720 }, { "classic", 800, 720 },
          { "portrait", 480, 900 } }) do
        love.window.setMode(size[2], size[3], { resizable = true })
        for _, phase in ipairs({ "menu", "moves" }) do
          screen.phase, screen.typedMoveColorsGen2 = phase, nil
          capture(mode[1] .. "-" .. size[1] .. "-" .. phase)
          check(not screen.modernBattleKeptIntact, "no suite stock capture while staged")
          check((screen.modernBattleYieldedTo3D == true) == mode[2], "live HUD toggle respects scene owner")
          if phase == "moves" then
            check((screen.typedMoveColorsGen2 == true) == mode[3], "move cards respect live component toggle")
          end
          check(api.battleStage.state(screen).ready, "Battle Art keeps a live GPU arena")
        end
      end
    end
    options["battle_hud.enabled"], options["move_colors.enabled"] = true, true
    love.window.setMode(1280, 720, { resizable = true })
    screen.phase, screen.moveIndex = "menu", 1
    local pressed
    local wasPressed, isDown = game.input.wasPressed, game.input.isDown
    game.input.wasPressed = function(_, key) return key == pressed end
    game.input.isDown = function() return false end
    local function tap(key) pressed = key; nativeUpdate(screen, 0); pressed = nil end
    tap("a")
    check(screen.phase == "moves", "native FIGHT enters move selection")
    tap("right")
    check(screen.moveIndex == 2, "D-pad follows the visible two-column move cards")
    tap("select"); tap("down")
    check(screen.moveSwapIndex == 2 and screen.moveIndex == 4, "native move pickup and destination stay usable")
    capture("move-pickup")
    tap("b")
    check(screen.moveSwapIndex == nil, "native cancellation clears the move pickup")
    if screen.phase == "moves" then tap("b") end
    check(screen.phase == "menu", "native cancellation returns to battle commands")
    screen.phase = "resolving"
    check(screen:animForMove("EMBER", "player"), "native Ember animation starts")
    local animation = screen.anim
    for _ = 1, 12 do nativeUpdate(screen, 1 / 60); U.wait(1) end
    capture("ember-animation")
    check(screen.anim == animation, "3D drawing restores the native animation object")
    check(api.battleStage.state(screen).ready, "move animation retains the 3D arena")
    game.input.wasPressed, game.input.isDown = wasPressed, isDown
    screen.anim, screen.phase = nil, "menu"

    -- The existing wrapper must recover when the player returns to 2D, and
    -- resume yielding if the same screen is staged again.
    staged.setting:setIndex(2, game)
    staged.finish(); staged.worldReady()
    capture("3d-off")
    check(not staged.enabled() and not api.battleStage.state(screen), "3D-BTL OFF has no active scene")
    check(screen.modernBattleKeptIntact and not screen.modernBattleYieldedTo3D,
      "normal battles regain the suite's responsive presentation")
    options["battle_hud.enabled"] = false
    capture("3d-off-hud-off")
    check(not screen.modernBattleKeptIntact, "live HUD OFF also restores the ordinary native renderer")
    options["battle_hud.enabled"] = true
    staged.setting:setIndex(1, game)
    check(staged.begin(world, screen), "3D-BTL can stage again after an OFF/ON change")
    for _ = 1, 120 do U.wait(1); if staged.shot() then break end end
    capture("3d-restored")
    check(screen.modernBattleYieldedTo3D and not screen.modernBattleKeptIntact,
      "3D-BTL ON restores Battle Art with suite components still enabled")
  end
  assert(not love.window.hasFocus() and love.audio.getVolume() == 0)
  print("[BATTLE ART QA] PASS " .. (baseline and "baseline reproduction" or "fixed 3D composition")
    .. " " .. checks .. " checks")
  love.event.quit(0)
end
