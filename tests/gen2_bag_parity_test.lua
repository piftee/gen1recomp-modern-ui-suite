-- Standalone: luajit mods/modern_ui_suite/tests/gen2_bag_parity_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local total, failed = 0, 0
local function eq(actual, expected, label)
  total = total + 1
  if actual ~= expected then
    failed = failed + 1
    io.stderr:write(("not ok %d - %s (expected %s, got %s)\n"):format(
      total, label, tostring(expected), tostring(actual)))
  else
    print(("ok %d - %s"):format(total, label))
  end
end

local function ids(rows)
  local out = {}
  for _, row in ipairs(rows or {}) do out[#out + 1] = row.id end
  return table.concat(out, ",")
end

local pressed = {}
local input = {}
function input:wasPressed(key) return pressed[key] == true end
local function press(menu, key)
  pressed[key] = true
  menu:update(0)
  pressed[key] = nil
end

local NativePackMenu = {
  POCKETS = {
    { id = "ITEM", label = "ITEMS" },
    { id = "BALL", label = "POKé BALLS" },
    { id = "KEY_ITEM", label = "KEY ITEMS" },
    { id = "TM_HM", label = "TM/HM" },
  },
}

function NativePackMenu.new(game, opts)
  opts = opts or {}
  local menu = {
    game = game, save = opts.save or game.save,
    items = opts.items or game.data.items,
    bagData = { items = opts.items or game.data.items },
    pocketIndex = 1, index = 1, scroll = 0, rows = {},
  }
  function menu:pocket() return NativePackMenu.POCKETS[self.pocketIndex] end
  function menu:pocketOf(id)
    local def = self.items[id]
    return def and def.pocket or "ITEM"
  end
  function menu:total() return #self.rows + 1 end
  function menu:isCancel() return self.index > #self.rows end
  function menu:ensureVisible()
    if self.index <= self.scroll then self.scroll = self.index - 1 end
    if self.index > self.scroll + 5 then self.scroll = self.index - 5 end
    self.scroll = math.max(0, self.scroll)
  end
  function menu:rebuild()
    local Bag = require("src.inventory.Bag")
    local rows = {}
    for _, id in ipairs(Bag.order(self.save, self.bagData)) do
      if self.save.inventory[id] and self:pocketOf(id) == self:pocket().id then
        local def = self.items[id] or {}
        rows[#rows + 1] = {
          id = id, name = def.name or id,
          count = self.save.inventory[id],
          showCount = self:pocket().id ~= "KEY_ITEM",
          tmhmLabel = self:pocket().id == "TM_HM" and id or nil,
          teaches = def.teaches,
        }
      end
    end
    if self:pocket().id == "TM_HM" then
      table.sort(rows, function(a, b)
        return (self.items[a.id].tmNumber or 0)
          < (self.items[b.id].tmNumber or 0)
      end)
    end
    self.rows = rows
    self.index = math.max(1, math.min(self.index, #rows + 1))
    self:ensureVisible()
  end
  function menu:storeCursor()
    self.lastStoredPocket = self:pocket().id
  end
  function menu:restoreCursor() self.index, self.scroll = 1, 0 end
  function menu:switchPocket(delta)
    self.pocketIndex = (self.pocketIndex - 1 + delta)
      % #NativePackMenu.POCKETS + 1
    self:rebuild()
  end
  function menu:submenuRows()
    if self:pocket().id == "TM_HM" then return { "use", "give", "quit" } end
    if self:pocket().id == "KEY_ITEM" then return { "use", "sel", "quit" } end
    return { "use", "give", "toss", "quit" }
  end
  function menu:openSubmenu()
    self.submenu = { row = self.rows[self.index], rows = self:submenuRows(),
      index = 1, sourcePocket = self:pocket().id }
  end
  function menu:armSwitch()
    if self:pocket().id == "TM_HM" or self:isCancel() then return end
    self.switching = self.index
  end
  function menu:placeSwitch()
    self.basePlaceCalls = (self.basePlaceCalls or 0) + 1
    self:endSwitch()
  end
  function menu:endSwitch()
    self.switching, self.message = nil, nil
  end
  function menu:playSfx(name) self.lastSfx = name end
  function menu:playSfxTwice(name) self.lastSfx = name end
  function menu:description()
    local row = self.rows[self.index]
    return row and (self.items[row.id].description or row.name) or nil
  end
  function menu:playerName() return "GOLD" end
  function menu:update()
    if self.switching then
      if input:wasPressed("a") or input:wasPressed("select") then
        self:placeSwitch()
      elseif input:wasPressed("b") then
        self:endSwitch()
      end
      return
    end
    if self.submenu then return end
    if input:wasPressed("left") then self:switchPocket(-1)
    elseif input:wasPressed("right") then self:switchPocket(1)
    elseif input:wasPressed("a") and not self:isCancel() then self:openSubmenu()
    elseif input:wasPressed("select") then self:armSwitch() end
  end
  function menu:drawPanel() self.nativeDraws = (self.nativeDraws or 0) + 1 end
  menu:rebuild()
  return menu
end

local NativeItemPcMenu = {}
function NativeItemPcMenu.new(game)
  return { game = game, drawPanel = function() end }
end

local drawnGlyphBottom = 0
package.loaded["src.ui.gen2.Chrome"] = {
  wrap = function(text, columns)
    columns = math.max(1, tonumber(columns) or 19)
    local lines, current = {}, ""
    for word in tostring(text or ""):gmatch("%S+") do
      local candidate = current == "" and word or (current .. " " .. word)
      if current ~= "" and #candidate > columns then
        lines[#lines + 1] = current
        current = word
      else
        current = candidate
      end
    end
    if current ~= "" then lines[#lines + 1] = current end
    return lines
  end,
  box = function() end,
  paletteGlyphs = function()
    return {}, function(_, _, y)
      drawnGlyphBottom = math.max(drawnGlyphBottom, y + 8)
    end, function() end
  end,
}
package.loaded["src.render.Font"] = {
  width = function(text) return #tostring(text or "") * 8 end,
  encode = function(text)
    local out = {}
    for i = 1, #tostring(text or "") do out[#out + 1] = text:byte(i) end
    return out
  end,
  advanceOf = function() return 8 end,
}
package.loaded["src.ui.gen2.PackMenu"] = NativePackMenu
package.loaded["src.ui.gen2.ItemPcMenu"] = NativeItemPcMenu

love = { graphics = {
  setColor = function() end, rectangle = function() end,
  polygon = function() end, push = function() end, pop = function() end,
  scale = function() end, translate = function() end,
  setLineWidth = function() end, setScissor = function() end,
} }

local screens = {}
local skin = "modern"
local mod = {
  options = { get = function(_, key) return key == "skin" and skin or nil end },
  exports = {}, log = { info = function() end },
  content = { screens = {
    get = function(_, id) return screens[id] end,
    register = function(_, id, record) screens[id] = record end,
    override = function(_, id, record) screens[id] = record end,
  } },
}

local itemDefs = {
  ESCAPE_ROPE = { name = "ESCAPE ROPE", pocket = "ITEM",
    fieldMenu = "ITEMMENU_CLOSE", description = "Escape." },
  POTION = { name = "POTION", pocket = "ITEM",
    fieldMenu = "ITEMMENU_PARTY", description = "Heal." },
  ANTIDOTE = { name = "ANTIDOTE", pocket = "ITEM",
    fieldMenu = "ITEMMENU_PARTY", description = "Cure." },
  NUGGET = { name = "NUGGET", pocket = "ITEM",
    fieldMenu = "ITEMMENU_NOUSE", description = "Treasure." },
  POKE_BALL = { name = "POKé BALL", pocket = "BALL", description = "Catch." },
  BICYCLE = { name = "BICYCLE", pocket = "KEY_ITEM", description = "Ride." },
  TM_Z = { name = "ZETA TM", pocket = "TM_HM", tmNumber = 1,
    teaches = "ZETA", description = "Teach Zeta." },
  TM_A = { name = "ALPHA TM", pocket = "TM_HM", tmNumber = 2,
    teaches = "ALPHA", description = "Teach Alpha." },
}
local save = {
  money = 999999,
  inventory = {
    ESCAPE_ROPE = 1, POTION = 4, ANTIDOTE = 2, NUGGET = 1,
    POKE_BALL = 12, BICYCLE = 1, TM_Z = 1, TM_A = 1,
  },
  player = { name = "GOLD" },
}
save.bagOrder = { "POTION", "ESCAPE_ROPE", "POKE_BALL", "BICYCLE",
  "TM_Z", "ANTIDOTE", "NUGGET", "TM_A" }
local game = { save = save, data = { items = itemDefs }, input = input }

dofile("mods/modern_ui_suite/components/modern_bag_ui/gen2.lua")(mod, {})
local menu = screens.Gen2PackMenu.new(game, { save = save, items = itemDefs })

eq(menu:modernBagLayoutInfo().pockets, 6,
  "modern Gen 2 exposes the same six Bag views as Gen 1")
eq(menu:modernBagLayoutInfo().pocket, "ITEMS",
  "the native remembered ITEM pocket maps to the Items view")
eq(ids(menu.rows), "ESCAPE_ROPE,NUGGET",
  "Items excludes the Medicine filter without changing storage")

press(menu, "left")
eq(menu:modernBagLayoutInfo().pocket, "ALL", "left reaches All")
eq(#menu.rows, 8, "All spans every real Gen 2 pocket")
press(menu, "right")
press(menu, "right")
eq(menu:modernBagLayoutInfo().pocket, "MEDICINE", "Medicine has its own tab")
eq(ids(menu.rows), "POTION,ANTIDOTE", "Medicine filters the native ITEM pocket")

press(menu, "left")
press(menu, "left")
local tmIndex
for i, row in ipairs(menu.rows) do if row.id == "TM_A" then tmIndex = i end end
menu.index = tmIndex
press(menu, "a")
eq(menu.submenu and menu.submenu.sourcePocket, "TM_HM",
  "A from All routes a TM through the native TM/HM actions")
eq(table.concat(menu.submenu.rows, ","), "use,give,quit",
  "the native TM/HM submenu remains intact")
menu.submenu = nil

local keyIndex
for i, row in ipairs(menu.rows) do if row.id == "BICYCLE" then keyIndex = i end end
menu.index = keyIndex
press(menu, "a")
eq(menu.submenu and menu.submenu.sourcePocket, "KEY_ITEM",
  "A from All routes a key item through native key-item rules")
eq(table.concat(menu.submenu.rows, ","), "use,sel,quit",
  "the native SEL registration action remains available")
menu.submenu = nil

local nuggetIndex
for i, row in ipairs(menu.rows) do if row.id == "NUGGET" then nuggetIndex = i end end
menu.index = nuggetIndex
press(menu, "select")
eq(menu.switching, nuggetIndex, "Select arms manual reorder in All")
menu.index = 1
press(menu, "select")
eq(save.bagOrder[1], "NUGGET", "All-view manual reorder updates bagOrder")
eq(menu.switching, nil, "manual reorder returns to browsing")

press(menu, "start")
eq(menu.modernBagSortMenu and #menu.modernBagSortMenu.rows, 4,
  "Start opens the four shared sort choices")
press(menu, "down")
press(menu, "down")
press(menu, "a")
eq(table.concat(save.bagOrder, ","),
  "TM_A,ANTIDOTE,BICYCLE,ESCAPE_ROPE,NUGGET,POKE_BALL,POTION,TM_Z",
  "Names A-Z sorts the canonical Gen 2 bag order")

menu.modernBagPocketIndex = 5
menu.modernBagRestoreState = { index = 1 }
menu:rebuild()
eq(ids(menu.rows), "TM_A,TM_Z",
  "name sorting overrides native TM-number order in the TM view")

menu.modernBagPocketIndex = 1
menu.modernBagRestoreState = { index = 1 }
menu:rebuild()
menu:modernBagSort("category", false)
local categories = {}
for _, id in ipairs(save.bagOrder) do
  categories[#categories + 1] = menu:modernBagCategoryFor(id)
end
eq(table.concat(categories, ","),
  "ITEMS,ITEMS,MEDICINE,MEDICINE,BALL,TM_HM,TM_HM,KEY_ITEM",
  "category ascending matches the Gen 1 tab order")
menu:modernBagSort("category", true)
categories = {}
for _, id in ipairs(save.bagOrder) do
  categories[#categories + 1] = menu:modernBagCategoryFor(id)
end
eq(table.concat(categories, ","),
  "KEY_ITEM,TM_HM,TM_HM,BALL,MEDICINE,MEDICINE,ITEMS,ITEMS",
  "category descending reverses the shared tab order")
menu:modernBagSort("name", true)
eq(table.concat(save.bagOrder, ","),
  "TM_Z,POTION,POKE_BALL,NUGGET,ESCAPE_ROPE,BICYCLE,ANTIDOTE,TM_A",
  "Names Z-A sorts the canonical Gen 2 bag order descending")

menu.message = { "FIRST LINE", "SECOND LINE" }
drawnGlyphBottom = 0
local compactOk = pcall(menu.drawPanel, menu)
eq(drawnGlyphBottom <= 144, true,
  "compact two-line footer stays inside the 144px panel")
menu.message = nil
local mobileOk = pcall(menu.drawWidescreen, menu, 320, 480)
local wideOk = pcall(menu.drawWidescreen, menu, 1200, 720)
eq(compactOk, true, "six-tab Bag draws at cartridge width")
eq(mobileOk, true, "six-tab Bag draws in compact mobile geometry")
eq(wideOk, true, "six-tab Bag draws in widescreen geometry")
local wideLayout = menu:modernBagLayoutInfo()
eq(wideLayout.layout, "full-width-bottom",
  "modern Bag uses the full-width list and bottom-detail layout")
eq(wideLayout.listWidth, wideLayout.detailWidth,
  "the bottom detail spans the same width as the item list")
eq(wideLayout.detailWidth, menu.modernBagLastWideWidth,
  "the bottom detail spans the whole responsive panel")
eq(wideLayout.detailPosition, "bottom",
  "item details no longer occupy a narrow side rail")
eq(table.concat(wideLayout.tabLabels, ","),
  "ALL,ITEMS,MED,BALLS,TM/HM,KEY",
  "normal widescreen tabs use readable names before abbreviating")

itemDefs.ESCAPE_ROPE.description = table.concat({
  "Returns the player to the most recent healing location after a long",
  "journey while preserving every word in this intentionally oversized",
  "description for the responsive scrolling test.",
}, " ")
menu.modernBagPocketIndex = 2
menu.modernBagRestoreState = { id = "ESCAPE_ROPE" }
menu:rebuild()
menu:drawPanel()
local qol = menu:modernBagQolInfo()
eq(qol.headerCash, "¥999999", "modern header shows the exact maximum money")
eq(qol.header.cashX + qol.header.cashW <= qol.header.hintLeft, true,
  "maximum money does not collide with the Start hint")
eq(qol.header.hintRight <= qol.header.countX, true,
  "the responsive Start hint does not collide with the item count")
eq(qol.descriptionOverflow, true,
  "an oversized modern description activates overflow scrolling")
eq(qol.descriptionStaticLines, 1,
  "the first fitting description line remains static")
menu:update(2)
menu:drawPanel()
qol = menu:modernBagQolInfo()
eq(qol.descriptionOffset > 0, true,
  "overflow advances using elapsed time after the initial hold")
for index, row in ipairs(menu.rows) do
  if row.id == "NUGGET" then menu.index = index break end
end
menu:drawPanel()
qol = menu:modernBagQolInfo()
eq(qol.descriptionOverflow, false,
  "a fitting description remains static")
eq(qol.descriptionOffset, 0,
  "changing selection resets the description position")
menu.message = { "STATIC PROMPT" }
menu:update(2)
menu:drawPanel()
qol = menu:modernBagQolInfo()
eq(qol.descriptionOffset, 0,
  "native messages never inherit description motion")
menu.message = nil

menu.modernBagPocketIndex = 3
menu.modernBagRestoreState = { id = "POTION" }
menu:rebuild()
menu:storeCursor()
local reopened = screens.Gen2PackMenu.new(game, { save = save, items = itemDefs })
eq(reopened:modernBagLayoutInfo().pocket, "MEDICINE",
  "reopening remembers the last modern view")
eq(reopened.rows[reopened.index] and reopened.rows[reopened.index].id, "POTION",
  "reopening remembers that view's selected item")

skin = "classic_pocket"
menu:rebuild()
eq(menu:modernBagLayoutInfo().pockets, 4,
  "the source-faithful Pocket skin keeps native four-pocket chrome")
press(menu, "start")
eq(menu.modernBagSortMenu ~= nil, true,
  "Start sorting remains available in the Pocket skin")
press(menu, "b")
eq(menu.modernBagSortMenu, nil, "B closes the sort menu")
menu.index = 1
menu:drawPanel()
eq(menu:modernBagQolInfo().headerCash, "¥999999",
  "Pocket skin also replaces its header label with exact money")

if failed > 0 then
  error(("%d of %d Gen 2 Bag parity checks failed"):format(failed, total), 0)
end
print(("%d/%d Gen 2 Bag parity checks passed"):format(total, total))
