-- Native font/layout regression; run through the isolated quiet runner.
return function(game)
  local U = dofile(assert(os.getenv("PC_REPO")) .. "/tests/drivers/util.lua")
  local Screens = require("src.ui.Screens")
  local Party = require("src.ui.gen2.PartyMenu")
  local Mon = require("src.battle.gen2.Mon")
  local Font = require("src.render.Font")
  local Chrome = require("src.ui.gen2.Chrome")
  local G = love.graphics
  local opts = game.mods.modOptions.modern_ui_suite
  local checks = 0
  local function check(ok, label) assert(ok, label); checks = checks + 1 end
  while game.stack:top() do game.stack:pop() end
  game.save = require("src.core.gen2.Save").newGame({playerName="LEVEL QA"})
  game.save.options = game.options or game.save.options
  game.save.party = {}
  local levels = {1, 9, 10, 99, 100, 100}
  for i, species in ipairs({"MEWTWO", "HO_OH", "BLASTOISE", "AMPHAROS", "TYRANITAR", "LUGIA"}) do
    game.save.party[i] = Mon.new(game.data, species, levels[i])
  end
  local menu = Screens.push(game, "Gen2PartyMenu", {save=game.save, submenu=true})
  check(menu.modernPartyGeneration == 2, "modern Gen2 Party loaded")

  -- Observe the actual rendered glyphs and transformed bounds, including
  -- fitting and scaling. A full source string alone cannot catch truncation.
  local glyphs = Chrome.paletteGlyphs
  local spans = {}
  Chrome.paletteGlyphs = function(...)
    local palette, draw, finish = glyphs(...)
    local span = {codes={}, left=math.huge, right=-math.huge, top=math.huge, bottom=-math.huge}
    return palette, function(code, x, y)
      span.codes[#span.codes+1] = code
      local left, top = G.transformPoint(x, y)
      local right, bottom = G.transformPoint(x + Font.advanceOf(code), y + 8)
      span.left, span.right = math.min(span.left, left), math.max(span.right, right)
      span.top, span.bottom = math.min(span.top, top), math.max(span.bottom, bottom)
      return draw(code, x, y)
    end, function()
      spans[#spans+1] = span
      return finish()
    end
  end
  local function find(text, left, right, y)
    local codes = table.concat(Font.encode(text), ",")
    for _, span in ipairs(spans) do
      if table.concat(span.codes, ",") == codes and span.left >= left - .01
          and span.right <= right + .01 and span.top >= y - .01
          and span.bottom <= y + 8.01 then return span end
    end
  end
  local function verify(width, mode)
    local canvas = G.newCanvas(width, 144)
    canvas:setFilter("nearest", "nearest")
    G.push("all"); G.setCanvas(canvas); G.origin(); G.setScissor(); G.setShader()
    G.clear(1,1,1,1)
    menu.modernPartyWideWidth = width
    spans = {}
    menu:drawPanel()
    menu.modernPartyWideWidth = nil
    for i, mon in ipairs(game.save.party) do
      local columns = width >= 240 and 2 or 1
      local compact = columns == 1
      local col, row = (i-1)%columns, math.floor((i-1)/columns)
      local left = math.floor(col*width/columns) + (compact and 26 or 23)
      local right = math.floor((col+1)*width/columns) - 7
      local y = 18 + row*(compact and 18 or 31)
      local data = Party.rowFor(mon)
      local level = find(data.level, left, right, y + (compact and 1 or 13))
      check(level, mode.." width "..width.." slot "..i.." shows complete level inside card")
      check(level.bottom - level.top == 8, "level glyphs remain full size")
      local name = find(data.name, left, compact and level.left - 4 or right,
        y + (compact and 1 or 3))
      check(name, "complete species name fits without touching level")
      local detail = data.status
      local percent = not detail and opts["party.hp_text"] == "percent"
      if percent then detail = tostring(math.floor(mon.hp / mon.maxHp * 100)) end
      if detail then
        local other = find(detail, left, right, y + (compact and 9 or 13))
        check(other and other.bottom - other.top == 8
          and (compact or other.left >= level.right + 2),
          mode.." width "..width.." slot "..i.." shows full detail without overlap")
        if percent then check(math.abs(right - other.right - 6) < .01,
          "percentage leaves six pixels for the bitmap percent symbol") end
      end
    end
    G.pop()
    if width == 160 or width == 192 or width == 256 then
      local big = G.newCanvas(width*4, 576)
      G.push("all"); G.setCanvas(big); G.origin(); G.setScissor(); G.setShader()
      G.clear(1,1,1,1); G.setColor(1,1,1,1); G.draw(canvas,0,0,0,4,4); G.pop()
      local file = assert(io.open(os.getenv("SHOT_DIR").."/"..mode.."-"..width..".png","wb"))
      file:write(big:newImageData():encode("png"):getString()); file:close(); big:release()
    end
    canvas:release()
  end
  for _, mode in ipairs({"healthy", "percent", "status"}) do
    opts["party.hp_text"] = mode == "healthy" and "bar" or "percent"
    for i, mon in ipairs(game.save.party) do
      mon.status, mon.hp = nil, mon.maxHp
      if mode == "status" then
        mon.level = 100
        mon.status = ({"poison", "paralyze", "sleep", "burn", "freeze"})[i]
        if i == 6 then mon.hp = 0 end
      end
    end
    for _, width in ipairs({160, 192, 239, 240, 256, 320}) do verify(width, mode) end
  end
  Chrome.paletteGlyphs = glyphs
  local function press(key)
    local input = game.input
    game.input = setmetatable({wasPressed=function(_, k) return k == key end}, {__index=input})
    local ok, why = pcall(menu.update, menu, 0)
    game.input = input
    assert(ok, why)
  end
  for _, width in ipairs({160,192,239,240,256}) do
    menu.modernPartyLastWideWidth, menu.index = width, 1
    press("down")
    check(menu.index == (width < 240 and 2 or 3), "Down matches rendered rows")
    press("right")
    check(menu.index == (width < 240 and 2 or 4), "Right matches rendered columns")
    menu.index = 6; press("down")
    check(menu:isCancel(), "Cancel remains reachable")
    press("up"); check(menu.index == 6, "Up returns from Cancel")
  end
  menu.modernPartyLastWideWidth, menu.index = 192, 1
  local first, second = game.save.party[1], game.save.party[2]
  press("select"); check(menu.switchFrom == 1, "Select begins native switching")
  press("down"); check(menu.index == 2, "Switch target follows compact rows")
  press("select")
  check(not menu.switchFrom and game.save.party[1] == second
    and game.save.party[2] == first, "Select completes native switching")
  local waitStart = love.timer.getTime()
  while menu.repeatSfx and love.timer.getTime() - waitStart < 5 do U.wait(30) end
  check(not menu.repeatSfx, "native switch sound wait completes before new input")
  opts["party.aspect_ratio"] = "4:3"
  love.window.setMode(480,900,{resizable=true})
  U.wait(3)
  check(U.shot(game,os.getenv("SHOT_DIR").."/status-phone-4x3.png"), "phone screenshot")
  menu.index = 1
  local ww, wh = G.getDimensions()
  local scale = math.floor(math.min(ww / 192, wh / 144))
  local x, y = (ww-192*scale)/2 + 60*scale, (wh-144*scale)/2 + 44*scale
  local function tap()
    game:pointerEvent("pressed","touch","levels-qa",x,y,0,0,1)
    game:pointerEvent("released","touch","levels-qa",x,y,0,0,1)
  end
  tap(); check(menu.index == 2 and not menu.submenu, "First touch selects the second compact row")
  tap(); check(menu.submenu ~= nil, "Second touch opens native actions")
  U.wait(2)
  check(U.shot(game,os.getenv("SHOT_DIR").."/actions-phone-4x3.png"), "native actions screenshot")
  press("b"); check(not menu.submenu and game.stack:top()==menu, "B returns to the roster")
  check(not love.window.hasFocus() and love.audio.getVolume()==0,"muted and unfocused")
  print("[DISCORD QA] PASS "..checks.." Gen2 level/detail checks")
  love.event.quit(0)
end
