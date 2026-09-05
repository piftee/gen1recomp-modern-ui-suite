-- Live Gen 1/2 proof for money headers and complete Bag descriptions.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Bag = require("src.inventory.Bag")
  local GameVersion = require("src.core.GameVersion")
  local Screens = require("src.ui.Screens")

  local edition = GameVersion.get()
  local generation = type(GameVersion.generation) == "function"
    and GameVersion.generation(edition) or (edition == "red" and 1 or 2)
  local shotDir = os.getenv("SHOT_DIR") or "/tmp/bag-qol-proof"
  local function check(value, message)
    if not value then error("BAG QOL FAILED: " .. message, 0) end
    U.log("PASS", edition, message)
  end
  local function includesFinalWords(value)
    return type(value) == "string"
      and value:gsub("%s+", " "):find("truncated ending", 1, true) ~= nil
  end
  local function clear()
    while game.stack:top() do game.stack:pop() end
  end
  local function setSkin(value)
    game.mods.modOptions = game.mods.modOptions or {}
    game.mods.modOptions.modern_ui_suite =
      game.mods.modOptions.modern_ui_suite or {}
    game.mods.modOptions.modern_ui_suite["bag.skin"] = value
    game.save.options = game.save.options or {}
    game.save.options.modOptions = game.save.options.modOptions or {}
    game.save.options.modOptions.modern_ui_suite =
      game.save.options.modOptions.modern_ui_suite or {}
    game.save.options.modOptions.modern_ui_suite["bag.skin"] = value
  end
  local function capture(name, width, height, prepare)
    love.window.setMode(width, height, { resizable = true })
    U.wait(2)
    if prepare then prepare() end
    check(U.shot(game, ("%s/%s-%s.png"):format(shotDir, edition, name)),
      name .. " screenshot captured")
  end
  local function rowIndex(menu, id)
    local rows = type(menu.rows) == "table" and menu.rows or menu.items or {}
    for index, row in ipairs(rows) do
      if row.id == id or row.value == id then return index end
    end
  end
  local function headerFits(info, label)
    local header = info.header or {}
    if header.leftRight then
      check(header.twoRows or header.leftRight <= header.titleX,
        label .. " money does not collide with the title")
      check(header.titleRight <= header.capacityLeft,
        label .. " title does not collide with capacity")
    else
      check((header.cashX or 0) + (header.cashW or 0)
          <= (header.hintLeft or math.huge),
        label .. " money does not collide with controls")
      if header.countX and header.hintRight then
        check(header.hintRight <= header.countX,
          label .. " controls do not collide with the item count")
      end
    end
  end
  local function openBag()
    clear()
    local id = generation == 2 and "Gen2PackMenu" or "BagMenu"
    local opts = generation == 2 and {
      save = game.save,
      world = { useFieldItem = function() return nil end },
    } or {}
    return Screens.push(game, id, opts)
  end
  local function selectMedicine(menu, id)
    if generation == 2 and not rowIndex(menu, id) then
      for _ = 1, 6 do
        if rowIndex(menu, id) then break end
        U.tap(game, "right")
      end
    end
    menu.index = assert(rowIndex(menu, id), id .. " row missing")
  end

  local longDescription = table.concat({
    "This medicine restores health during a very long journey and preserves",
    "every word in this deliberately oversized description so the player can",
    "read the complete explanation instead of seeing a truncated ending.",
  }, " ")
  check(game.data.items.POTION ~= nil, "POTION exists in the active cache")
  check(game.data.items.ANTIDOTE ~= nil, "ANTIDOTE exists in the active cache")
  game.data.items.POTION.description = longDescription
  game.data.items.ANTIDOTE.description = "Cures poison."
  game.save.inventory = {}
  game.save.bagOrder = nil
  game.save.money = 999999
  check(Bag.add(game.save, "POTION", 7, game.data), "POTION is seeded")
  check(Bag.add(game.save, "ANTIDOTE", 3, game.data), "ANTIDOTE is seeded")

  setSkin("modern")
  local bag = openBag()
  selectMedicine(bag, "POTION")
  capture("modern-wide-start", 1200, 720,
    function() selectMedicine(bag, "POTION") end)
  local info = bag:modernBagQolInfo()
  check(info.money == "¥999999" and info.headerCash == info.money,
    "modern header shows exact maximum money")
  headerFits(info, "modern header")
  check(info.descriptionOverflow, "modern long description activates overflow")
  U.log("INFO", edition, "modern overflow tail", info.descriptionTail or "<none>")
  check(includesFinalWords(info.descriptionTail),
    "modern overflow retains the final words")
  bag:update(2)
  capture("modern-wide-scroll", 1200, 720)
  info = bag:modernBagQolInfo()
  check(info.descriptionOffset > 0, "modern description advances after its hold")
  selectMedicine(bag, "ANTIDOTE")
  capture("modern-portrait-reset", 320, 480,
    function() selectMedicine(bag, "ANTIDOTE") end)
  info = bag:modernBagQolInfo()
  check(not info.descriptionOverflow and info.descriptionOffset == 0,
    "selection change resets a fitting modern description")

  selectMedicine(bag, "POTION")
  bag:draw()
  bag:update(2)
  bag.modernBagPrompt = "How many?"
  if generation == 2 then bag.message = { "How many?" } end
  bag:draw()
  info = bag:modernBagQolInfo()
  check(info.descriptionOffset == 0,
    "quantity and confirmation prompts remain static")
  bag.modernBagPrompt = nil
  if generation == 2 then bag.message = nil end

  setSkin("classic_pocket")
  bag = openBag()
  selectMedicine(bag, "POTION")
  capture("pocket-landscape-start", 854, 390,
    function() selectMedicine(bag, "POTION") end)
  info = bag:modernBagQolInfo()
  check(info.money == "¥999999" and info.headerCash == info.money,
    "Pocket header shows exact maximum money")
  headerFits(info, "Pocket header")
  check(info.descriptionOverflow, "Pocket long description activates overflow")
  U.log("INFO", edition, "Pocket overflow tail", info.descriptionTail or "<none>")
  check(includesFinalWords(info.descriptionTail),
    "Pocket overflow retains the final words")
  bag:update(2)
  capture("pocket-landscape-scroll", 854, 390)
  info = bag:modernBagQolInfo()
  check(info.descriptionOffset > 0, "Pocket description advances after its hold")
  capture("pocket-portrait", 320, 480,
    function() selectMedicine(bag, "POTION") end)
  info = bag:modernBagQolInfo()
  check(info.headerCash == "¥999999",
    "Pocket portrait keeps the exact maximum-money header")
  headerFits(info, "Pocket portrait header")

  U.log("PASS", edition,
    "Bag money/description QoL completed for modern and Pocket skins")
end
