-- Native regression for battle colour masks leaking into an opaque Bag.
return function(game)
  local U = dofile(assert(os.getenv("PC_REPO")) .. "/tests/drivers/util.lua")
  local Battle = require("src.battle.BattleState")
  local Pokemon = require("src.pokemon.Pokemon")
  local Screens = require("src.ui.Screens")
  local Palette = require("src.render.PaletteFX")
  local opts = game.mods.modOptions.modern_ui_suite
  love.window.setMode(1294, 746, {resizable=true})
  game.save.options.colors = "redpp"
  game.save.options.battleBg = "world"
  game.save.options.textSpeed, game.save.options.animations = 1, false
  Palette.setMode("redpp")
  game.save.party = {Pokemon.new(game.data, "IVYSAUR", 25)}
  game.save.party[1].status = "PSN"
  game.save.inventory = {MASTER_BALL=5, POKE_BALL=76, POTION=7, ANTIDOTE=3}
  game.save.bagOrder = {"MASTER_BALL", "POKE_BALL", "POTION", "ANTIDOTE"}
  opts["bag.hide_all"], opts["bag.open_on"] = true, "items"
  U.teleport(game, "ROUTE_1", 5, 5, "down")
  local battle = Battle.newWild(game, "PIDGEY", 16, {onFinish=function() end})
  game.stack:push(battle)
  battle.introSlide, battle.introBalls, battle.current = 0, nil, nil
  battle.showEnemyTrainer, battle.showPlayerBack = false, false
  battle.enemySendingOut, battle.sendingOut = false, false
  battle.phase, battle.queue, battle.afterQueue = "menu", {}, "menu"
  U.wait(3)
  local before = #Palette.trueColorRects("ui")
  assert(before > 0, "battle has native true-colour HUD regions")
  for _, skin in ipairs({"modern", "classic_pocket"}) do
    opts["bag.skin"] = skin
    local bag = Screens.push(game, "BagMenu", {battle=battle})
    for _=1,6 do
      if bag.items[1] and bag.items[1].value == "MASTER_BALL" then break end
      bag:modernBagSwitchPocket(1)
    end
    bag.index = 2
    U.wait(3)
    assert(not love.window.hasFocus() and love.audio.getVolume() == 0)
    assert(U.shot(game, os.getenv("SHOT_DIR") .. "/" .. skin .. "-bag.png"))
    local remaining = #Palette.trueColorRects("ui")
    print("[BATTLE BAG] " .. skin .. " battle-marks=" .. before .. " bag-marks=" .. remaining)
    if os.getenv("EXPECT_BASELINE") ~= "1" then
      assert(remaining == 0, "covered battle regions must not bypass Bag colourization")
    end
    bag:close()
    if os.getenv("EXPECT_BASELINE") ~= "1" then
      bag = Screens.push(game, "BagMenu", {battle=battle})
      assert(bag.items[bag.index].value == "POKE_BALL", "reopened Bag restores ball selection")
      bag:close()
    end
  end
  U.wait(2)
  assert(#Palette.trueColorRects("ui") > 0, "battle colours return after closing Bag")
  if os.getenv("EXPECT_BASELINE") ~= "1" then
    opts["bag.skin"] = "modern"
    local function openBattleBag()
      if battle.chooseMenu then assert(battle:chooseMenu("item"))
      else battle:openItems() end
      for _=1,120 do
        if game.stack:top() ~= battle then break end
        U.wait(1)
      end
      local bag = game.stack:top()
      assert(bag.modernBagUI, "native ITEM action opens Bag")
      return bag
    end
    local bag = openBattleBag()
    for _=1,6 do
      if bag.items[1] and bag.items[1].value == "POTION" then break end
      bag:modernBagSwitchPocket(1)
    end
    bag.index = 2
    assert(bag.items[bag.index].value == "ANTIDOTE")
    U.tap(game,"a")
    assert(game.stack:top() ~= bag, "medicine opens native party picker")
    U.tap(game,"a")
    for _=1,800 do
      if game.stack:top() == battle and battle.phase == "menu" then break end
      U.tap(game,"a")
    end
    assert(game.save.inventory.ANTIDOTE == 2, "native medicine use consumes exactly one")
    assert(game.save.party[1].status ~= "PSN", "native medicine cures poison")
    assert(game.stack:top() == battle and battle.phase == "menu", "item turn returns to battle menu")
    -- Open through the battle controller's ITEM action, then cancel targeting.
    bag = openBattleBag()
    assert(bag.modernBagUI and bag.items[bag.index].value == "ANTIDOTE",
      "battle ITEM restores the used medicine and pocket")
    U.tap(game,"a"); U.tap(game,"b")
    assert(game.stack:top() == bag and bag.items[bag.index].value == "ANTIDOTE",
      "cancelled party targeting retains medicine selection")
    assert(game.save.inventory.ANTIDOTE == 2, "cancel does not consume medicine")
    for _, size in ipairs({{1294,746,"wide"},{480,900,"portrait"}}) do
      love.window.setMode(size[1],size[2],{resizable=true})
      U.wait(3)
      assert(not love.window.hasFocus() and love.audio.getVolume() == 0)
      assert(U.shot(game, os.getenv("SHOT_DIR") .. "/remembered-medicine-" .. size[3] .. ".png"))
      assert(#Palette.trueColorRects("ui") == 0, "resized Bag keeps covered battle regions clear")
    end
    print("[BATTLE BAG] native medicine turn, reopen and target cancel passed")
  end
  print("[DISCORD QA] PASS")
end
