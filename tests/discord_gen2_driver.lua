return function(game)
  local U = dofile(assert(os.getenv("PC_REPO")) .. "/tests/drivers/util.lua")
  local Screens = require("src.ui.Screens")
  local Mon = require("src.battle.gen2.Mon")
  local Battle = require("src.battle.gen2.Battle")
  local opts = game.mods.modOptions.modern_ui_suite
  local function clear() while game.stack:top() do game.stack:pop() end end
  local function press(menu, key)
    local input = game.input
    game.input = setmetatable({ wasPressed = function(_, k) return k == key end,
      isDown = function() return false end }, { __index = input })
    local ok, err = pcall(menu.update, menu, 0)
    game.input = input
    assert(ok, err)
  end
  local function shot(name, w, h)
    love.window.setMode(w, h, { resizable = true })
    U.wait(2)
    assert(not love.window.hasFocus() and love.audio.getVolume() == 0)
    assert(U.shot(game, os.getenv("SHOT_DIR") .. "/" .. name .. ".png"))
  end
  game.save.inventory = { ANTIDOTE = 3, HYPER_POTION = 2, POTION = 8,
    SUPER_POTION = 4, ULTRA_BALL = 1, POKE_BALL = 10, GREAT_BALL = 5 }
  game.save.bagOrder = { "ANTIDOTE", "HYPER_POTION", "POTION", "SUPER_POTION",
    "ULTRA_BALL", "POKE_BALL", "GREAT_BALL" }
  game.save.party = { Mon.new(game.data, "CYNDAQUIL", 15), Mon.new(game.data, "MAREEP", 15),
    Mon.new(game.data, "TOTODILE", 15), Mon.new(game.data, "CHIKORITA", 15) }
  for _, skin in ipairs({ "modern", "classic_pocket" }) do
    clear()
    opts["bag.skin"] = skin
    opts["bag.open_on"] = "medicine"
    game:pushStartMenuItem("pack")
    local pack = game.stack:top()
    assert(pack.modernBagGeneration == 2, "field PACK is decorated")
    assert(pack.modernBagControllerReady, "native Pack controller is available")
    pack:modernBagSort("category", false)
    assert(pack.rows[1].id == "POTION" and pack.rows[2].id == "SUPER_POTION"
      and pack.rows[3].id == "HYPER_POTION" and pack.rows[4].id == "ANTIDOTE")
    for _, size in ipairs({ { "wide", 1280, 720 }, { "portrait", 480, 900 } }) do
      shot("field-bag-" .. skin .. "-" .. size[1], size[2], size[3])
    end
    print("[DISCORD QA] field bag and category sort", skin)
  end
  clear()
  opts["bag.skin"] = "modern"
  game.save.party[1].hp = 0
  local battle = Battle.new({ data = game.data, save = game.save, party = game.save.party,
    wild = Mon.new(game.data, "PIDGEY", 5) })
  local screen = Screens.push(game, "Gen2BattleState", { save = game.save, battle = battle, onDone = function() end })
  screen:openPack()
  local pack = game.stack:top()
  assert(pack.modernBagGeneration == 2, "battle PACK is decorated")
  shot("battle-bag", 1280, 720)
  press(pack, "b")
  assert(game.stack:top() == screen, "native B returns to battle")
  screen:openParty(true)
  local picker = game.stack:top()
  assert(picker.modernPartyGeneration == 2)
  picker.index = 1
  shot("party-fainted-selection", 1280, 720)
  press(picker, "right")
  assert(picker.index == 2, "selection moves to the second card")
  shot("party-pale-selection", 480, 900)
  press(picker, "a")
  assert(game.stack:top() ~= picker and battle.player == game.save.party[2], "native healthy replacement works")
  clear()
  print("[DISCORD QA] PASS")
end
