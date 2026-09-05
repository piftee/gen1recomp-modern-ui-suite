-- Live Gold/Silver/Crystal driver for the Modern UI Suite's Gen 2 Bag.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Bag = require("src.inventory.Bag")
  local GameVersion = require("src.core.GameVersion")
  local Screens = require("src.ui.Screens")

  local edition = GameVersion.get()
  local shotDir = os.getenv("SHOT_DIR") or "/tmp/gen2-bag-parity"
  local function check(value, message)
    if not value then error("GEN2 BAG PARITY FAILED: " .. message, 0) end
    U.log("PASS", edition, message)
  end
  local function clear()
    while game.stack:top() do game.stack:pop() end
  end
  local function capture(name, width, height)
    love.window.setMode(width, height, { resizable = true })
    U.wait(2)
    check(U.shot(game, ("%s/%s-%s.png"):format(shotDir, edition, name)),
      name .. " screenshot captured")
  end
  local function checkLayout(pack, label)
    local info = pack:modernBagLayoutInfo()
    check(info.layout == "full-width-bottom", label .. " uses bottom details")
    check(info.detailPosition == "bottom", label .. " has no side detail rail")
    check(info.listWidth == info.detailWidth,
      label .. " list and detail both span the panel")
    check(info.detailWidth == pack.modernBagLastWideWidth,
      label .. " detail reaches the responsive panel edges")
    return info
  end
  local function pocketIs(pack, id)
    local info = pack:modernBagLayoutInfo()
    return info and info.pocket == id
  end
  local function switchTo(pack, id)
    for _ = 1, 6 do
      if pocketIs(pack, id) then return true end
      U.tap(game, "right")
    end
    return pocketIs(pack, id)
  end
  local function rowIndex(pack, id)
    for index, row in ipairs(pack.rows or {}) do
      if row.id == id then return index end
    end
  end

  game.save.inventory = {}
  game.save.bagOrder = nil
  for _, spec in ipairs({
    { "ESCAPE_ROPE", 2 }, { "POTION", 7 }, { "ANTIDOTE", 3 },
    { "POKE_BALL", 12 }, { "SQUIRTBOTTLE", 1 }, { "BICYCLE", 1 },
    { "TM_THUNDERPUNCH", 1 }, { "TM_RAIN_DANCE", 1 },
  }) do
    check(game.data.items[spec[1]] ~= nil, spec[1] .. " exists in cache")
    check(Bag.add(game.save, spec[1], spec[2], game.data),
      spec[1] .. " seeded into its native pocket")
  end
  game.mods.modOptions = game.mods.modOptions or {}
  game.mods.modOptions.modern_ui_suite =
    game.mods.modOptions.modern_ui_suite or {}
  game.mods.modOptions.modern_ui_suite["bag.skin"] = "modern"
  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.modern_ui_suite =
    game.save.options.modOptions.modern_ui_suite or {}
  game.save.options.modOptions.modern_ui_suite["bag.skin"] = "modern"

  clear()
  local pack = Screens.push(game, "Gen2PackMenu", {
    save = game.save,
    world = { useFieldItem = function() return nil end },
  })
  check(pack.modernBagGeneration == 2, "suite owns the native Pack controller")
  U.log("INFO", edition, "bag skin", pack:modernBagLayoutInfo().skin,
    "controller", tostring(pack.modernBagControllerReady))
  check(pack:modernBagLayoutInfo().pockets == 6,
    "modern presentation exposes six parity views")
  check(pocketIs(pack, "ITEMS"), "native ITEM cursor maps to Items")
  check(#pack.rows == 1 and pack.rows[1].id == "ESCAPE_ROPE",
    "Items excludes medicine without moving its storage")
  check(switchTo(pack, "MEDICINE"), "Medicine tab is reachable")
  check(#pack.rows == 2 and rowIndex(pack, "POTION")
      and rowIndex(pack, "ANTIDOTE"),
    "Medicine filters the native ITEM pocket")
  check(switchTo(pack, "ALL"), "All tab is reachable")
  check(#pack.rows == 8, "All spans all four native pockets")

  pack.index = assert(rowIndex(pack, "TM_THUNDERPUNCH"))
  U.tap(game, "a")
  check(pack.submenu ~= nil and pack:pocket().id == "TM_HM",
    "A on an All-view TM uses the native TM/HM action rules")
  check(table.concat(pack.submenu.rows, ",") == "use,give,quit",
    "TM USE/GIVE/QUIT actions are preserved")
  pack:closeSubmenu()

  pack.index = assert(rowIndex(pack, "BICYCLE"))
  U.tap(game, "a")
  check(pack.submenu ~= nil and pack:pocket().id == "KEY_ITEM",
    "A on an All-view key item uses native key-item rules")
  check(table.concat(pack.submenu.rows, ","):find("sel", 1, true) ~= nil,
    "the native SEL registration action remains available")
  pack:closeSubmenu()

  pack.index = assert(rowIndex(pack, "POTION"))
  U.tap(game, "a")
  local itemActions = pack.submenu and table.concat(pack.submenu.rows, ",") or ""
  check(pack:pocket().id == "ITEM" and itemActions:find("give", 1, true)
      and itemActions:find("toss", 1, true),
    "Medicine keeps native GIVE/TOSS and quantity paths")
  pack:closeSubmenu()

  U.tap(game, "start")
  check(pack.modernBagSortMenu and #pack.modernBagSortMenu.rows == 4,
    "Start opens Category asc/desc and Names A-Z/Z-A")
  capture("sort-compact", 320, 480)
  local compactInfo = checkLayout(pack, "small portrait")
  check(table.concat(compactInfo.tabLabels, ",") == "ALL,I,MED,B,TM,KEY",
    "small portrait abbreviates only labels that cannot fit")
  U.tap(game, "down")
  U.tap(game, "down")
  U.tap(game, "a")
  check(pack.modernBagSortMenu == nil, "choosing a sort returns to the Bag")
  local previous = ""
  for _, id in ipairs(game.save.bagOrder) do
    local name = tostring(game.data.items[id].name or id):lower()
    check(name >= previous, "Names A-Z order includes " .. id)
    previous = name
  end
  check(pack.rows[pack.index] and pack.rows[pack.index].id == "POTION",
    "sorting preserves the selected item")
  pack:modernBagSort("name", true)
  previous = string.rep("z", 64)
  for _, id in ipairs(game.save.bagOrder) do
    local name = tostring(game.data.items[id].name or id):lower()
    check(name <= previous, "Names Z-A order includes " .. id)
    previous = name
  end
  local categoryRank = { ITEMS = 1, MEDICINE = 2, BALL = 3, TM_HM = 4,
    KEY_ITEM = 5 }
  pack:modernBagSort("category", false)
  local previousRank = 0
  for _, id in ipairs(game.save.bagOrder) do
    local rank = categoryRank[pack:modernBagCategoryFor(id)]
    check(rank >= previousRank, "Category ascending includes " .. id)
    previousRank = rank
  end
  pack:modernBagSort("category", true)
  previousRank = 99
  for _, id in ipairs(game.save.bagOrder) do
    local rank = categoryRank[pack:modernBagCategoryFor(id)]
    check(rank <= previousRank, "Category descending includes " .. id)
    previousRank = rank
  end

  capture("all-portrait", 320, 480)
  checkLayout(pack, "small portrait browsing")
  capture("all-wide", 1200, 720)
  local normalInfo = checkLayout(pack, "normal landscape")
  check(table.concat(normalInfo.tabLabels, ",")
      == "ALL,ITEMS,MED,BALLS,TM/HM,KEY",
    "normal landscape keeps readable tab names")
  check(switchTo(pack, "MEDICINE"), "Medicine remains reachable after sorting")
  capture("medicine-mobile", 854, 390)
  local compactLandscapeInfo = checkLayout(pack, "compact landscape")
  check(compactLandscapeInfo.tabLabels[2] == "ITEMS"
      and compactLandscapeInfo.tabLabels[3] == "MEDICINE"
      and compactLandscapeInfo.tabLabels[4] == "BALLS",
    "compact landscape uses full tab names where they fit")
  check(switchTo(pack, "TM_HM"), "TM/HM remains reachable after sorting")
  capture("tm-wide", 1776, 1332)
  local largeInfo = checkLayout(pack, "large display")
  local labels = largeInfo.tabLabels or {}
  U.log("INFO", edition, "large tab labels", table.concat(labels, ","))
  local readableLabels = #labels == 6 and labels[1] == "ALL"
    and (labels[2] == "ITEM" or labels[2] == "ITEMS")
    and (labels[3] == "MED" or labels[3] == "MEDICINE")
    and (labels[4] == "BALL" or labels[4] == "BALLS")
    and (labels[5] == "TM" or labels[5] == "TM/HM")
    and (labels[6] == "KEY" or labels[6] == "KEY ITEMS")
  for _, label in ipairs(labels) do
    if #label < 2 or label:find(".", 1, true) then readableLabels = false end
  end
  check(readableLabels,
    "large high-scale display keeps clear non-truncated tab labels")

  U.log("PASS", edition,
    "Gen 2 Bag parity completed (six views, native actions, Start sorting)")
end
