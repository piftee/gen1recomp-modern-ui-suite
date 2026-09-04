-- Standalone: luajit mods/modern_ui_suite/tests/modern_ui_suite_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Bag = require("src.inventory.Bag")
local Runtime = require("src.mods.Runtime")

local run = T.sdk.loadMod("mods/modern_ui_suite", {
  data = T.fixtures.fresh(), dev = true,
})
T.eq(#run.errors, 0,
  "the complete suite loads clean (" .. tostring(run.errors[1]) .. ")")
T.eq(run.mod and run.mod.manifest.id, "modern_ui_suite",
  "the package has one canonical mod identity")

local componentIds = {
  "modern_start_menu_ui",
  "modern_party_ui",
  "modern_bag_ui",
  "modern_pc_ui",
  "modern_pokedex_ui",
  "battle_info_hud",
  "typed_move_colors",
}
local componentKeys = {
  "start_menu", "party", "bag", "pc", "pokedex", "battle_hud",
  "move_colors",
}
local expectedVersions = {
  modern_start_menu_ui = "0.1.18",
  modern_party_ui = "0.4.9",
  modern_bag_ui = "0.5.0",
  modern_pc_ui = "0.4.4",
  modern_pokedex_ui = "0.2.10",
  battle_info_hud = "0.9.2",
  typed_move_colors = "0.4.10",
}

local exports = run.loader.exports.modern_ui_suite
T.check(type(exports) == "table", "the suite publishes a public API")
T.eq(exports.apiVersion, 1, "the component API is versioned")
for _, id in ipairs(componentIds) do
  local component = exports.components and exports.components[id]
  T.check(type(component) == "table", id .. " is exported by the suite")
  T.eq(component and component.version, expectedVersions[id],
    id .. " reports its imported snapshot version")
  T.check(type(component and component.exports) == "table",
    id .. " retains its component-specific exports")
  T.eq(type(component and component.enabled), "function",
    id .. " exposes its live enabled state")
  T.eq(exports.isEnabled(id), true, id .. " is enabled by default")
end
T.eq(exports.isEnabled("not_a_component"), false,
  "unknown component ids are rejected by the public toggle query")

local schema = run.loader.optionSchemas.modern_ui_suite or {}
T.eq(#schema, 31,
  "seven master toggles and all 24 detailed preferences share one schema")
local schemaByKey = {}
for _, row in ipairs(schema) do
  schemaByKey[row.key] = row
  T.check(#tostring(row.label or "") <= 16,
    row.key .. " has a 160x144-safe manager label: " .. tostring(row.label))
end
for _, key in ipairs(componentKeys) do
  local row = schemaByKey[key .. ".enabled"]
  T.check(type(row) == "table", key .. " has a namespaced master toggle")
  T.eq(row and row.default, true, key .. " is on by default")
end
T.eq(schemaByKey["battle_hud.enabled"].label, "HUD ENABLED",
  "Battle HUD's former enabled option is one concise suite master toggle")
T.eq(schemaByKey["move_colors.opacity"].label, "MOVE OPACITY",
  "flat manager labels keep their component context without overflowing")
T.eq(run.loader.optionSchemas.modern_party_ui, nil,
  "embedded components do not leak standalone option schemas")

