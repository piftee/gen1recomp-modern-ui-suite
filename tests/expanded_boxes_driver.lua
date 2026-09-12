-- Native v0.2 companion integration. Use only the silent, private-profile runner.
return function(game)
  local Save = require("src.core.gen2.Save")
  local Boxes = require("src.core.gen2.Boxes")
  local Mon = require("src.battle.gen2.Mon")
  local Mail = require("src.core.gen2.Mail")
  local Battle = require("src.battle.gen2.Battle")
  local Screens = require("src.ui.Screens")
  local Version = require("src.core.GameVersion")
  local U = dofile(assert(os.getenv("PC_REPO")) .. "/tests/drivers/util.lua")
  local checks = 0
  local function check(ok, label) assert(ok, label); checks = checks + 1 end
  local function eq(a, b, label) check(a == b, label .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
  local function quiet()
    check(not love.window.hasFocus(), "window stays unfocused")
    eq(love.audio.getVolume(), 0, "audio stays muted")
  end
  local function press(pc, key)
    local old = game.input
    game.input = setmetatable({wasPressed = function(_, k) return k == key end,
      isDown = function() return false end}, {__index = old})
    local ok, err = pcall(pc.update, pc, 0); game.input = old; assert(ok, err)
  end
  local function clear() while game.stack:top() do game.stack:pop() end end
  local species = {"CHIKORITA", "CYNDAQUIL", "TOTODILE", "PIKACHU", "MAREEP", "WOOPER"}
  local function mon(i)
    local m = assert(Mon.new(game.data, species[(i - 1) % #species + 1], 10 + i % 80))
    m.nickname = ("SLOT%02d"):format(i)
    return m
  end
  eq(Boxes.NUM_BOXES, 50, "real companion sets box count")
  eq(Boxes.MONS_PER_BOX, 50, "real companion sets box capacity")
  eq(Save.NUM_BOXES, 50, "save model receives companion count")
  eq(Save.MONS_PER_BOX, 50, "save model receives companion capacity")
  local function persisted(save)
    eq(save.currentBox, 50, "current box survives loading")
    eq(#save.boxes[1], 50, "first full box survives loading")
    eq(#save.boxes[50], 50, "fiftieth full box survives loading")
    eq(save.boxes[50][50].nickname, "FINAL SLOT", "slot fifty identity survives loading")
    eq(save.boxes[50][50].item, "BERRY", "held item survives loading")
    check(save.boxes[50][50].shiny, "shiny flag survives loading")
    eq(Mail.get(save, 1).message, "HELLO", "party Mail survives loading")
  end
  if os.getenv("EXPANDED_REOPEN") == "1" then
    game.save = assert(Save.load(Version.get())); persisted(game.save)
    clear()
    local pc = Screens.push(game, "Gen2PcMenu", {save = game.save, bills = true})
    check(pc.modernPCUI, "restarted save opens suite PC")
    pc.boxIndex = 50
    local l = pc:modernPCLayoutInfo()
    eq(l.box.last, 50, "restarted save can display final slot")
    quiet(); print("[EXPANDED QA] PASS restart " .. checks); love.event.quit(0); return
  end
  local function fixture()
    clear(); game.save = Save.newGame({playerName = "BOX QA", trainerId = 1234})
    local save = game.save
    save.party = {}; save.boxes = {}; save.currentBox = 1
    for i = 1, 6 do save.party[i] = mon(i) end
    for b = 1, 50 do save.boxes[b] = {} end
    for i = 1, 50 do save.boxes[1][i] = mon(i); save.boxes[50][i] = mon(i) end
    local pc = Screens.push(game, "Gen2PcMenu", {save = save, bills = true,
      writer = function() return Save.save(save) end, onClose = function() game.stack:pop() end})
    check(pc.modernPCUI, "PC controller belongs to suite with expansion enabled")
    return pc, save
  end
  local function action(pc, kind)
    press(pc, "start")
    for i, entry in ipairs(pc.actions or {}) do
      if entry.action == kind then pc.actionIndex = i; press(pc, "a"); return end
    end
    error("missing PC action " .. kind)
  end
  local pc, save = fixture()
  local options = game.mods.modOptions.modern_ui_suite
  local function render(label)
    pc.status = nil
    U.wait(3)
    local l = pc:modernPCLayoutInfo()
    local seen, renderer = {}, pc.modernPCIconRenderer
    local original = renderer.drawIcon
    renderer.drawIcon = function(self, m, x, y, ...)
      seen[m] = {x=x, y=y}; return original(self, m, x, y, ...)
    end
    local G = love.graphics
    local canvas = G.newCanvas(l.width, l.canvasHeight or l.height)
    G.push("all"); G.setCanvas(canvas); G.origin(); G.setScissor(); pc:draw(); G.pop()
    renderer.drawIcon = original
    if not pc.boxPicker then
      for i, m in ipairs(Boxes.box(save)) do
        if i >= l.box.first and i <= l.box.last then
          check(seen[m], "visible icon rendered at slot " .. i)
          check(seen[m].y >= l.box.y and seen[m].y + 16 <= l.box.y + l.box.h,
            "box icon stays inside viewport at slot " .. i)
        else check(not seen[m], "offscreen slot never draws over party/footer: " .. i) end
      end
      for _, m in ipairs(save.party) do
        check(seen[m] and seen[m].y >= l.party.y, "party icons remain visible below viewport")
      end
    end
    local encoded = canvas:newImageData():encode("png"):getString()
    local file = assert(io.open(os.getenv("SHOT_DIR") .. "/" .. label .. ".png", "wb"))
    file:write(encoded); file:close(); canvas:release(); quiet()
  end
  for _, size in ipairs({{"compact",640,576,"fill"}, {"four-three",768,576,"4:3"},
      {"wide",1280,720,"16:9"}, {"portrait",480,900,"fill"}}) do
    options["pc.aspect_ratio"] = size[4]
    love.window.setMode(size[2], size[3], {resizable=true, vsync=0}); U.wait(3)
    pc.region, pc.boxIndex, pc.boxSwitching, pc.boxPicker = "box", 1, false, false
    save.currentBox = 1; options["pc.box_exclusive"] = false
    render(size[1] .. "-top")
    pc.boxIndex = 20; press(pc, "down")
    eq(pc.boxIndex, 25, "Down from old final row reaches expanded row")
    eq(pc.region, "box", "old grid edge no longer enters party")
    render(size[1] .. "-middle")
    for _ = 1, 5 do press(pc, "down") end
    eq(pc.boxIndex, 50, "Down reaches slot fifty")
    render(size[1] .. "-bottom")
    local l = pc:modernPCLayoutInfo()
    eq(l.box.first, 31, "last viewport shows slots 31 to 50")
    press(pc, "down"); eq(pc.region, "party", "Down after final row enters party")
    press(pc, "up"); check(pc.boxIndex >= 46, "Up from party returns to actual bottom row")
    pc.boxIndex = 50; press(pc, "a"); local held = pc.held
    press(pc, "right"); eq(save.currentBox, 2, "expanded row edge changes box")
    eq(pc.held, held, "carried mon survives box switch and scrolling")
    eq(held.sourceList[50], held.mon, "carry keeps original slot intact")
    press(pc, "b"); eq(pc.held, nil, "carry cancellation leaves storage unchanged")
    press(pc, "select"); press(pc, "a"); pc.boxPickerIndex = 48
    press(pc, "down"); eq(pc.boxPickerIndex, 50, "last partial picker row is reachable")
    render(size[1] .. "-boxes")
    press(pc, "a"); eq(save.currentBox, 50, "picker opens box fifty")
    press(pc, "select"); press(pc, "right"); eq(save.currentBox, 1, "header wraps after box fifty")
    press(pc, "left"); eq(save.currentBox, 50, "header wraps before box one"); press(pc, "b")
    options["pc.box_exclusive"] = true; pc.boxIndex = 46; press(pc, "left")
    eq(pc.boxIndex, 50, "Box Only wraps inside expanded final row")
    eq(save.currentBox, 50, "Box Only never switches boxes at grid edge")
    pc.boxIndex = 20; press(pc, "down"); eq(pc.boxIndex, 25, "Box Only also scrolls")
  end
  options["pc.box_exclusive"] = false
  pc, save = fixture()
  local p, b = save.party[1], save.boxes[1][50]
  pc.region, pc.partyIndex = "party", 1
  check(not pc:modernPCQuickTransfer(), "fifty-first deposit refused")
  eq(#save.boxes[1], 50, "full-box refusal preserves fifty mons")
  press(pc, "a"); pc.region, pc.boxIndex = "box", 50; press(pc, "a")
  eq(save.party[1], b, "occupied slot fifty swaps with full party")
  eq(save.boxes[1][50], p, "outgoing mon occupies slot fifty")
  local spare = table.remove(save.party)
  check(pc:modernPCQuickTransfer(), "quick withdrawal reaches slot fifty")
  eq(save.party[6], p, "quick withdrawal preserves expanded record identity")
  eq(#save.boxes[1], 49, "quick withdrawal removes just one expanded record")
  pc.region, pc.partyIndex = "party", 6
  check(pc:modernPCQuickTransfer(), "quick deposit can refill slot fifty")
  eq(save.boxes[1][50], p, "quick deposit appends at actual expanded limit")
  save.party[6] = spare
  pc.region, pc.boxIndex = "box", 45; action(pc, "multi")
  for i = 46, 50 do pc.boxIndex = i; press(pc, "a") end
  local marked = {}; for i, mark in ipairs(pc.multi) do marked[i] = mark.mon end
  action(pc, "multi_party")
  eq(pc.multiMode, nil, "whole-party swap accepts fifty-mon source")
  for i = 1, 6 do eq(save.party[i], marked[i], "expanded selection swaps in order") end
  eq(#save.boxes[1], 50, "group swap keeps expanded source full")
  pc.region, pc.boxIndex = "box", 49; action(pc, "multi")
  pc.boxIndex = 50; press(pc, "a")
  local a, b = pc.multi[1].mon, pc.multi[2].mon
  table.remove(save.boxes[50]); table.remove(save.boxes[50])
  pc:modernPCSwitchBox(49); pc.boxIndex = 49; press(pc, "a")
  eq(save.boxes[50][49], a, "group fills expanded slot forty-nine")
  eq(save.boxes[50][50], b, "group fills expanded slot fifty")
  eq(#save.boxes[1], 48, "group removes exactly two source records")
  pc:modernPCSwitchBox(1) -- Box 1 has room, so exercise Mail rather than the full-box gate.
  pc.region, pc.partyIndex = "party", 1; save.party[1].item = "FLOWER_MAIL"
  local letter = Mail.entry("FLOWER_MAIL", "HELLO", "BOX QA", 1234, save.party[1].species)
  Mail.set(save, 1, letter)
  check(not pc:modernPCQuickTransfer(), "Mail still cannot enter an expanded box")
  check(pc.status:find("MAIL", 1, true), "Mail rule causes refusal with expanded space available")
  eq(Mail.get(save, 1), letter, "refused transfer preserves letter identity")
  -- Last available slot among 2,500; the actual battle handler must fill it.
  pc, save = fixture(); clear()
  for box = 1, 50 do
    for i = 1, 50 do save.boxes[box][i] = mon(i) end
  end
  table.remove(save.boxes[50]); save.currentBox = 49; save.inventory.MASTER_BALL = 2
  local enemy = mon(7); enemy.item = "BERRY"
  local battle = Battle.new({data=game.data, save=save, party=save.party, wild=enemy,
    random=function() return 0 end})
  local bs = Screens.push(game, "Gen2BattleState", {save=save, battle=battle, onDone=function() end})
  bs:useItem("MASTER_BALL")
  eq(battle.outcome, "caught", "native capture succeeds in last storage slot")
  eq(save.currentBox, 50, "catch overflow finds fiftieth box")
  eq(#save.boxes[50], 50, "capture fills expanded box exactly")
  eq(save.boxes[50][1], enemy, "native catch inserts the original enemy record")
  eq(save.inventory.MASTER_BALL, 1, "catch consumes exactly one ball")
  local nextBattle = Battle.new({data=game.data, save=save, party=save.party, wild=mon(8),
    random=function() return 0 end})
  clear(); bs = Screens.push(game, "Gen2BattleState", {save=save, battle=nextBattle, onDone=function() end})
  bs:useItem("MASTER_BALL")
  eq(save.inventory.MASTER_BALL, 1, "all 2,500 slots full refuses before spending ball")
  check(nextBattle.outcome ~= "caught", "full storage cannot report a catch")
  -- Save every expanded box, plus record metadata, then verify in a new process.
  clear(); save.boxes[50][50].nickname = "FINAL SLOT"
  save.boxes[50][50].item, save.boxes[50][50].shiny = "BERRY", true
  save.party[1].item = "FLOWER_MAIL"
  Mail.set(save, 1, Mail.entry("FLOWER_MAIL", "HELLO", "BOX QA", 1234, save.party[1].species))
  check(Save.save(save), "native save writes expanded storage")
  local loaded = assert(Save.load(Version.get()))
  persisted(loaded)
  for box = 1, 50 do eq(#loaded.boxes[box], 50, "every box survives serialization") end
  quiet(); print("[EXPANDED QA] PASS " .. checks); love.event.quit(0)
end
