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
  modern_start_menu_ui = "0.1.16",
  modern_party_ui = "0.4.8",
  modern_bag_ui = "0.4.10",
  modern_pc_ui = "0.4.3",
  modern_pokedex_ui = "0.2.10",
  battle_info_hud = "0.9.0",
  typed_move_colors = "0.4.8",
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
for _, row in ipairs(schema) do schemaByKey[row.key] = row end
for _, key in ipairs(componentKeys) do
  local row = schemaByKey[key .. ".enabled"]
  T.check(type(row) == "table", key .. " has a namespaced master toggle")
  T.eq(row and row.default, true, key .. " is on by default")
end
T.eq(schemaByKey["battle_hud.enabled"].label, "BATTLE HUD ENABLED",
  "Battle HUD's former enabled option is its single suite master toggle")
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

-- Typed Move Colors has process-stable patches on native controller classes.
-- Those patches outlive the suite's hook gate, so their own presentation
-- predicates must release the native Summary and battle chrome when the
-- component master switch is off.
local BattleState = require("src.battle.BattleState")
local typedTextPatch = rawget(BattleState, "_typedMoveColorsTextPatch")
T.eq(type(typedTextPatch and typedTextPatch.owns), "function",
  "Typed Move Colors exposes its native battle-chrome ownership predicate")
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

suiteOptions["bag.enabled"] = true
local openModern = run.data.screens.BagMenu.new(game, {})
T.eq(openModern.modernBagUI, true,
  "an enabled screen component opens its modern presentation")
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

T.finish("modern_ui_suite")