local stack = { states = {} }
function stack:push(state) self.states[#self.states + 1] = state end
function stack:pop() return table.remove(self.states) end
function stack:top() return self.states[#self.states] end

local input = { pressed = {} }
function input:wasPressed(key) return self.pressed[key] == true end
function input:isDown() return false end

local writes = 0
local game = {
  data = run.data,
  save = {
    options = {}, inventory = {}, bagOrder = {}, pcItems = {}, money = 0,
    party = {},
    flags = {}, pokedex = { seen = {}, owned = {} },
    player = { name = "RED" },
  },
  mods = run.loader,
  stack = stack,
  input = input,
  writeOptions = function() writes = writes + 1 return true end,
}

-- The engine normally treats an unmarked menu above the overworld as a
-- transparent overlay for per-category GAME SPEED. Every suite-owned menu
-- must instead use MENU SPEED, including child prompts whose own state is
-- unmarked. A newer gameplay boundary above an old menu must still win.
local speedOptions = {
  speedOverworld = 100,
  speedBattle = 20,
  speedMenu = 2,
}
local function resolvedSpeed(states, options)
  local speedGame = {
    save = { options = options or speedOptions },
    stack = { states = states },
  }
  return Runtime.call("core.logic_speed", function()
    return speedGame.save.options.speedOverworld or 4
  end, speedGame)
end

local suiteMenuMarkers = {
  "modernStartMenuUI", "modernBagUI", "modernPCUI",
  "modernPartyUI", "modernPartySummary", "modernPartyNaming",
  "modernPokedexUI", "modernPokedexEntry", "modernDexSearchOpen",
}
for _, marker in ipairs(suiteMenuMarkers) do
  T.eq(resolvedSpeed({ { isOverworld = true }, { [marker] = true } }), 2,
    marker .. " uses MENU SPEED over a fast overworld")
end
T.eq(resolvedSpeed({
  { isOverworld = true }, { modernPokedexUI = true }, {},
}), 2, "an unmarked child prompt inherits its suite menu's speed")
T.eq(resolvedSpeed({
  { modernPokedexUI = true }, { isBattle = true },
}), 100, "a newer gameplay boundary ignores a stale suite menu below it")
T.eq(resolvedSpeed({ { isOverworld = true }, {} }), 100,
  "an ordinary unmarked overlay retains the engine's speed resolution")
T.eq(resolvedSpeed({ { modernPokedexUI = true } }, {
  speedOverworld = 4,
}), 4, "older single-speed engines pass through unchanged")

local optionRows = Runtime.call("ui.options.rows",
  function(_, rows) return rows end, game, { { id = "text_speed" } })
T.eq(#optionRows, 2,
  "the normal Options menu receives one consolidated suite entry")
T.eq(optionRows[2] and optionRows[2].id, "modern_ui_suite_settings",
  "the consolidated Options row has a stable id")
T.eq(optionRows[2] and optionRows[2].label, "MODERN UI SUITE",
  "the consolidated Options row names the package")
for _, row in ipairs(optionRows) do
  T.check(not expectedVersions[row.id],
    "standalone component rows are suppressed from the root Options menu")
end

optionRows[2].activate(game)
local hub = stack:top()
T.eq(hub and hub.screenId, "modern_ui_suite:settings",
  "the consolidated row opens the unified settings hub")
T.eq(hub and #hub.items, 10,
  "the hub contains bulk actions, seven components, and Back")
T.eq(hub.items[1].id, "enable_all", "Enable All is the first bulk action")
T.eq(hub.items[2].id, "disable_all", "Disable All UI is the second bulk action")

-- Exercise every player-facing row through the same OptionsMenu:update path
-- used by keyboard and controller input. A complete rightward cycle must
-- visit every advertised value, return to the starting value, update both
-- live and saved buckets, and request durable persistence. Left then proves
-- the reverse/wrap path for that same individual option.
local visitedRows = {}
local expectedPageRows = {
  modern_start_menu_ui = 5, -- enabled + 3 choices + icon picker
  modern_party_ui = 11,
  modern_bag_ui = 2,
  modern_pc_ui = 1,
  modern_pokedex_ui = 4,
  battle_info_hud = 1,
  typed_move_colors = 8,
}
local function pressPage(page, button)
  input.pressed[button] = true
  page:update(0)
  input.pressed[button] = nil
end
for hubIndex = 3, 9 do
  local item = hub.items[hubIndex]
  hub.onChoose(item, hub)
  local page = stack:top()
  local componentId = item.component.id
  T.eq(page.modernUiSuiteComponent, componentId,
    componentId .. " opens its own detailed page")
  T.eq(#page.rows, expectedPageRows[componentId],
    componentId .. " exposes every intended detailed row")
  for rowIndex, row in ipairs(page.rows) do
    T.check(#tostring(row.label or "") <= 16,
      row.id .. " has a 160x144-safe component-page label: "
        .. tostring(row.label))
    local schemaRow = schemaByKey[row.id]
    if schemaRow then
      visitedRows[row.id] = true
      local initialLabel = row.value(page.game)
      local states = schemaRow.type == "toggle" and 2
        or #(schemaRow.choices or {})
      local seen = {}
      page.index = rowIndex
      for _ = 1, states do
        local writesBefore = writes
        pressPage(page, "right")
        local label = row.value(page.game)
        seen[label] = true
        T.check(writes > writesBefore,
          row.id .. " persists after a rightward UI step")
        local saved = game.save.options.modOptions.modern_ui_suite[row.id]
        local live = run.loader.modOptions.modern_ui_suite[row.id]
        T.eq(saved, live, row.id .. " keeps saved and live values synchronized")
      end
      T.eq(row.value(page.game), initialLabel,
        row.id .. " wraps to its starting value after a complete cycle")
      local seenCount = 0
      for _ in pairs(seen) do seenCount = seenCount + 1 end
      T.eq(seenCount, states, row.id .. " exposes every advertised value")
      pressPage(page, "left")
      T.check(row.value(page.game) ~= initialLabel,
        row.id .. " supports the reverse/wrap direction")
      pressPage(page, "right")
      T.eq(row.value(page.game), initialLabel,
        row.id .. " reverses cleanly back to its starting value")
    elseif row.id == "start_menu.icon_overrides" then
      row.activate(game)
      local icons = stack:top()
      T.eq(icons.screenId, "modern_start_menu_ui:settings",
        "the vanilla icon-overrides row opens its dedicated screen")
      T.eq(icons.items[1].label, "NO MOD ENTRIES",
        "the vanilla icon screen explains that no custom actions exist")
      T.eq(icons.items[#icons.items].label, "BACK",
        "the empty vanilla icon screen always has an exit")
      stack:pop()
    else
      T.check(false, "unexpected suite settings row: " .. tostring(row.id))
    end
  end
  stack:pop()
end
for _, row in ipairs(schema) do
  T.check(visitedRows[row.key] == true,
    row.key .. " is reachable from a component page")
end

hub.index = 3
input.pressed.right = true
hub:update(0)
input.pressed.right = nil
T.eq(exports.isEnabled("modern_start_menu_ui"), false,
  "Left or Right changes a component live from the hub")
T.eq(game.save.options.modOptions.modern_ui_suite["start_menu.enabled"], false,
  "a hub toggle is persisted in the suite namespace")
T.eq(game.save.options.modOptions.modern_start_menu_ui, nil,
  "a hub toggle does not recreate the legacy namespace")

hub.onChoose(hub.items[4], hub)
local partyPage = stack:top()
T.eq(partyPage and partyPage.modernUiSuiteComponent, "modern_party_ui",
  "A opens the selected component's detailed page")
T.eq(partyPage and #partyPage.rows, 11,
  "the Party page has one master switch plus all ten Party preferences")
T.eq(partyPage.rows[1].id, "party.enabled",
  "every detail page starts with its component master switch")
partyPage.rows[1].step(game, 1)
T.eq(exports.isEnabled("modern_party_ui"), false,
  "the detail page master switch uses the same live state")
partyPage.rows[2].step(game, 1)
T.eq(run.loader.modOptions.modern_ui_suite["party.card_color"],
  "species_palette", "detail preferences write to namespaced suite keys")

stack:pop()
hub = stack:top()
hub.onChoose(hub.items[1], hub)
for _, id in ipairs(componentIds) do
  T.eq(exports.isEnabled(id), true, "Enable All turns on " .. id)
end
T.check(writes >= 1, "bulk actions request durable option persistence")
hub.onChoose(hub.items[2], hub)
for _, id in ipairs(componentIds) do
  T.eq(exports.isEnabled(id), false, "Disable All UI turns off " .. id)
end
T.eq(run.loader.modOptions.modern_ui_suite["party.card_color"],
  "species_palette", "bulk disabling preserves detailed preferences")

-- Compatibility arbitration is not itself a custom presentation. With every
-- suite screen switched off, Gender Mod must still be the sole gender owner
-- when Crystal 251 and a staged voxel renderer are present. This is the exact
-- configuration that used to leave coloured glyphs floating beside a second
-- black marker (and during the caught-mon transfer message).
local genderHud = {
  classicGenderXY = function(side)
    return side == "enemy" and 24 or 104, side == "enemy" and 8 or 64
  end,
  enemyHudVisible = function(battle) return battle and battle.enemy ~= nil end,
  playerHudVisible = function(battle) return battle and battle.player ~= nil end,
}
local crystalTrackingCalls = 0
local crystalGender = {
  forMon = function() return nil end,
  withBattleHudTracking = function(_, draw, ...)
    crystalTrackingCalls = crystalTrackingCalls + 1
    return draw(...)
  end,
}
run.loader.exports.gender_mod = { BattleHUD = genderHud, ratios = {} }
run.loader.exports.CRYSTAL_251 = { crystalGender = crystalGender }
Runtime.emit("game.ready", { game = game })
T.eq(crystalGender.withBattleHudTracking({ game = game },
    function() return "one marker" end), "one marker",
  "disabled Battle HUD still preserves the selected Gender Mod provider")
T.eq(crystalTrackingCalls, 0,
  "disabled Battle HUD does not restore Crystal 251's duplicate marker")
run.loader.modOptions.modern_ui_suite["battle_hud.enabled"] = true
T.eq(crystalGender.withBattleHudTracking({ game = game },
    function() return "one marker" end), "one marker",
  "enabled Battle HUD also preserves the selected Gender Mod provider")
T.eq(crystalTrackingCalls, 0,
  "enabled Battle HUD does not overlap Crystal 251's duplicate marker")
run.loader.modOptions.modern_ui_suite["battle_hud.enabled"] = false
T.eq(genderHud.enemyHudVisible({ enemy = {}, result = "caught" }), false,
  "caught-mon transfer frames suppress the stray opponent gender glyph")
T.eq(genderHud.playerHudVisible({ player = {}, blankForAskName = true }), false,
  "caught-mon nickname frames suppress the stray player gender glyph")
T.eq(genderHud.playerHudVisible({ player = {} }), true,
  "ordinary disabled-suite battles retain Gender Mod's native marker")
T.same({ genderHud.classicGenderXY("player") }, { 104, 64 },
  "disabled Battle HUD leaves Gender Mod's native coordinate unchanged")

-- Typed Move Colors has process-stable patches on native controller classes.
-- Those patches outlive the suite's hook gate, so their own presentation
-- predicates must release the native Summary and battle chrome when the
-- component master switch is off.
local BattleState = require("src.battle.BattleState")
local typedTextPatch = rawget(BattleState, "_typedMoveColorsTextPatch")
local typedInputPatch = rawget(BattleState, "_typedMoveColorsInputPatch")
T.eq(type(typedTextPatch and typedTextPatch.owns), "function",
  "Typed Move Colors exposes its native battle-chrome ownership predicate")
T.eq(type(typedInputPatch and typedInputPatch.nativeGamePresentation),
  "function", "Typed Move Colors exposes its GAME-layout predicate")
local nativeTextCalls = 0
local originalTextArea = typedTextPatch and typedTextPatch.original
if typedTextPatch then
  typedTextPatch.original = function()
    nativeTextCalls = nativeTextCalls + 1
    return "native battle chrome"
  end
end
local nativeTextOK, nativeTextResult = pcall(BattleState.drawTextArea, {
  phase = "menu",
})
if typedTextPatch then typedTextPatch.original = originalTextArea end
T.check(nativeTextOK and nativeTextCalls == 1
    and nativeTextResult == "native battle chrome",
  "disabled move colours restore the native battle command area")

local SummaryMenu = require("src.ui.SummaryMenu")
local typedSummaryPatch = rawget(SummaryMenu, "_typedMoveColorsPatch")
T.eq(type(typedSummaryPatch and typedSummaryPatch.renderer), "function",
  "Typed Move Colors exposes its native Summary overlay")
local disabledSummaryTouched = false
local summaryProbe = setmetatable({ page = 2 }, {
  __index = function()
    disabledSummaryTouched = true
    return nil
  end,
})
local disabledSummaryOK = typedSummaryPatch
  and pcall(typedSummaryPatch.renderer, summaryProbe)
T.check(disabledSummaryOK and not disabledSummaryTouched,
  "disabled move colours do not inspect or repaint native Summary rows")

T.eq(Bag.capacity(run.data), 255,
  "expanded Bag capacity remains active while Bag presentation is off")
local expanded = { inventory = {}, bagOrder = {} }
T.check(Bag.add(expanded, "SUITE_TEST_ITEM", 999, run.data),
  "x999 stacks remain save-safe while Bag presentation is off")
T.eq(expanded.inventory.SUITE_TEST_ITEM, 999,
  "the expanded stack uses the existing save shape")

local records = {
  BagMenu = "modern_bag_ui",
  PartyMenu = "modern_party_ui",
  BoxMenu = "modern_pc_ui",
  PokedexMenu = "modern_pokedex_ui",
}
for screenId, componentId in pairs(records) do
  local record = run.data.screens and run.data.screens[screenId]
  T.eq(record and record.__modernUiSuiteComponent, componentId,
    screenId .. " records which suite component owns its presentation")
  T.eq(type(record and record.__modernUiSuiteEnabled), "function",
    screenId .. " exposes its dynamic gate for regression tests")
end

local smokeMarkers = {
  BagMenu = "modernBagUI",
  PartyMenu = "modernPartyUI",
  BoxMenu = "modernPCUI",
  PokedexMenu = "modernPokedexUI",
}
local suiteOptions = run.loader.modOptions.modern_ui_suite
for index = 1, #componentKeys do
  suiteOptions[componentKeys[index] .. ".enabled"] = true
end
for screenId, marker in pairs(smokeMarkers) do
  local ok, screen = pcall(run.data.screens[screenId].new, game, {})
  T.check(ok, screenId .. " constructs inside the all-in-one load: "
    .. tostring(screen))
  T.eq(ok and screen[marker], true,
    screenId .. " keeps its imported modern presentation marker")
end

local StartMenu = require("src.ui.StartMenu")
local modernStart = StartMenu.new(game)
T.eq(modernStart.modernStartMenuUI, true,
  "the enabled Start presentation hook decorates a newly built controller")

-- Phosphor's optional iOS controls hide the engine-owned touch overlay and
-- present themselves as a joystick. Current sandboxed mods cannot inspect
-- love.system, so reproduce that denied module here and prove the portrait
-- overlay still selects the native surface without touching it.
local startPresentation = exports.components.modern_start_menu_ui.exports.presentation
local savedSystem, savedJoystick = love.system, love.joystick
local savedPixelDimensions = love.graphics.getPixelDimensions
love.system = setmetatable({}, { __index = function(_, key)
  error("love.system is not available to mods: " .. tostring(key), 2)
end })
love.joystick = { getJoysticks = function() return { {} } end }
love.graphics.getPixelDimensions = function() return 390, 844 end
local phosphorOK, phosphorWidth, phosphorHeight = pcall(
  startPresentation.responsiveSize, modernStart)
love.system, love.joystick = savedSystem, savedJoystick
love.graphics.getPixelDimensions = savedPixelDimensions
T.check(phosphorOK,
  "Phosphor's controller overlay never reads sandboxed love.system")
T.same({ phosphorWidth, phosphorHeight }, { 160, 144 },
  "Phosphor's portrait overlay keeps the native START surface")

local positionKeys = { "left", "mid_left", "center", "mid_right", "right" }
local compactPositionXs = {}
for index, position in ipairs(positionKeys) do
  suiteOptions["start_menu.position"] = position
  compactPositionXs[index] = startPresentation.layoutFor(modernStart).panelX
end
T.same(compactPositionXs, { 0, 16, 28, 40, 56 },
  "all five compact START positions retain visibly distinct docks")
T.eq(compactPositionXs[1], 0,
  "LEFT reaches the true logical screen edge")
T.eq(compactPositionXs[5] + startPresentation.PANEL_W, 160,
  "RIGHT reaches the opposite logical screen edge")
suiteOptions["start_menu.position"] = "right"

-- Party uses a tall portrait surface on phones. A Summary pushed above it
-- must inherit that exact canvas so backing out cannot release and recreate
-- the render target with a visible white allocation clear.
do
  local oldPixelDimensions = love.graphics.getPixelDimensions
  love.graphics.getPixelDimensions = function() return 390, 844 end
  local mon = {
    species = "FIXMON_A", nickname = "LEAF", level = 12, exp = 1728,
    hp = 35,
    stats = { hp = 35, attack = 20, defense = 18, speed = 16, special = 22 },
    moves = {},
  }
  game.save.party = { mon }
  stack.states = {}
  local party = run.data.screens.PartyMenu.new(game, {})
  stack:push(party)
  local partyW, partyH = party:uiSize()
  local summary = run.data.screens.SummaryMenu.new(game, mon)
  stack:push(summary)
  local summaryW, summaryH = summary:uiSize()
  T.same({ summaryW, summaryH }, { partyW, partyH },
    "portrait Summary inherits the active Party render surface")
  T.eq(summary.modernSummaryParentSurface, "modern_party_ui",
    "Summary identifies its parent surface for transition diagnostics")
  game.renderer = { uiSize = function() return summaryW, summaryH end }
  local summaryLayout = summary:modernSummaryLayoutInfo()
  T.eq(summaryLayout.height, partyH,
    "portrait Summary fills the inherited Party canvas")
  T.eq(summaryLayout.footerY, partyH - 8,
    "portrait Summary keeps its footer at the inherited canvas bottom")
  local summaryZones = summary:sgbPalettes(game) or {}
  T.eq(summaryZones[1] and summaryZones[1].h, partyH,
    "portrait Summary palette covers the inherited Party canvas")
  local summaryDrawOK, summaryDrawError = pcall(summary.draw, summary)
  T.check(summaryDrawOK,
    "portrait Summary draws across the inherited Party canvas: "
      .. tostring(summaryDrawError))
  summary.page = 2
  input.pressed.b = true
  summary:update(0)
  input.pressed.b = nil
  T.eq(stack:top(), party,
    "backing out of Summary returns directly to the existing Party screen")
  T.same({ party:uiSize() }, { summaryW, summaryH },
    "the Summary-to-Party return keeps one continuous render surface")
  stack.states = {}
  game.save.party = {}
  game.renderer = nil
  love.graphics.getPixelDimensions = oldPixelDimensions
end

suiteOptions["start_menu.enabled"] = false
local nativeStart = StartMenu.new(game)
T.check(nativeStart.modernStartMenuUI ~= true,
  "disabling a hook component takes effect on its next invocation")
T.eq(modernStart.modernStartMenuUI, true,
  "a hook toggle does not mutate an already-presented controller")
suiteOptions["start_menu.enabled"] = true

-- Exhaust every combination once. One assertion covers all seven public
-- states and every replacement-screen gate for that combination.
for mask = 0, 127 do
  local matches = true
  for index, id in ipairs(componentIds) do
    local enabled = math.floor(mask / (2 ^ (index - 1))) % 2 == 1
    suiteOptions[componentKeys[index] .. ".enabled"] = enabled
    matches = matches and exports.isEnabled(id) == enabled
  end
  for screenId, componentId in pairs(records) do
    local record = run.data.screens[screenId]
    matches = matches
      and record.__modernUiSuiteEnabled() == exports.isEnabled(componentId)
  end
  T.check(matches, ("toggle combination %03d/127 is independent"):format(mask))
end

-- GAME means the game's own move-selection geometry with a colour pass, not
-- a second half-width card layout. Keep the native TYPE/PP and move boxes so
-- stock twelve-glyph names remain at their integer pixel size.
suiteOptions["move_colors.layout"] = "game"
local gameLayoutBattle = {
  phase = "moveSelect", game = game, moveIndex = 1,
  player = { curMoves = { { id = "TACKLE", pp = 35 } } },
}
T.eq(typedInputPatch.nativeGamePresentation(gameLayoutBattle), true,
  "GAME selects the faithful native-list colour overlay")
T.eq(typedInputPatch.replacementPresentationOwnsPhase(gameLayoutBattle), false,
  "GAME no longer suppresses the native TYPE/PP and move-list boxes")
local gameRow = typedInputPatch.nativeGameRowGeometry(1)
T.eq(gameRow.x, 40, "GAME colour begins inside the native move-list border")
T.eq(gameRow.y, 104, "GAME first colour row matches the native first move")
T.eq(gameRow.w, 112, "GAME uses the complete native move-list interior")
T.eq(gameRow.textX, 48, "GAME keeps the native move-name origin")
T.check(gameRow.textWidth >= 96,
  "GAME preserves room for a twelve-glyph stock move at 1x")

-- Localization mods can move the whole move-list row left to make room for
-- longer translated labels. Colour those glyphs while the native renderer is
-- drawing them so no uncovered prefix or second cursor survives at the old
-- position (the reported ARRANHAO/ROSNA DURA doubling regression).
local shiftedRow = typedInputPatch.nativeGameRowGeometry(1, 16)
T.eq(shiftedRow.x, 8,
  "GAME colour follows a localization's shifted cursor column")
T.eq(shiftedRow.textX, 16,
  "GAME ink follows a localization's shifted move-name column")
T.eq(shiftedRow.w, 144,
  "a shifted GAME row still reaches the native right edge")

local Font = require("src.render.Font")
local PaletteFX = require("src.render.PaletteFX")
local realFontDraw, realFontDrawCode = Font.draw, Font.drawCode
local realRectangle = love.graphics.rectangle
local realMarkTrueColor = PaletteFX.markTrueColor
local shiftedDraws, shiftedCodes, shiftedFills, shiftedMarks = {}, {}, {}, {}
Font.draw = function(value, x, y)
  shiftedDraws[#shiftedDraws + 1] = { value = value, x = x, y = y }
end
Font.drawCode = function(code, x, y)
  shiftedCodes[#shiftedCodes + 1] = { code = code, x = x, y = y }
end
love.graphics.rectangle = function(mode, x, y, w, h)
  if mode == "fill" then
    shiftedFills[#shiftedFills + 1] = { x = x, y = y, w = w, h = h }
  end
  return realRectangle(mode, x, y, w, h)
end
PaletteFX.markTrueColor = function(x, y, w, h)
  shiftedMarks[#shiftedMarks + 1] = { x = x, y = y, w = w, h = h }
end

run.data.moves.TRANSLATED_LONG = {
  id = "TRANSLATED_LONG", name = "MARTELOSDEIS", type = "FIGHTING",
  power = 100, pp = 10,
}
local shiftedBattle = {
  phase = "moveSelect", game = game, moveIndex = 1,
  player = { curMoves = { { id = "TRANSLATED_LONG", pp = 10 } } },
}
originalTextArea = typedTextPatch.original
typedTextPatch.original = function()
  Font.draw("MARTELOSDEIS", 16, 104)
  Font.drawCode(0xED, 8, 104)
  return "shifted native GAME layout"
end
local shiftedTextOK, shiftedTextResult = pcall(BattleState.drawTextArea,
  shiftedBattle)
typedTextPatch.original = originalTextArea
Font.draw, Font.drawCode = realFontDraw, realFontDrawCode
love.graphics.rectangle = realRectangle
PaletteFX.markTrueColor = realMarkTrueColor
T.check(shiftedTextOK and shiftedTextResult == "shifted native GAME layout",
  "GAME colours a shifted localization row without replacing its renderer")
T.same(shiftedFills[1], { x = 8, y = 104, w = 144, h = 8 },
  "the shifted row fill covers the original long-name prefix")
T.same(shiftedMarks[1], { x = 8, y = 104, w = 144, h = 8 },
  "the complete shifted row remains protected as true colour")
T.eq(#shiftedDraws, 1,
  "the translated move name is drawn once rather than duplicated")
T.same(shiftedDraws[1], { value = "MARTELOSDEIS", x = 16, y = 104 },
  "the single coloured name retains the localization's coordinates")
T.same(shiftedCodes[1], { code = 0xED, x = 8, y = 104 },
  "the single coloured cursor retains the localization's coordinates")

nativeTextCalls = 0
originalTextArea = typedTextPatch.original
typedTextPatch.original = function()
  nativeTextCalls = nativeTextCalls + 1
  return "native GAME layout"
end
nativeTextOK, nativeTextResult = pcall(BattleState.drawTextArea,
  gameLayoutBattle)
typedTextPatch.original = originalTextArea
T.check(nativeTextOK and nativeTextCalls == 1
    and nativeTextResult == "native GAME layout",
  "enabled GAME colours still draw the native battle menu first")
suiteOptions["move_colors.layout"] = "wide"

suiteOptions["bag.enabled"] = true
local openModern = run.data.screens.BagMenu.new(game, {})
T.eq(openModern.modernBagUI, true,
  "an enabled screen component opens its modern presentation")

-- START opens a compact sort overlay. Category order follows the visible
-- pockets and is stable within each one; name order uses the displayed item
-- names. All four choices update only bagOrder and retain the selected item.
local sortDefs = {
  SORT_KEY = { name = "EMBER MAP", bagPocket = "key" },
  SORT_ZINC = { name = "ZINC TOOL", bagPocket = "items" },
  SORT_MED = { name = "APPLE MED", bagPocket = "medicine" },
  SORT_BERRY = { name = "BERRY TOOL", bagPocket = "items" },
  SORT_BALL = { name = "CHARM BALL", bagPocket = "balls" },
  SORT_TM = { name = "DELTA TM", bagPocket = "machines" },
}
for id, def in pairs(sortDefs) do run.data.items[id] = def end
local originalSortOrder = {
  "SORT_KEY", "SORT_ZINC", "SORT_MED",
  "SORT_BERRY", "SORT_BALL", "SORT_TM",
}
game.save.inventory = {}
for _, id in ipairs(originalSortOrder) do game.save.inventory[id] = 1 end

local function resetSortBag()
  game.save.bagOrder = {}
  for index, id in ipairs(originalSortOrder) do
    game.save.bagOrder[index] = id
  end
  openModern.index, openModern.scroll = 1, 0
  openModern:modernBagRefresh("SORT_KEY")
end

local function pressState(state, key)
  input.pressed[key] = true
  state:update(0)
  input.pressed[key] = nil
end

local function chooseSort(index)
  resetSortBag()
  pressState(openModern, "start")
  local sorter = stack:top()
  T.check(sorter ~= openModern and sorter.modernBagSortMenu == true,
    "START opens the Bag sorting submenu")
  T.eq(sorter.items[1].label, "CATEGORY ASC",
    "the sorting submenu begins with ascending pocket categories")
  T.eq(sorter.items[4].label, "NAMES Z-A",
    "the sorting submenu exposes descending item names")
  T.check(sorter.__modernBagResponsiveOverlay == true,
    "the sorting submenu stays inside the responsive Bag surface")
  local drawOK, drawErr = pcall(sorter.draw, sorter)
  T.check(drawOK,
    "the sorting submenu draws cleanly: " .. tostring(drawErr))
  for _ = 2, index do pressState(sorter, "down") end
  pressState(sorter, "a")
  T.eq(stack:top(), openModern,
    "choosing a sort order returns directly to the Bag")
end

stack:push(openModern)
chooseSort(1)
T.same(game.save.bagOrder, {
  "SORT_ZINC", "SORT_BERRY", "SORT_MED",
  "SORT_BALL", "SORT_TM", "SORT_KEY",
}, "category ascending follows pocket order and preserves pocket contents")
T.eq(openModern.items[openModern.index].value, "SORT_KEY",
  "sorting keeps the previously selected item highlighted")

chooseSort(2)
T.same(game.save.bagOrder, {
  "SORT_KEY", "SORT_TM", "SORT_BALL",
  "SORT_MED", "SORT_ZINC", "SORT_BERRY",
}, "category descending reverses pocket groups but not their contents")

chooseSort(3)
T.same(game.save.bagOrder, {
  "SORT_MED", "SORT_BERRY", "SORT_BALL",
  "SORT_TM", "SORT_KEY", "SORT_ZINC",
}, "name A-Z uses the item names shown in the Bag")

chooseSort(4)
T.same(game.save.bagOrder, {
  "SORT_ZINC", "SORT_KEY", "SORT_TM",
  "SORT_BALL", "SORT_BERRY", "SORT_MED",
}, "name Z-A reverses the displayed-name order")
stack:pop()

suiteOptions["bag.enabled"] = false
T.eq(openModern.modernBagUI, true,
  "an already-open screen is not rebuilt underneath the player")
local openNative = run.data.screens.BagMenu.new(game, {})
T.check(openNative.modernBagUI ~= true,
  "a disabled screen component uses the native presentation on next open")
suiteOptions["bag.enabled"] = true
T.eq(run.data.screens.BagMenu.new(game, {}).modernBagUI, true,
  "re-enabling restores the modern presentation on next open")

-- Simulate upgrading after the standalone folders have been removed. Suite
-- values win, missing values are copied, and legacy buckets remain untouched.
local legacyIcons = { custom_entry = "star" }
game.save.options.modOptions = {
  modern_ui_suite = { ["party.card_color"] = "blue" },
  modern_party_ui = { card_color = "health", animate_icons = false },
  modern_start_menu_ui = { theme = "red", icons = legacyIcons },
  modern_pokedex_ui = { pattern = "plain" },
  battle_info_hud = { enabled = false },
  typed_move_colors = { strength = "vibrant" },
}
run.loader.modOptions = {
  modern_ui_suite = { ["party.card_color"] = "blue" },
  modern_party_ui = { card_color = "health", animate_icons = false },
  modern_start_menu_ui = { theme = "red", icons = legacyIcons },
  modern_pokedex_ui = { pattern = "plain" },
  battle_info_hud = { enabled = false },
  typed_move_colors = { strength = "vibrant" },
}
local writesBeforeMigration = writes
run.loader.events:emit("game.ready", { game = game })
local migrated = run.loader.modOptions.modern_ui_suite
T.eq(migrated["party.card_color"], "blue",
  "an existing suite value wins over its legacy equivalent")
T.eq(migrated["party.animate_icons"], false,
  "a missing Party preference migrates")
T.eq(migrated["start_menu.theme"], "red",
  "a missing Start preference migrates")
T.eq(migrated["pokedex.pattern"], "plain",
  "a missing Pokedex preference migrates")
T.eq(migrated["battle_hud.enabled"], false,
  "Battle HUD's standalone enabled option migrates to its master switch")
T.eq(migrated["move_colors.strength"], "vibrant",
  "a missing move-colour preference migrates")
T.same(migrated["start_menu.icons"], legacyIcons,
  "Start Menu icon overrides migrate with their contents")
T.neq(migrated["start_menu.icons"], legacyIcons,
  "migrated icon overrides are copied rather than aliased")
T.eq(run.loader.modOptions.modern_start_menu_ui.icons, legacyIcons,
  "the legacy option bucket is not changed during migration")
T.eq(migrated._migration_version, 1,
  "the destination records the migration format")
T.eq(writes, writesBeforeMigration + 1,
  "a changed migration requests one durable options write")
run.loader.events:emit("game.ready", { game = game })
T.eq(writes, writesBeforeMigration + 1,
  "running migration again is idempotent")

run.release()

local compatibility = T.sdk.loadMods({
  "mods/modern_bag_ui/tests/fixtures/useful_bag",
  "mods/modern_ui_suite",
}, { data = T.fixtures.fresh(), dev = true })
T.eq(#compatibility.errors, 0,
  "the all-in-one suite loads beside an optional Bag companion")
T.eq(Bag.capacity(compatibility.data), 999,
  "the companion's larger storage contract is preserved")
local compatibilityStack = { states = {} }
function compatibilityStack:push(state)
  self.states[#self.states + 1] = state
end
function compatibilityStack:pop() return table.remove(self.states) end
function compatibilityStack:top() return self.states[#self.states] end
local compatibilityGame = {
  data = compatibility.data,
  save = {
    options = {}, inventory = {}, bagOrder = {}, money = 0, party = {},
    flags = {}, player = { name = "RED" },
    pokedex = { seen = {}, owned = {} },
  },
  mods = compatibility.loader,
  stack = compatibilityStack,
  input = { wasPressed = function() return false end,
    isDown = function() return false end },
}
local compatibilityRows = Runtime.call("ui.options.rows",
  function(_, rows) return rows end, compatibilityGame, {})
compatibilityRows[1].activate(compatibilityGame)
local compatibilityHub = compatibilityStack:top()
compatibilityHub.onChoose(compatibilityHub.items[5], compatibilityHub)
local bagPage = compatibilityStack:top()
T.eq(bagPage.rows[3] and bagPage.rows[3].id, "bag.companions",
  "the Bag page offers companion settings without another root entry")
bagPage.rows[3].activate(compatibilityGame)
local companionPage = compatibilityStack:top()
T.eq(#(companionPage.rows or {}), 1,
  "the companion page removes the duplicate suite-owned skin setting")
T.eq(companionPage.rows[1] and companionPage.rows[1].id,
  "modern_bag_ui_useful_fullscreen",
  "the useful companion's own preference remains reachable")
compatibility.loader.modOptions.modern_ui_suite = { ["bag.enabled"] = false }
local fallback = compatibility.data.screens.BagMenu.new(compatibilityGame, {})
T.eq(fallback.usefulBagFixtureScreen, true,
  "disabling Modern Bag hands the next open to the downstream companion")
compatibility.release()

-- Gen 3 Inspired UI owns its finished-frame battle dialogue and Pokemon
-- menu surfaces. The suite may tint Gen 3's dedicated move panel, but it
-- must not feed terminal ROM control commands into the dialogue renderer or
-- repaint native-coordinate Summary/MoveLearn rows over the larger screens.
local gen3Compatibility = T.sdk.loadMods({
  "mods/modern_ui_suite/tests/fixtures/gen3_battle_ui",
  "mods/modern_ui_suite",
}, { data = T.fixtures.fresh(), dev = true })
T.eq(#gen3Compatibility.errors, 0,
  "the suite loads beside the Gen 3 UI compatibility fixture")
T.eq(gen3Compatibility.loader.order[1], "gen3_battle_ui",
  "Gen 3 UI establishes its presentation before the suite adapter")

local gen3Stack = { states = {} }
function gen3Stack:top() return self.states[#self.states] end
local gen3Game = {
  data = gen3Compatibility.data,
  save = { options = {}, party = {}, player = { name = "RED" } },
  mods = gen3Compatibility.loader,
  stack = gen3Stack,
}
local gen3Battle = {
  game = gen3Game,
  phase = "messages",
  current = {},
  shown = {},
}
gen3Stack.states = { gen3Battle }

for _, marker in ipairs({ "(PROMPT)", "{PROMPT}", "<PROMPT>" }) do
  local source = "Wild PIDGEY\nappeared!" .. marker
  gen3Battle.current.text = source
  gen3Game.gen3FixtureMessage = nil
  local ok, err = pcall(Runtime.call, "render.hud", function() end,
    gen3Game, { width = 1280, height = 720 })
  T.check(ok, "Gen 3 dialogue compatibility draws: " .. tostring(err))
  T.eq(gen3Game.gen3FixtureMessage, "Wild PIDGEY\nappeared!",
    marker .. " is hidden from Gen 3's player-facing dialogue")
  T.eq(gen3Battle.current.text, source,
    marker .. " remains intact in the engine-owned battle queue")
end
local spacedSource = "Deliberate trailing space  "
gen3Battle.current.text = spacedSource
gen3Game.gen3FixtureMessage = nil
Runtime.call("render.hud", function() end,
  gen3Game, { width = 1280, height = 720 })
T.eq(gen3Game.gen3FixtureMessage, spacedSource,
  "ordinary message whitespace is unchanged when no control marker exists")

local gen3TypedInput = rawget(BattleState, "_typedMoveColorsInputPatch")
gen3Battle.phase = "moveSelect"
gen3Battle.player = { curMoves = {} }
gen3Battle.wideLayout = function() return false end
T.eq(gen3TypedInput.nativeGamePresentation(gen3Battle), false,
  "Gen 3 battle UI bypasses the native GAME-row class interception")

local MoveLearnMenu = require("src.ui.MoveLearnMenu")
local gen3MovePatch = rawget(MoveLearnMenu, "_typedMoveColorsPatch")
local gen3SummaryPatch = rawget(SummaryMenu, "_typedMoveColorsPatch")
local gen3Paints = 0
local realGen3Mark = PaletteFX.markTrueColor
PaletteFX.markTrueColor = function() gen3Paints = gen3Paints + 1 end
local gen3Learner = setmetatable({
  game = gen3Game, selecting = true, index = 1,
  mon = { moves = { { id = "TACKLE", pp = 35 } } },
}, MoveLearnMenu)
gen3Stack.states = { gen3Battle, gen3Learner }
local gen3LearnOK, gen3LearnErr = pcall(gen3MovePatch.renderer, gen3Learner)
T.check(gen3LearnOK,
  "Gen 3 move-learning ownership check: " .. tostring(gen3LearnErr))
T.eq(gen3Paints, 0,
  "the suite does not overlay fixed native rows on Gen 3 move learning")

local gen3Summary = setmetatable({
  game = gen3Game, page = 2,
  mon = { moves = { { id = "TACKLE", pp = 35 } } },
}, SummaryMenu)
gen3Stack.states = { gen3Battle, gen3Summary }
local gen3SummaryOK, gen3SummaryErr =
  pcall(gen3SummaryPatch.renderer, gen3Summary)
PaletteFX.markTrueColor = realGen3Mark
T.check(gen3SummaryOK,
  "Gen 3 Summary ownership check: " .. tostring(gen3SummaryErr))
T.eq(gen3Paints, 0,
  "the suite does not overlay fixed native rows on Gen 3 Summary")
gen3Compatibility.release()

local conflict = T.sdk.loadMods({
  "mods/modern_bag_ui", "mods/modern_ui_suite",
}, { data = T.fixtures.fresh(), dev = true })
T.check(#conflict.errors >= 1,
  "installing a standalone component beside the suite reports a conflict")
T.eq(conflict.mods.modern_ui_suite.state, "conflict",
  "the suite refuses to initialize beside a legacy screen owner")
T.eq(conflict.mods.modern_bag_ui.state, "loaded",
  "the already-installed standalone is left intact for a deliberate migration")
T.eq(conflict.loader.exports.modern_ui_suite, nil,
  "a conflict leaves no partial suite exports")
conflict.release()

local innerFs = T.fs.new(".")
local missingAsset = "mods/modern_ui_suite/components/modern_start_menu_ui/"
  .. "assets/start_menu_icons.png"
local damagedFs = { root = innerFs.root }
function damagedFs.read(path)
  if path == missingAsset then return nil, "simulated missing asset" end
  return innerFs.read(path)
end
function damagedFs.load(path) return innerFs.load(path) end
function damagedFs.getInfo(path)
  if path == missingAsset then return nil end
  return innerFs.getInfo(path)
end
function damagedFs.getDirectoryItems(path)
  if path == "mods" then return { "modern_ui_suite" } end
  return innerFs.getDirectoryItems(path)
end
local damaged = T.sdk.loadMods({ "mods/modern_ui_suite" }, {
  data = T.fixtures.fresh(), fs = damagedFs, dev = true,
})
T.check(#damaged.errors >= 1,
  "a damaged all-in-one archive is rejected during preflight")
T.eq(damaged.mods.modern_ui_suite.state, "failed",
  "a preflight failure marks the whole suite failed")
T.eq(damaged.loader.exports.modern_ui_suite, nil,
  "a preflight failure rolls back every component export")
T.eq(damaged.loader.optionSchemas.modern_ui_suite, nil,
  "a preflight failure leaves no partial settings schema")
damaged.release()

-- Compact Gen 2 widescreen battles are commonly only 200 logical pixels
-- wide. A details panel plus two move columns left each label room for just
-- two letters even though the footer had four full rows available. Exercise
-- the component directly with Gen 2's fixed-width battle font so both the
-- responsive geometry and the matching controller path stay covered here.
local savedGen2MoveChrome = package.loaded["src.ui.gen2.Chrome"]
local savedGen2MoveFont = package.loaded["src.render.Font"]
local savedGen2MoveSummary = package.loaded["src.ui.gen2.SummaryMenu"]
local savedGen2MovePolygon = love.graphics.polygon
local savedGen2MoveCircle = love.graphics.circle
love.graphics.polygon = function() end
love.graphics.circle = function() end
local gen2MovePrints = {}
local gen2BattleFont = false
package.loaded["src.render.Font"] = {
  TTF_BASE = 0x400000,
  useBattleExtra = function(on)
    local was = gen2BattleFont
    gen2BattleFont = on == true
    return was
  end,
  encode = function(text)
    local codes = {}
    for i = 1, #tostring(text or "") do
      codes[#codes + 1] = tostring(text):byte(i)
    end
    return codes
  end,
  advanceOf = function() return 8 end,
  width = function(text) return #tostring(text or "") * 8 end,
  draw = function(text) return #tostring(text or "") * 8 end,
}
package.loaded["src.ui.gen2.Chrome"] = {
  paletteGlyphs = function()
    local printed = { text = "", glyphs = {} }
    gen2MovePrints[#gen2MovePrints + 1] = printed
    return {}, function(code, x, y)
      printed.text = printed.text .. string.char(code)
      printed.glyphs[#printed.glyphs + 1] = { x = x, y = y }
    end, function() end
  end,
}
package.loaded["src.ui.gen2.SummaryMenu"] = {
  new = function() return {} end,
}

local gen2MoveHooks, pushedGen2Move
gen2MoveHooks = {}
local gen2MoveMod = {
  id = "typed_move_colors",
  options = {
    enabled = function() return true end,
    get = function(_, key)
      if key == "battle_colors" or key == "effect_hints" then return true end
      if key == "strength" then return "bold" end
      if key == "opacity" then return "100" end
      return nil
    end,
  },
  hooks = { wrap = function(_, name, callback)
    gen2MoveHooks[name] = callback
  end },
  events = { on = function(_, name, callback)
    if name == "screen.pushed" then pushedGen2Move = callback end
  end },
  content = { screens = {
    get = function() return nil end,
    register = function() end,
  } },
  exports = {},
  log = { info = function() end },
}
local gen2MoveInstall = assert(loadfile(
  "mods/modern_ui_suite/components/typed_move_colors/gen2.lua"))()
gen2MoveInstall(gen2MoveMod)

local gen2MovePressed = {}
local gen2MoveInput = {}
function gen2MoveInput:wasPressed(key) return gen2MovePressed[key] == true end
local gen2MoveDefs = {
  TACKLE = { name = "TACKLE", type = "NORMAL", power = 35, pp = 35 },
  SCREECH = { name = "SCREECH", type = "NORMAL", power = 0, pp = 40 },
  BIND = { name = "BIND", type = "NORMAL", power = 15, pp = 20 },
  EARTHQUAKE = {
    name = "EARTHQUAKE", type = "GROUND", power = 100, pp = 10,
  },
}
local gen2Moves = {
  { id = "TACKLE", pp = 18 }, { id = "SCREECH", pp = 40 },
  { id = "BIND", pp = 20 }, { id = "EARTHQUAKE", pp = 10 },
}
local function gen2MoveScreen(width)
  return {
    screenId = "Gen2BattleState", phase = "moves", moveIndex = 1,
    modernBattleWideWidth = width, modernBattleLastWideWidth = width,
    game = { input = gen2MoveInput, data = {
      moves = gen2MoveDefs, type_chart = { matchups = {} },
    } },
    player = { moves = gen2Moves },
    activeMon = function() return { types = { "GRASS", "POISON" } } end,
    update = function() end,
  }
end
local function drawGen2Moves(screen)
  gen2MovePrints = {}
  pushedGen2Move({ state = screen })
  gen2MoveHooks["battle.overlay"](function() end, screen)
end

local compactGen2Moves = gen2MoveScreen(200)
drawGen2Moves(compactGen2Moves)
-- The real Gen 2 compositor clears this draw-only field before input runs.
compactGen2Moves.modernBattleWideWidth = nil
T.eq(compactGen2Moves.typedMoveColorsLayout, "list",
  "a 200px Gen 2 battle uses four readable move rows")
T.eq(gen2MovePrints[1] and gen2MovePrints[1].text, "TACKLE",
  "compact Gen 2 keeps TACKLE instead of collapsing it to TA.")
T.eq(gen2MovePrints[2] and gen2MovePrints[2].text, "SCREECH",
  "compact Gen 2 keeps SCREECH instead of collapsing it to SC.")
T.eq(gen2MovePrints[3] and gen2MovePrints[3].text, "BIND",
  "compact Gen 2 keeps BIND instead of collapsing it to BI.")
T.eq(gen2MovePrints[4] and gen2MovePrints[4].text, "EARTHQUAKE",
  "compact Gen 2 keeps a ten-tile name beside its effect marker")
gen2MovePressed.right = true
compactGen2Moves:update()
gen2MovePressed.right = nil
T.eq(compactGen2Moves.moveIndex, 1,
  "compact Gen 2 ignores horizontal movement in its vertical list")
gen2MovePressed.down = true
compactGen2Moves:update()
gen2MovePressed.down = nil
T.eq(compactGen2Moves.moveIndex, 2,
  "compact Gen 2 DOWN follows the visible vertical list")

local roomyGen2Moves = gen2MoveScreen(304)
drawGen2Moves(roomyGen2Moves)
roomyGen2Moves.modernBattleWideWidth = nil
T.eq(roomyGen2Moves.typedMoveColorsLayout, "grid",
  "a genuinely roomy Gen 2 battle retains the 2x2 move grid")
T.eq(gen2MovePrints[4] and gen2MovePrints[4].text, "EARTHQUAKE",
  "the wide Gen 2 grid uses the marker's real footprint for name fitting")
gen2MovePressed.right = true
roomyGen2Moves:update()
gen2MovePressed.right = nil
T.eq(roomyGen2Moves.moveIndex, 2,
  "roomy Gen 2 RIGHT follows the visible 2x2 grid")
gen2MovePressed.down = true
roomyGen2Moves:update()
gen2MovePressed.down = nil
T.eq(roomyGen2Moves.moveIndex, 4,
  "roomy Gen 2 DOWN follows the visible 2x2 grid")
T.eq(gen2BattleFont, false,
  "the Gen 2 move presenter restores the caller's font page")

package.loaded["src.ui.gen2.Chrome"] = savedGen2MoveChrome
package.loaded["src.render.Font"] = savedGen2MoveFont
package.loaded["src.ui.gen2.SummaryMenu"] = savedGen2MoveSummary
love.graphics.polygon = savedGen2MovePolygon
love.graphics.circle = savedGen2MoveCircle

-- The Gen 2 Battle HUD decorates a screen instance after full-window battle
-- presenters have wrapped the class. An active Stadium scene must retain the
-- final draw: replacing it here regresses the fight to the centred stock art.
local savedGen2Chrome = package.loaded["src.ui.gen2.Chrome"]
package.loaded["src.ui.gen2.Chrome"] = {
  paletteGlyphs = function() return nil end,
  wrap = function(text) return { text } end,
}
local pushedGen2Battle
local gen2Hooks = {}
local stadiumActive = true
local stadiumScene
local battleArtState
local gen2Mod = {
  options = { get = function() return true end },
  hooks = { wrap = function(_, name, callback)
    gen2Hooks[name] = callback
  end },
  events = { on = function(_, name, callback)
    if name == "screen.pushed" then pushedGen2Battle = callback end
  end },
  exports = {},
  log = { info = function() end },
  find = function(id)
    if id == "STADIUM2_IMPORTER" then
      return { exports = {
        getActiveBattleScene = function() return stadiumScene end,
        battleStatus = function() return { active = stadiumActive } end,
      } }
    end
    if id == "BATTLE_ART_VOXEL_FORK" then
      return { exports = { battleStage = {
        state = function(expected)
          if battleArtState and expected == battleArtState.battle then
            return battleArtState
          end
        end,
      } } }
    end
  end,
}
local gen2Install = assert(loadfile(
  "mods/modern_ui_suite/components/battle_info_hud/gen2.lua"))()
gen2Install(gen2Mod)
T.eq(type(pushedGen2Battle), "function",
  "the Gen 2 Battle HUD registers its instance decorator")
T.eq(type(gen2Hooks["battle.overlay"]), "function",
  "the Gen 2 Battle HUD keeps its ordinary overlay integration")

local stadiumDraws = 0
local gen2Battle = {
  screenId = "Gen2BattleState",
  battle = {},
  drawWidescreen = function(_, width, height)
    stadiumDraws = stadiumDraws + 1
    return ("stadium:%dx%d"):format(width, height)
  end,
}
stadiumScene = { battle = gen2Battle.battle, screen = gen2Battle }
pushedGen2Battle({ state = gen2Battle })
T.eq(gen2Battle:drawWidescreen(1280, 720), "stadium:1280x720",
  "an active Stadium Gen 2 scene retains the final widescreen draw")
T.eq(stadiumDraws, 1,
  "the suite delegates to the captured 3D presenter exactly once")
T.eq(gen2Battle.modernBattleYieldedTo3D, true,
  "the screen records that its stock compositor yielded to 3D")
T.eq(gen2Battle.modernBattleKeptIntact, nil,
  "the stock centred capture never replaces an active 3D arena")

stadiumActive, stadiumScene = false, nil
local battleArtDraws = 0
local battleArtBattle = {
  screenId = "Gen2BattleState",
  battle = {},
  drawWidescreen = function()
    battleArtDraws = battleArtDraws + 1
    return "battle-art"
  end,
}
battleArtState = {
  battle = battleArtBattle.battle,
  staged = true,
  ownership = { arena = true },
}
pushedGen2Battle({ state = battleArtBattle })
T.eq(battleArtBattle:drawWidescreen(1280, 720), "battle-art",
  "a staged Battle Art Gen 2 scene also retains its final draw")
T.eq(battleArtDraws, 1,
  "the suite honours Battle Art's public arena-ownership contract")

package.loaded["src.ui.gen2.Chrome"] = savedGen2Chrome

T.finish("modern_ui_suite")
