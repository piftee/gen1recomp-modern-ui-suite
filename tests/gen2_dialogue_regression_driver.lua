-- Native renderer/input comparison for capture dialogue and battle Yes/No.
return function(game)
  local U = dofile(assert(os.getenv("PC_REPO")) .. "/tests/drivers/util.lua")
  local Save = require("src.core.gen2.Save")
  local Mon = require("src.battle.gen2.Mon")
  local Battle = require("src.battle.gen2.Battle")
  local View = require("src.ui.gen2.BattleAnimView")
  local Screens = require("src.ui.Screens")
  local Font = require("src.render.Font")
  local Chrome = require("src.ui.gen2.Chrome")
  local edition = require("src.core.GameVersion").get()
  local baseline = os.getenv("EXPECT_BASELINE") == "1"
  local checks = 0
  local function check(ok, why)
    assert(ok, "DIALOGUE: " .. why); checks = checks + 1
  end
  local options = game.mods.modOptions.modern_ui_suite
  local function fixture(hud, typed)
    options["battle_hud.enabled"], options["move_colors.enabled"] = hud, typed
    options["move_colors.text_position"] = "left"
    options["move_colors.box_color"] = "original"
    options["move_colors.info_position"] = "original"
    options["move_colors.opacity"] = "100"
    while game.stack:top() do game.stack:pop() end
    Screens.invalidate()
    game.save = Save.newGame({ playerName = "DIALOG QA", trainerId = 4321 })
    local player, enemy = Mon.new(game.data, "TOGEPI", 12), Mon.new(game.data, "MAREEP", 6)
    game.save.party = { player, Mon.new(game.data, "CYNDAQUIL", 10) }
    game.save.options = { battleLayout = "og" }
    local battle = Battle.new({ data = game.data, save = game.save,
      party = game.save.party, wild = enemy, random = function() return 0 end })
    local screen = Screens.push(game, "Gen2BattleState", { save = game.save,
      battle = battle, onDone = function() end })
    screen.slideFrame = View.SLIDE_FRAMES
    screen.showPlayerTrainer, screen.showEnemyTrainer = false, false
    screen.showEnemyHud, screen.showPlayerHud = true, true
    screen.ballRows, screen.queue = {}, {}
    screen.anim, screen.message, screen.typer = nil, nil, nil
    screen.messageTimer, screen.phase = 0, "resolving"
    return screen, enemy
  end
  local pressed
  game.input.wasPressed = function(_, key) return key == pressed end
  game.input.isDown = function() return false end
  local function tap(screen, key) pressed = key; screen:update(0); pressed = nil end
  local function reveal(screen)
    screen:syncTyper(); screen.typer.shown = screen.typer.total
  end
  local observed, glyphs = {}, {}
  local encode, paletteGlyphs = Font.encode, Chrome.paletteGlyphs
  Font.encode = function(value)
    observed[tostring(value)] = true; return encode(value)
  end
  Chrome.paletteGlyphs = function(...)
    local palette, draw, finish = paletteGlyphs(...)
    if not draw then return palette, draw, finish end
    return palette, function(code, x, y)
      glyphs[#glyphs + 1] = { x = x, y = y, right = x + Font.advanceOf(code) }
      return draw(code, x, y)
    end, finish
  end
  local function capture(screen, name)
    observed, glyphs = {}, {}; U.wait(2)
    local out = os.getenv("SHOT_DIR")
    if out then check(U.shot(game, out .. "/" .. edition .. "-" .. name .. ".png"), "captured " .. name) end
  end
  local function fits(screen, why)
    local width = screen.modernBattleLastWideWidth or 160
    for _, line in ipairs(screen.typer and screen.typer.page or {}) do
      check(Font.width(line) <= width - 16, why .. " complete native line fits available width")
    end
    for _, glyph in ipairs(glyphs) do
      if glyph.y >= 104 and glyph.y <= 128 then
        check(glyph.x >= 4 and glyph.right <= width - 4, why .. " rendered glyph stays inside border")
      end
    end
  end
  love.window.setMode(1027, 776, { resizable = true }); U.wait(2)
  for _, mode in ipairs({ { "suite-default", true, true }, { "hud-only", true, false },
      { "typed-only", false, true }, { "native", false, false } }) do
    local screen, enemy = fixture(mode[2], mode[3])
    screen:showPages("Gotcha! MAREEP was caught!"); reveal(screen)
    capture(screen, mode[1] .. "-caught")
    local raw = observed["Gotcha! MAREEP was caught!"] == true
    if baseline then
      check(raw == mode[2], mode[1] .. " isolates raw single-line text to HUD takeover")
    else
      check(not raw, mode[1] .. " renders native wrapped message lines")
    end
    screen:askNickname(enemy); reveal(screen); tap(screen, "a")
    capture(screen, mode[1] .. "-nickname")
    local choices = observed.YES and observed.NO
    if baseline then check(not not choices == not mode[2], mode[1] .. " isolates missing choices to HUD takeover")
    else check(choices, mode[1] .. " displays both native nickname choices") end
    local before = screen.nicknameIndex; tap(screen, "down")
    check(screen.nicknameIndex ~= before, mode[1] .. " native nickname cursor moves")
  end
  if not baseline then
    for _, mode in ipairs({ { "suite", true, true }, { "hud-only", true, false },
        { "typed-only", false, true }, { "native", false, false } }) do
      local screen = fixture(mode[2], mode[3])
      local originalWrap = Chrome.wrap
      local longWord = "ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMN"
      screen:showPages(longWord)
      reveal(screen)
      check(Chrome.wrap == originalWrap, mode[1] .. " showPages restores shared wrapper")
      check((Font.width(screen.typer.page[1]) <= 144) == (mode[2] or mode[3]),
        mode[1] .. " long-word correction respects component enable gates")
      local throwing = function() error("dialogue provider fixture") end
      Chrome.wrap = throwing
      local ok, why = pcall(screen.showPages, screen, "error fixture")
      check(not ok and tostring(why):find("dialogue provider fixture", 1, true),
        mode[1] .. " provider failure is not swallowed")
      check(Chrome.wrap == throwing, mode[1] .. " provider failure restores exact previous wrapper")
      Chrome.wrap = originalWrap
      screen:showPages("#MON used\nTHUNDER SHOCK!")
      reveal(screen)
      check(table.concat(screen.typer.page, "\n") == "#MON used\nTHUNDER SHOCK!",
        mode[1] .. " native tokens and hard line breaks stay intact")
    end
    local sizes = { { "16x9", 1280, 720 }, { "reported", 1027, 776 },
      { "square", 800, 720 }, { "portrait", 480, 900 }, { "compact", 320, 288 } }
    local settings = {
      { "default", "left", "original", "original", "100", "no" },
      { "center-black", "center", "black", "left", "100", "yes" },
      { "right-white", "right", "white", "right", "100", "cancel" },
      { "left-gray", "left", "gray", "original", "100", "no" },
      { "opacity-gate", "center", "black", "right", "70", "cancel" },
    }
    local function applySettings(row)
      options["move_colors.text_position"], options["move_colors.box_color"] = row[2], row[3]
      options["move_colors.info_position"], options["move_colors.opacity"] = row[4], row[5]
    end
    for _, size in ipairs(sizes) do
      love.window.setMode(size[2], size[3], { resizable = true }); U.wait(2)
      for _, settingsRow in ipairs(settings) do
        local tag = size[1] .. "-" .. settingsRow[1]
        local screen, enemy = fixture(true, true); applySettings(settingsRow)
        local originalNickname = enemy.nickname
        -- Use the real capture-completion queue and storage path. Only the
        -- audible wait is skipped after asserting that it was installed.
        game.save.pokedex.caught.MAREEP = true
        screen:pushCaught(enemy, "POKE_BALL"); screen:advanceQueue()
        check(screen.battle.outcome == "caught" and game.save.party[3] == enemy,
          tag .. " real capture stores exactly this mon")
        check(screen.waitSfx ~= nil, tag .. " native caught jingle still gates progression")
        screen.waitSfx, screen.waitSfxLeft, screen.messageDelay = nil, nil, 0
        reveal(screen); capture(screen, tag .. "-caught"); fits(screen, tag)
        local page, typer = screen.typer.page, screen.typer
        screen.typer.shown = 1; observed, glyphs = {}, {}; U.wait(1)
        local origin = screen.typedMoveColorsMessageOrigins and screen.typedMoveColorsMessageOrigins[1]
        screen.typer.shown = 5; U.wait(1)
        check(screen.typer == typer and screen.typer.page == page, tag .. " reveal preserves native page identity")
        if origin then check(screen.typedMoveColorsMessageOrigins[1] == origin, tag .. " alignment is stable during reveal") end
        reveal(screen); tap(screen, "a"); screen:update(0)
        check(screen.phase == "ask-nickname", tag .. " caught message advances into native nickname prompt")
        reveal(screen); tap(screen, "a"); capture(screen, tag .. "-nickname-yes")
        check(observed.YES and observed.NO and screen.nicknameIndex == 1,
          tag .. " nickname choices and native YES selection are visible")
        fits(screen, tag .. " nickname")
        if settingsRow[6] == "yes" then
          tap(screen, "a")
          local naming = game.stack:top()
          check(naming ~= screen and screen.phase == "submenu" and type(naming.onDone) == "function",
            tag .. " YES opens the real naming controller")
          naming.onDone("SPARK")
          check(enemy.nickname == "SPARK", tag .. " native naming completion changes only caught nickname")
        else
          tap(screen, "down"); capture(screen, tag .. "-nickname-no")
          check(screen.modernBattleChoiceBounds.index == 2, tag .. " visible cursor follows native NO")
          tap(screen, settingsRow[6] == "cancel" and "b" or "a")
          check(enemy.nickname == originalNickname, tag .. " NO or B retains caught nickname")
        end
        check(game.save.party[3] == enemy and #game.save.party == 3,
          tag .. " nickname flow retains captured party ownership")

        screen, enemy = fixture(true, true); applySettings(settingsRow)
        local first, second = game.save.party[1], game.save.party[2]
        screen:offerShiftSwitch(enemy)
        local guard = 0
        while screen.phase == "shift-intro" do
          reveal(screen); tap(screen, "a"); screen:update(0)
          guard = guard + 1; check(guard < 20, tag .. " shift introduction advances without looping")
        end
        check(screen.phase == "ask-shift", tag .. " real shift-mode prompt reached")
        reveal(screen); tap(screen, "a"); capture(screen, tag .. "-shift-yes")
        check(observed.YES and observed.NO and screen.shiftIndex == 1,
          tag .. " shift choices are visible after native introduction")
        fits(screen, tag .. " shift")
        if settingsRow[6] == "yes" then
          tap(screen, "a")
          local party = game.stack:top()
          check(party ~= screen and screen.phase == "submenu", tag .. " shift YES opens native party selection")
          tap(party, "b")
          check(game.stack:top() == screen, tag .. " native party cancellation returns to battle")
        else
          tap(screen, "down"); capture(screen, tag .. "-shift-no")
          check(screen.modernBattleChoiceBounds.index == 2, tag .. " shift NO cursor is visible")
          tap(screen, settingsRow[6] == "cancel" and "b" or "a")
        end
        check(game.save.party[1] == first and game.save.party[2] == second,
          tag .. " declining/cancelling switch preserves party order")
        check(screen.phase == "menu", tag .. " prompt dismissal restores native battle menu")
        capture(screen, tag .. "-dismissed")
        check(not observed.YES and not observed.NO and not screen.modernBattleChoiceBounds,
          tag .. " choices do not remain after dismissal")

        screen, enemy = fixture(true, true); applySettings(settingsRow)
        local longText = "ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMN used a very long move name!\nEvery final word must remain readable after the final page."
        local originalWrap = Chrome.wrap
        screen:showPages(longText)
        check(Chrome.wrap == originalWrap, tag .. " scoped word wrapping is restored")
        local collected, pages = {}, 0
        while true do
          reveal(screen); pages = pages + 1
          local carried = screen.messageCarried and screen.messageCarried[screen.messagePage]
          for index, line in ipairs(screen.typer.page) do
            if not (carried and index == 1) then collected[#collected + 1] = line end
          end
          observed, glyphs = {}, {}; U.wait(1); fits(screen, tag .. " long page")
          if not screen.messagePages then break end
          tap(screen, "a"); screen:update(0)
          check(pages < 32, tag .. " long message advances using native input")
        end
        check(table.concat(collected):gsub("%s+", "") == longText:gsub("%s+", ""),
          tag .. " every long-word/name and final-message character survives pagination")
        capture(screen, tag .. "-long-final")
      end
    end
  end
  Font.encode, Chrome.paletteGlyphs = encode, paletteGlyphs
  print(("[DIALOGUE %s] %s %d checks passed"):format(baseline and "BASELINE" or "FIX", edition, checks))
  love.event.quit(0)
end
