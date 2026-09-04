-- Native Gen 2 integration proof for Modern UI Suite's seven components.
-- Run this driver against an engine checkout with Gen 2 support and a Gen 2
-- cache; it fails immediately if the suite or one of its Gen 2 presenters is
-- not the implementation that the registry builds.
-- PROOF_WIDTH / PROOF_HEIGHT select the captured framebuffer; when omitted,
-- the original 800x720 native-aspect proof remains the default.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Bag = require("src.inventory.Bag")
  local Battle = require("src.battle.gen2.Battle")
  local BattleAnimView = require("src.ui.gen2.BattleAnimView")
  local Boxes = require("src.core.gen2.Boxes")
  local Chrome = require("src.ui.gen2.Chrome")
  local Font = require("src.render.Font")
  local GameVersion = require("src.core.GameVersion")
  local Mon = require("src.battle.gen2.Mon")
  local Screens = require("src.ui.Screens")
  local SummaryMenu = require("src.ui.gen2.SummaryMenu")
  local Unown = require("src.core.gen2.Unown")

  local DIR = os.getenv("SHOT_DIR") or "artifacts/gen2-compatibility"
  local edition = GameVersion.get()
  local editionLabel = edition:sub(1, 1):upper() .. edition:sub(2)
  local function shotPath(index, slug)
    return ("%s/%02d-%s-%s.png"):format(DIR, index, slug, edition)
  end
  local proofWidth = tonumber(os.getenv("PROOF_WIDTH")) or 800
  local proofHeight = tonumber(os.getenv("PROOF_HEIGHT")) or 720
  assert(proofWidth >= 160 and proofHeight >= 144,
    "GEN2 PROOF FAILED: proof viewport must hold the 160x144 game surface")
  love.window.setMode(proofWidth, proofHeight, {
    resizable = true, minwidth = 480, minheight = 360,
  })

  local function clear()
    while game.stack:top() do game.stack:pop() end
  end

  local function check(ok, message)
    if not ok then error("GEN2 PROOF FAILED: " .. message, 0) end
    U.log("PASS", message)
  end

  local actualWidth, actualHeight = love.graphics.getPixelDimensions()
  check(actualWidth == proofWidth and actualHeight == proofHeight,
    ("proof framebuffer is %dx%d (requested %dx%d)"):format(
      actualWidth, actualHeight, proofWidth, proofHeight))
  local proofScale = math.max(1, math.floor(math.min(
    proofWidth / 160, proofHeight / 144)))
  local expectedLogicalWidth = math.max(160,
    math.floor(proofWidth / proofScale))

  local shotIndex = 0
  local function capture(slug, message)
    shotIndex = shotIndex + 1
    U.wait(2)
    check(U.shot(game, shotPath(shotIndex, slug)),
      message .. " " .. editionLabel .. " screenshot captured")
  end

  local componentPrefixes = {
    battle_info_hud = "battle_hud",
    modern_bag_ui = "bag",
    modern_party_ui = "party",
    modern_pc_ui = "pc",
    modern_pokedex_ui = "pokedex",
    modern_start_menu_ui = "start_menu",
    typed_move_colors = "move_colors",
  }

  local function setOption(owner, key, value)
    local prefix = assert(componentPrefixes[owner],
      "unknown Modern UI Suite component: " .. tostring(owner))
    key, owner = prefix .. "." .. key, "modern_ui_suite"
    game.mods.modOptions = game.mods.modOptions or {}
    game.mods.modOptions[owner] = game.mods.modOptions[owner] or {}
    game.mods.modOptions[owner][key] = value
    game.save.options = game.save.options or {}
    game.save.options.modOptions = game.save.options.modOptions or {}
    game.save.options.modOptions[owner] =
      game.save.options.modOptions[owner] or {}
    game.save.options.modOptions[owner][key] = value
  end

  local loaderExports = game.mods and game.mods.exports or {}
  local suite = loaderExports.modern_ui_suite
  check(type(suite) == "table", "Modern UI Suite loaded on " .. editionLabel)
  local exports = {}
  for id, component in pairs(suite.components or {}) do
    exports[id] = component.exports
  end
  for _, id in ipairs({
    "battle_info_hud", "modern_bag_ui", "modern_party_ui", "modern_pc_ui",
    "modern_pokedex_ui", "modern_start_menu_ui", "typed_move_colors",
  }) do
    check(type(exports[id]) == "table",
      id .. " is exported by Modern UI Suite on " .. editionLabel)
  end
  for _, id in ipairs({
    "battle_info_hud", "modern_party_ui", "modern_pc_ui",
    "modern_pokedex_ui", "typed_move_colors",
  }) do
    check(exports[id].generation == 2, id .. " selected its Gen 2 path")
  end

  clear()
  local root = Screens.push(game, "Gen2OptionsMenu", {
    options = game.save.options,
  })
  check(root:focusRow("modern_ui_suite_settings") == root,
    "the suite hub is reachable from Gen 2 Options")
  U.tap(game, "a")
  local hub = game.stack:top()
  check(hub ~= root and hub.screenId == "modern_ui_suite:settings",
    "the unified suite settings hub opens on Gen 2")
  check(#(hub.items or {}) == 10,
    "the Gen 2 hub exposes both bulk actions and all seven components")
  hub.index = 3
  U.tap(game, "a")
  local page = game.stack:top()
  local visible = type(page.visible) == "function" and page:visible()
    or page.items or page.rows or {}
  check(page ~= hub and visible[1] and visible[1].id == "start_menu.enabled",
    "a component page opens from the unified Gen 2 hub")
  U.tap(game, "a")
  check(game.stack:top() == page,
    "a suite setting changes without closing its Gen 2 component page")
  U.tap(game, "a")
  check(visible[1].value() == "ON",
    "the Gen 2 settings smoke restores the component before screen proofs")
  clear()

  game.save.player = game.save.player or {}
  game.save.player.name = "GOLD"
  game.save.player.money = 18420
  game.save.options = game.save.options or {}
  game.save.pokedex = game.save.pokedex or { seen = {}, caught = {} }
  game.save.pokedex.seen = game.save.pokedex.seen or {}
  game.save.pokedex.caught = game.save.pokedex.caught or {}

  -- Modern Bag UI: native four-pocket PACK, decorated by the Gen 2 path.
  game.save.inventory = {}
  game.save.bagOrder = nil
  for _, entry in ipairs({
    { "POTION", 7 }, { "SUPER_POTION", 3 }, { "ANTIDOTE", 4 },
    { "REPEL", 6 }, { "ESCAPE_ROPE", 2 }, { "X_ATTACK", 2 },
    { "POKE_BALL", 12 }, { "GREAT_BALL", 5 },
    { "SQUIRTBOTTLE", 1 }, { "RAINBOW_WING", 1 },
    { "TM_THUNDERPUNCH", 1 }, { "TM_RAIN_DANCE", 1 },
  }) do
    if game.data.items[entry[1]] then
      Bag.add(game.save, entry[1], entry[2], game.data)
    end
  end
  setOption("modern_bag_ui", "skin", "modern")
  clear()
  local pack = Screens.push(game, "Gen2PackMenu", { save = game.save })
  pack.index = math.min(2, #pack.rows)
  pack.update = function() end
  check(pack.modernBagGeneration == 2,
    "Modern Bag owns the native Gen2PackMenu screen")
  capture("modern-bag", "Modern Bag list")
  check(pack.modernBagLastWideWidth == expectedLogicalWidth,
    ("Modern Bag uses a %dx144 logical layout"):format(expectedLogicalWidth))
  pack.submenu = {
    rows = { "use", "give", "toss", "sel", "quit" }, index = 2,
  }
  capture("modern-bag-actions", "Modern Bag action menu")
  pack.submenu = nil
  pack.qtyState = { qty = 3, max = 7,
    prompt = { "Toss out how many", "POTION(S)?" } }
  capture("modern-bag-quantity", "Modern Bag quantity selector")
  pack.qtyState = nil
  pack.confirm = { choice = 2,
    prompt = { "Throw away 3", "POTION(S)?" } }
  capture("modern-bag-confirm", "Modern Bag confirmation")
  pack.confirm = nil

  -- The item PC is part of Modern Bag's Gen 1 surface family in both games.
  game.save.pcItems = { POTION = 14, ANTIDOTE = 5, ESCAPE_ROPE = 2 }
  clear()
  local itemPc = Screens.push(game, "Gen2ItemPcMenu", { save = game.save })
  itemPc.update = function() end
  check(itemPc.modernBagGeneration == 2,
    "Modern Bag owns the native Gen2ItemPcMenu screen")
  capture("modern-item-pc", "Modern Item PC menu")
  check(itemPc.modernBagLastWideWidth == expectedLogicalWidth,
    ("Modern Item PC uses a %dx144 logical layout"):format(expectedLogicalWidth))
  itemPc.phase = "withdraw"
  itemPc:rebuild()
  itemPc.listIndex = math.min(2, #itemPc.rows)
  capture("modern-item-pc-items", "Modern Item PC item list")
  itemPc.qtyState = { qty = 4, max = 14,
    prompt = { "How many do you", "want to withdraw?" } }
  capture("modern-item-pc-quantity", "Modern Item PC quantity selector")
  itemPc.qtyState = nil
  itemPc.confirm = { choice = 2,
    prompt = { "Throw away 4", "POTION(S)?" } }
  capture("modern-item-pc-confirm", "Modern Item PC confirmation")

  -- Build a representative Johto party once for Party, PC and battle proofs.
  local partySpecs = {
    { "TYPHLOSION", 48, 0.88 }, { "AMPHAROS", 46, 0.62, "paralyze" },
    { "LAPRAS", 44, 0.30 }, { "NOCTOWL", 42, 0.76 },
    { "ESPEON", 43, 0.52 }, { "HERACROSS", 41, 1.00 },
  }
  local party = {}
  for i, spec in ipairs(partySpecs) do
    local mon = assert(Mon.new(game.data, spec[1], spec[2]))
    mon.hp = math.max(1, math.floor(mon.maxHp * spec[3]))
    mon.status = spec[4]
    party[i] = mon
  end
  game.save.party = party

  clear()
  local partyMenu = Screens.push(game, "Gen2PartyMenu", {
    save = game.save, submenu = true, prompt = "choose",
  })
  partyMenu.index = 2
  partyMenu.clock = 20
  partyMenu.update = function() end
  check(partyMenu.modernPartyGeneration == 2,
    "Modern Party owns the native Gen2PartyMenu screen")
  capture("modern-party", "Modern Party roster")
  check(partyMenu.modernPartyLastWideWidth == expectedLogicalWidth,
    ("Modern Party uses a %dx144 logical layout"):format(expectedLogicalWidth))
  partyMenu:openSubmenu()
  partyMenu.submenu.index = math.min(2, #partyMenu.submenu.items)
  capture("modern-party-actions", "Modern Party action menu")

  party[1].moves = {
    { id = "FLAMETHROWER", pp = 12, maxPp = 15 },
    { id = "THUNDERPUNCH", pp = 14, maxPp = 15 },
    { id = "EARTHQUAKE", pp = 10, maxPp = 10 },
    { id = "SWIFT", pp = 18, maxPp = 20 },
  }
  clear()
  local summary = Screens.push(game, "Gen2SummaryMenu", {
    save = game.save, party = party, index = 1,
    page = SummaryMenu.PINK_PAGE,
  })
  local summaryUpdate = summary.update
  summary.update = function() end
  check(summary.modernPartySummary and summary.modernPartyGeneration == 2,
    "Modern Party owns the native Gen2SummaryMenu screen")
  capture("modern-party-summary-stats", "Modern Party stats summary")
  check(summary.modernPartyLastWideWidth == expectedLogicalWidth,
    ("Modern Summary uses a %dx144 logical layout"):format(expectedLogicalWidth))
  summary.page = SummaryMenu.GREEN_PAGE
  capture("modern-party-summary-moves", "Modern Party moves summary")
  summary.page = SummaryMenu.BLUE_PAGE
  capture("modern-party-summary-trainer", "Modern Party trainer summary")
  summary.page = SummaryMenu.GREEN_PAGE
  summary.moveDetail = true
  summary.moveIndex = 2
  capture("modern-party-move-detail", "Modern Party move detail")
  if expectedLogicalWidth > 160 then
    summary.update = summaryUpdate
    summary.moveIndex = 1
    U.tap(game, "right")
    check(summary.moveIndex == 2,
      "Modern Summary RIGHT crosses the wide move grid")
    U.tap(game, "down")
    check(summary.moveIndex == 4,
      "Modern Summary DOWN crosses the wide move grid")
    summary.update = function() end
    summary.moveIndex = 2
  end
  check(summary.typedMoveColorsGeneration == 2,
    "Typed Move Colors decorates the native Gen2SummaryMenu controller")

  local egg = assert(Mon.new(game.data, "TOGEPI", 5))
  egg.isEgg = true
  egg.eggSteps = 18
  clear()
  local eggSummary = Screens.push(game, "Gen2SummaryMenu", {
    save = game.save, mon = egg, page = SummaryMenu.PINK_PAGE,
  })
  eggSummary.update = function() end
  capture("modern-party-summary-egg", "Modern Party egg summary")

  clear()
  local naming = Screens.push(game, "Gen2NamingScreen", {
    type = "nickname", prompt = "NICKNAME?", monName = "TYPHLOSION",
    maxLength = 10, initial = "TYPH", onDone = function() end,
  })
  naming.row, naming.col = 2, 4
  naming.update = function() end
  check(naming.modernPartyNaming and naming.modernPartyGeneration == 2,
    "Modern Party owns the native Gen2NamingScreen screen")
  capture("modern-party-naming", "Modern Party naming screen")
  check(naming.modernPartyLastWideWidth == expectedLogicalWidth,
    ("Modern Naming uses a %dx144 logical layout"):format(expectedLogicalWidth))

  -- Modern PC UI: the actual fourteen-box Gen 2 storage controller.
  game.save.boxes = {}
  game.save.boxNames = { [1] = "JOHTO TEAM" }
  game.save.currentBox = 1
  local box = Boxes.box(game.save, 1)
  for _, spec in ipairs({
    { "CHIKORITA", 16 }, { "CYNDAQUIL", 16 }, { "TOTODILE", 16 },
    { "MAREEP", 14 }, { "TOGEPI", 10 },
  }) do
    box[#box + 1] = assert(Mon.new(game.data, spec[1], spec[2]))
  end
  clear()
  local pc = Screens.push(game, "Gen2BoxMenu", {
    save = game.save, mode = "move",
  })
  pc.index = 2
  pc.update = function() end
  check(pc.modernPCGeneration == 2,
    "Modern PC owns the native fourteen-box screen")
  capture("modern-pc", "Modern PC storage list")
  check(pc.modernPCLastWideWidth == expectedLogicalWidth,
    ("Modern PC uses a %dx144 logical layout"):format(expectedLogicalWidth))
  pc.phase = "submenu"
  pc.submenuIndex = 2
  capture("modern-pc-actions", "Modern PC action menu")
  pc:beginMove()
  capture("modern-pc-insert", "Modern PC move destination")
  pc.phase = nil
  pc.message = "Saving... Leave ON!"
  capture("modern-pc-message", "Modern PC status message")
  pc.message = nil

  -- Modern Pokedex UI: scroll to #152 so the screenshot itself proves the
  -- list is the 251-species Johto dex rather than a Gen 1 fallback.
  for _, species in ipairs({
    "CHIKORITA", "BAYLEEF", "MEGANIUM", "CYNDAQUIL", "QUILAVA",
    "TYPHLOSION", "TOTODILE", "CROCONAW", "FERALIGATR", "SENTRET",
  }) do
    game.save.pokedex.seen[species] = true
  end
  for _, species in ipairs({ "CHIKORITA", "CYNDAQUIL", "TOTODILE" }) do
    game.save.pokedex.caught[species] = true
  end
  game.save.lastDexMode = "OLD"
  clear()
  local dex = Screens.push(game, "Gen2PokedexMenu", { save = game.save })
  dex.modeIndex = 2
  dex:rebuild()
  dex.index = 152
  dex:ensureVisible()
  dex.update = function() end
  check(dex.modernPokedexGeneration == 2,
    "Modern Pokedex owns the native Gen2PokedexMenu screen")
  check(dex.modernDexCount == 251 and #dex.rows == 251,
    "Modern Pokedex renders all 251 native species")
  capture("modern-pokedex", "Modern Pokedex species list")
  check(dex.modernPokedexLastWideWidth == expectedLogicalWidth,
    ("Modern Pokedex uses a %dx144 logical layout"):format(expectedLogicalWidth))
  dex.view = "entry"
  dex.page = 1
  dex.entryAction = 1
  capture("modern-pokedex-entry", "Modern Pokedex data page one")
  dex.page = 2
  capture("modern-pokedex-entry-page-two", "Modern Pokedex data page two")
  dex.view = "area"
  dex.areaRegion = "johto"
  dex.areaBlink = 0
  capture("modern-pokedex-area", "Modern Pokedex area screen")
  game.save.engineFlags = game.save.engineFlags or {}
  game.save.engineFlags[Unown.ENGINE_UNOWN_DEX] = true
  dex.view = "option"
  dex.optionIndex = 4
  capture("modern-pokedex-options", "Modern Pokedex options screen")
  dex.view = "search"
  dex.searchIndex = 2
  dex.searchType = { 10, 0 }
  capture("modern-pokedex-search", "Modern Pokedex search screen")
  game.save.unownDex = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }
  dex.view = "unown"
  dex.unownIndex = 5
  capture("modern-pokedex-unown", "Modern Pokedex Unown screen")

  -- Modern Start Menu: the presence of PACK and POKEGEAR is a visual Gen 2
  -- signature, while selection still calls the native choose/close methods.
  game.save.engineFlags = game.save.engineFlags or {}
  game.save.engineFlags[4] = true
  game.save.engineFlags[11] = true
  check(type(game.save.playTime) == "table",
    "native Gen 2 play time retains its split clock shape")
  game.save.playTime = { hours = 12, minutes = 34, seconds = 56, frames = 0 }
  setOption("modern_start_menu_ui", "theme", "blue")
  clear()
  local backdrop = {
    isOpaque = true,
    drawsWidescreen = function() return true end,
    drawWidescreen = function(_, winW, winH)
      local scale = math.max(1, math.floor(math.min(winH / 144, winW / 160)))
      local cell = 8 * scale
      love.graphics.setColor(0.78, 0.86, 0.90, 1)
      love.graphics.rectangle("fill", 0, 0, winW, winH)
      love.graphics.setColor(0.66, 0.76, 0.82, 1)
      for y = 0, winH - 1, cell do
        local row = math.floor(y / cell)
        for x = (row % 2) * cell, winW - 1, cell * 2 do
          love.graphics.rectangle("fill", x, y, cell, cell)
        end
      end
    end,
    draw = function()
      Chrome.clear()
      love.graphics.setColor(0.78, 0.86, 0.90, 1)
      love.graphics.rectangle("fill", 0, 0, 160, 144)
      love.graphics.setColor(0.66, 0.76, 0.82, 1)
      for y = 0, 136, 8 do
        for x = (y / 8 % 2) * 8, 152, 16 do
          love.graphics.rectangle("fill", x, y, 8, 8)
        end
      end
      -- This is proof scenery, not a cartridge text box: draw only the ink so
      -- the checkerboard remains visible through and around every glyph.
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw("JOHTO", 16, 24)
      Font.draw("GEN 2", 16, 40)
    end,
  }
  game.stack:push(backdrop)
  local start = Screens.push(game, "Gen2StartMenu", {
    save = game.save,
    unlocked = { pokedex = true, party = true, pack = true,
      pokegear = true, mods = true },
    onChoose = function() end,
    onClose = function() end,
  })
  start.update = function() end
  check(start.modernStartMenuUI and start.modernStartGen2,
    "phone presentation decorates the native Gen2StartMenu controller")
  check(#start.items >= 8, "native Gen 2 START actions remain available")
  local pokegearItem
  for _, item in ipairs(start.items) do
    if item.value == "pokegear" then pokegearItem = item break end
  end
  local startPresentation = exports.modern_start_menu_ui.presentation
  check(pokegearItem ~= nil
      and startPresentation.iconFor(pokegearItem, game) == "pokegear"
      and startPresentation.tileLabelFor(pokegearItem, "pokegear") == "GEAR",
    "Gen 2 POKéGEAR keeps its action and honest GEAR caption")
  capture("modern-start-menu", "Modern Start Menu phone")
  check(start.modernStartLastWideWidth == expectedLogicalWidth,
    ("Modern Start Menu uses a %dx144 logical layout"):format(
      expectedLogicalWidth))
  start.phase = "confirm"
  start.confirmChoice = 2
  capture("modern-start-confirm", "Modern Start Menu quit confirmation")
  start.phase = nil

  -- Battle Info HUD + Typed Move Colors use one real native Gen 2 battle.
  local player = assert(Mon.new(game.data, "TYPHLOSION", 48))
  player.moves = {
    { id = "FLAMETHROWER", pp = 12, maxPp = 15 },
    { id = "THUNDERPUNCH", pp = 14, maxPp = 15 },
    { id = "EARTHQUAKE", pp = 10, maxPp = 10 },
    { id = "SWIFT", pp = 18, maxPp = 20 },
  }
  player.status = "paralyze"
  local enemy = assert(Mon.new(game.data, "PIDGEOT", 45))
  enemy.status = "poison"
  game.save.party = { player }
  game.save.pokedex.seen.PIDGEOT = true
  game.save.pokedex.caught.PIDGEOT = true
  local battle = Battle.new({ data = game.data, save = game.save,
    party = game.save.party, wild = enemy, random = function() return 0 end })

  clear()
  local battleScreen = Screens.push(game, "Gen2BattleState", {
    save = game.save, battle = battle, onDone = function() end,
  })
  battleScreen.slideFrame = BattleAnimView.SLIDE_FRAMES
  battleScreen.showPlayerTrainer = false
  battleScreen.showEnemyTrainer = false
  battleScreen.showEnemyHud = true
  battleScreen.showPlayerHud = true
  battleScreen.ballRows = {}
  battleScreen.queue = {}
  battleScreen.message = "What will PIDGEOT do?"
  battleScreen.messageTimer = 0
  battleScreen.phase = "menu"
  battleScreen.menuIndex = 1
  battleScreen.anim = nil
  battleScreen.update = function() end
  capture("battle-info-hud", "Battle Info HUD")
  check(battleScreen.modernBattleLastWideWidth == expectedLogicalWidth,
    ("Battle Info HUD uses a %dx144 logical layout"):format(
      expectedLogicalWidth))
  check(battleScreen.battleInfoHudGen2 == true,
    "Battle Info HUD rendered through the Gen 2 battle overlay")
  if expectedLogicalWidth > 160 then
    check(battleScreen.modernBattleKeptIntact == true,
      "Battle Info HUD never splits the native battle scene")
    check(battleScreen.modernBattleContinuousPanel == true,
      "Battle Info HUD wide command area is one continuous panel")
    check((battleScreen.modernBattlePromptLines or 0) >= 1
        and battleScreen.modernBattlePromptLines <= 2,
      "Battle Info HUD wide prompt stays within its two-line region")
  end

  -- GAME is a persisted Gen 1 preference but Gen 2 still presents the same
  -- visible two-column cards.  This is the setting combination from the
  -- reported two-move failure and must navigate horizontally.
  setOption("typed_move_colors", "layout", "game")
  setOption("typed_move_colors", "battle_colors", true)
  setOption("typed_move_colors", "effect_hints", true)
  setOption("typed_move_colors", "strength", "bold")
  battleScreen.phase = "moves"
  do
    -- Simulate a Silver controller replacing the push-time wrapper.  Drawing
    -- the live cards must reattach navigation through battle.overlay.
    battleScreen.update = function(self)
      local input = self.game and self.game.input
      local moves = self:playerMoves()
      if input:wasPressed("up") then
        self.moveIndex = self.moveIndex > 1 and self.moveIndex - 1 or #moves
      elseif input:wasPressed("down") then
        self.moveIndex = self.moveIndex < #moves and self.moveIndex + 1 or 1
      end
    end
    battleScreen:drawScene()
    -- Simulate the released Silver controller that predates the public grid
    -- hook.  The mod's compatibility adapter must still own all four arrows.
    battleScreen.moveGridNavigation = function() return false end
    local moves = battleScreen:playerMoves()
    local move3, move4 = moves[3], moves[4]
    moves[3], moves[4] = nil, nil
    battleScreen.moveIndex = 1
    U.tap(game, "right")
    check(battleScreen.moveIndex == 2,
      "Typed Move Colors RIGHT switches two first-row moves in GAME layout")
    U.tap(game, "down")
    check(battleScreen.moveIndex == 2,
      "Typed Move Colors DOWN stays on the only populated two-move row")
    capture("typed-move-colors-two-moves",
      "Typed Move Colors two-move first row")
    check(battleScreen.typedMoveColorsInfoPanel == true,
      "Typed Move Colors keeps the selected-move information panel")
    check(battleScreen.typedMoveColorsInfoMode
        == (expectedLogicalWidth > 160 and "full" or "compact"),
      "Typed Move Colors uses the aspect-appropriate information panel")
    check(battleScreen.typedMoveColorsInfoPower == "75"
        and battleScreen.typedMoveColorsInfoPP == "14/15",
      "Typed Move Colors shows selected Power and PP without repeated type")
    local markers = battleScreen.typedMoveColorsEffectMarkers or {}
    check(markers[1] == "up" and markers[2] == "double_up",
      "Typed Move Colors marks neutral and super-effective Gen 2 moves")
    moves[3], moves[4] = move3, move4
    setOption("typed_move_colors", "layout", "wide")
    battleScreen.moveIndex = 1
    U.tap(game, "right")
    check(battleScreen.moveIndex == 2,
      "Typed Move Colors RIGHT crosses the wide battle grid")
    U.tap(game, "down")
    check(battleScreen.moveIndex == 4,
      "Typed Move Colors DOWN crosses the wide battle grid")
    battleScreen.phase = "moveSelect"
    battleScreen.moveIndex = 1
    U.tap(game, "right")
    check(battleScreen.moveIndex == 2,
      "Typed Move Colors RIGHT works on the earlier Silver move phase")
    battleScreen.phase = "moves"
    battleScreen.update = function() end
  end
  battleScreen.moveIndex = 2
  capture("typed-move-colors", "Typed Move Colors battle grid")
  check(battleScreen.typedMoveColorsGen2 == true,
    "Typed Move Colors rendered its Gen 2 move grid")

  clear()
  local typedSummary = Screens.push(game, "Gen2SummaryMenu", {
    save = game.save, party = game.save.party, index = 1,
    page = SummaryMenu.GREEN_PAGE, moveScreen = true,
  })
  typedSummary.moveIndex = 2
  typedSummary.update = function() end
  capture("typed-summary-colors", "Typed Move Colors summary list")
  check(typedSummary.typedMoveColorsGeneration == 2,
    "Typed Move Colors rendered through the Gen 2 summary screen")

  local expectedShots = 33
  check(shotIndex == expectedShots,
    ("all %d visual states completed for %s"):format(
      expectedShots, editionLabel))
  U.log("PASS all seven mods completed native " .. editionLabel
    .. " visual integration proof (" .. shotIndex .. " screenshots)")
end
