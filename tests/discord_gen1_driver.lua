return function(game)
  local U = dofile(assert(os.getenv("PC_REPO")) .. "/tests/drivers/util.lua")
  local Screens = require("src.ui.Screens")
  local Pokemon = require("src.pokemon.Pokemon")
  local Strings = require("src.core.Strings")
  local MoveLearn = require("src.ui.MoveLearnMenu")
  local suite = game.mods.exports.modern_ui_suite
  local opts = game.mods.modOptions.modern_ui_suite
  local function clear() while game.stack:top() do game.stack:pop() end end
  local function shot(name)
    U.wait(2)
    assert(not love.window.hasFocus() and love.audio.getVolume() == 0)
    assert(U.shot(game, os.getenv("SHOT_DIR") .. "/" .. name .. ".png"))
  end
  game.save.party = { Pokemon.new(game.data, "SQUIRTLE", 20) }
  local mon = game.save.party[1]
  mon.moves = { { id = "TACKLE", pp = 35 }, { id = "BITE", pp = 25 },
    { id = "BUBBLE", pp = 30 }, { id = "WATER_GUN", pp = 25 } }
  for _, mode in ipairs({ { "cards", false }, { "text", true } }) do
    clear()
    opts["move_colors.text_only"] = mode[2]
    local learner = MoveLearn.new(game, mon, "SURF", function() end)
    game.stack:push(learner)
    learner.selecting, learner.index = true, 2
    while game.stack:top() ~= learner do game.stack:pop() end
    for _, size in ipairs({ { "wide", 1280, 720 }, { "portrait", 480, 900 } }) do
      love.window.setMode(size[2], size[3], { resizable = true })
      shot("forget-" .. mode[1] .. "-" .. size[1])
      assert(learner._typedMoveColorsLearnRowBase == 7, "overlay follows current native row 7")
    end
  end
  clear()
  game.save.flags.EVENT_GOT_POKEDEX = true
  local translations = { ["POKéDEX"] = "ずかん", ["POKéMON"] = "ポケモン", ITEM = "どうぐ",
    SAVE = "レポート", OPTION = "せってい", MODS = "モッド", QUIT = "とじる" }
  local expected = { ["ずかん"] = "pokedex", ["ポケモン"] = "party", ["どうぐ"] = "bag",
    ["レポート"] = "save", ["せってい"] = "options", ["モッド"] = "mods", ["とじる"] = "quit" }
  Strings.load({ strings = translations })
  local start = Screens.push(game, "StartMenu")
  local presentation = suite.components.modern_start_menu_ui.exports.presentation
  local found = 0
  for _, item in ipairs(start.items) do
    if expected[item.label] then
      found = found + 1
      assert(presentation.iconFor(item, game) == expected[item.label], "Japanese built-in icon")
    end
  end
  assert(found >= 5, "actual native menu has translated label-only rows")
  shot("translated-start")
  Strings.load(game.data)
  clear()
  print("[DISCORD QA] PASS")
end
