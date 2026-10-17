-- Native Gen 2 battle integration. Gold already owns coloured HP/EXP bars and
-- caught markers, so the useful addition here is the one its cartridge HUD
-- omits: keep the level visible beside a three-letter status condition.
return function(mod)
  local Chrome = require("src.ui.gen2.Chrome")
  local Font = require("src.render.Font")
  local nativePaletteGlyphs = Chrome.paletteGlyphs
  local nativeRectangle = love.graphics.rectangle

  -- Keep native message pages/reveal/input; only make its existing wrapping
  -- split overlong words on real glyph boundaries. The scoped Chrome override
  -- cannot affect other screens and is restored even if a provider throws.
  local function installDialogueWrapping(screen, owner, active)
    if type(screen.showPages) ~= "function" or type(screen.syncTyper) ~= "function" then return end
    screen.modernGen2DialogueOwners = screen.modernGen2DialogueOwners or {}
    screen.modernGen2DialogueOwners[owner] = active
    if screen.modernGen2DialogueWrapped then return end
    screen.modernGen2DialogueWrapped = true
    for _, method in ipairs({ "showPages", "syncTyper" }) do
      local native = screen[method]
      screen[method] = function(self, ...)
        local enabled = false
        for _, test in pairs(self.modernGen2DialogueOwners or {}) do
          if test() then enabled = true; break end
        end
        if not enabled or not Font.split or not Font.spansFitting then
          return native(self, ...)
        end
        local wrap = Chrome.wrap
        Chrome.wrap = function(text, tiles)
          local out, budget = {}, math.max(8, (tiles or 20) * 8)
          for _, line in ipairs(wrap(text, tiles)) do
            while Font.width(line) > budget do
              local spans = Font.split(line)
              local count = math.max(1, Font.spansFitting(spans, budget))
              -- A macro may expand several glyphs from one byte; keep every
              -- span of that source token together instead of duplicating it.
              local last = spans[count] and spans[count].to
              if not last then break end
              while spans[count + 1] and spans[count + 1].to == last do count = count + 1 end
              out[#out + 1] = line:sub(1, last)
              line = line:sub(last + 1)
              if line == "" then break end
            end
            if line ~= "" then out[#out + 1] = line end
          end
          return out
        end
        local result = { pcall(native, self, ...) }
        Chrome.wrap = wrap
        if not result[1] then error(result[2], 0) end
        return unpack(result, 2)
      end
    end
  end
  local Runtime = require("src.mods.Runtime")

  -- The enhanced labels are an overlay, not tilemap replacements. Draw only
  -- their ink so an eventual coloured/custom battle surface is never punched
  -- back to the cartridge text-box white behind each character.
  local function printInk(text, tx, ty)
    local palette, drawGlyph, finish = Chrome.paletteGlyphs({
      { 255, 255, 255 }, { 170, 170, 170 }, { 85, 85, 85 }, { 0, 0, 0 },
    }, false, true)
    if not palette then
      love.graphics.setColor(0, 0, 0, 1)
      return Font.draw(text, tx * 8, ty * 8)
    end
    local pen = tx * 8
    for _, code in ipairs(Font.encode(text)) do
      drawGlyph(code, pen, ty * 8)
      pen = pen + Font.advanceOf(code)
    end
    finish()
    return pen - tx * 8
  end

  local function printInkPx(text, x, y, color)
    color = color or { 0, 0, 0 }
    local ink = {}
    for i = 1, 3 do ink[i] = math.floor((color[i] or 0) * 255 + 0.5) end
    local _, drawGlyph, finish = Chrome.paletteGlyphs({
      { 255, 255, 255 },
      { math.floor((255 + ink[1]) / 2), math.floor((255 + ink[2]) / 2),
        math.floor((255 + ink[3]) / 2) },
      { math.floor(ink[1] / 2), math.floor(ink[2] / 2),
        math.floor(ink[3] / 2) }, ink,
    }, false, true)
    if not drawGlyph then
      love.graphics.setColor(color[1], color[2], color[3], 1)
      return Font.draw(text, math.floor(x), math.floor(y))
    end
    local pen = math.floor(x)
    for _, code in ipairs(Font.encode(text or "")) do
      drawGlyph(code, pen, math.floor(y))
      pen = pen + Font.advanceOf(code)
    end
    finish()
    return pen - math.floor(x)
  end

  local function panel(x, y, w, h)
    local G = love.graphics
    G.setColor(1, 1, 1, 1)
    G.rectangle("fill", x, y, w, h)
    G.setColor(0.05, 0.05, 0.06, 1)
    G.setLineWidth(2)
    G.rectangle("line", x + 1, y + 1, w - 2, h - 2)
  end

  local function drawChoices(screen, width, palette)
    screen.modernBattleChoiceBounds = nil
    local fields = { ["ask-nickname"] = "nicknameIndex", ["ask-shift"] = "shiftIndex",
      ["ask-next-mon"] = "nextMonIndex", ["ask-forget"] = "forgetChoice",
      ["stop-learning"] = "forgetChoice" }
    local field = fields[screen.phase]
    if not field or (screen.messageTimer or 0) > 0 then return end
    local Strings = require("src.core.Strings")
    palette = palette or Chrome.DEFAULT_BOX_PALETTE
    -- Match native YesNoBox positions and its actual selection fields. This
    -- is temporary prompt chrome, not a second input/controller path.
    local left = (screen.phase == "ask-shift" or screen.phase == "ask-next-mon")
      and 1 or (width - 48) / 8
    Chrome.paletteBox(left, 7, 6, 5, palette)
    Chrome.printThrough(Strings("YES"), left + 2, 8, palette)
    Chrome.printThrough(Strings("NO"), left + 2, 10, palette)
    Chrome.cursorThrough(left + 1, screen[field] == 1 and 8 or 10, palette)
    screen.modernBattleChoiceBounds = { x = left * 8, y = 56, w = 48, h = 40,
      index = screen[field], phase = screen.phase }
  end

  local function drawWideBottom(screen, width)
    local G = love.graphics
    screen.modernBattleChoiceBounds = nil
    local y, h = 104, 40
    if screen.phase == "moves" or screen.phase == "moveSelect" then
      -- Typed Move Colors replaces this bed with four colour cards.  Keeping
      -- it dark also gives a legible neutral surface when that companion mod
      -- is disabled or a move slot is empty.
      G.setColor(0.08, 0.09, 0.12, 1)
      G.rectangle("fill", 0, y, width, h)
      return
    end
    if screen.phase == "menu" then
      -- Reserve enough room for two native command columns, then wrap the
      -- prompt inside whatever remains.  Mid-wide 4:3 windows are the tight
      -- case: a one-line "What will <name> do?" used to run straight through
      -- the cursor and FIGHT label there.
      local menuWidth = math.max(88, math.min(112,
        math.floor(width * 0.44)))
      local split = width - menuWidth
      -- One continuous battle panel.  The old pair of separately framed
      -- halves put a full-height black join near the centre of ultrawide
      -- screens, which looked like the battle renderer had torn in two.
      panel(0, y, width, h)
      local prompt = screen.message or "What will you do?"
      local maxTiles = math.max(6, math.floor((split - 16) / 8))
      local lines = Chrome.wrap(prompt, maxTiles)
      if #lines > 2 then
        -- A very long nickname cannot fit alongside four commands in forty
        -- pixels of height.  Use the cartridge-neutral compact wording
        -- instead of clipping through the menu or drawing a third line.
        lines = Chrome.wrap("What will you do?", maxTiles)
      end
      if #lines > 2 then lines = { "What", "now?" } end
      for i = 1, math.min(2, #lines) do
        printInkPx(lines[i], 8, y + 4 + (i - 1) * 16)
      end
      screen.modernBattlePromptLines = math.min(2, #lines)
      local labels = type(screen.menuLabels) == "function"
        and screen:menuLabels() or { "FIGHT", "PKMN", "PACK", "RUN" }
      local areaW = width - split
      local colW = math.floor(areaW / 2)
      for i, label in ipairs(labels) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local x = split + 8 + col * colW
        local ty = y + 8 + row * 16
        if i == (screen.menuIndex or 1) then printInkPx("▶", x - 9, ty) end
        printInkPx(label, x, ty)
      end
      screen.modernBattleContinuousPanel = true
      return
    end
    panel(0, y, width, h)
    if type(screen.syncTyper) == "function" then screen:syncTyper() end
    local lines = type(screen.messageLines) == "function" and screen:messageLines()
      or Chrome.wrap(screen.message or "", math.floor((width - 16) / 8))
    screen.modernBattleDialogueLines = lines
    for i = 1, math.min(2, #lines) do
      printInkPx(lines[i], 8, y + 4 + (i - 1) * 16)
    end
    if type(screen.messageArrowVisible) == "function" and screen:messageArrowVisible() then
      printInkPx("▼", width - 14, 132)
    end
    drawChoices(screen, width)
    -- The native bottom pass also paints the level-up stat confirmation
    -- above the dialogue. Keep its renderer and A/B-controlled lifetime.
    if screen.phase == "stats-box" and screen.statsBoxMon
        and type(screen.drawStatsBox) == "function" then
      G.push("all")
      G.translate(math.floor((width - 160) / 2), 0)
      screen:drawStatsBox(screen.statsBoxMon, 0)
      G.pop()
    end
    -- drawWideBattle suppresses the native bottom pass, which also owns the
    -- four-slot forget list above the dialogue. Restore that native list:
    -- otherwise A confirms an invisible cursor (initially slot one).
    if screen.phase == "choose-forget" and (screen.messageTimer or 0) <= 0 then
      local learn = screen.pendingLearn
      local mon = learn and screen.battle and screen.battle.party[learn.index]
      local moves = mon and mon.moves or screen:playerMoves()
      G.push("all")
      G.translate(math.floor((width - 160) / 2), 0)
      require("src.ui.gen2.ForgetMoveList").draw(moves, screen.forgetIndex,
        screen.game.data.moves, Chrome.DEFAULT_BOX_PALETTE)
      G.pop()
    end
  end

  -- A full-window battle presenter may already have wrapped the Gen 2 class
  -- before this component decorates the individual screen.  The suite keeps
  -- that function in classicGen2BattleWidescreen below; when Stadium owns the
  -- live fight, call it instead of replacing its 3D scene with our stock
  -- centred capture.  Query at draw time because Stadium can be installed at
  -- boot but become active only after its model cache and battle session are
  -- ready.
  local function companionApi(id)
    if type(mod.find) ~= "function" then return false end
    local okHandle, handle = pcall(mod.find, id)
    return okHandle and handle and handle.exports or nil
  end

  local function external3DBattleActive(screen)
    local api = companionApi("STADIUM2_IMPORTER")

    if type(api) == "table"
        and type(api.getActiveBattleScene) == "function" then
      local okScene, scene = pcall(api.getActiveBattleScene)
      if okScene and type(scene) == "table" then
        return scene.screen == nil or scene.screen == screen
          or (screen and scene.battle == screen.battle)
      end
    end
    if type(api) == "table" and type(api.battleStatus) == "function" then
      local okStatus, status = pcall(api.battleStatus)
      if okStatus and type(status) == "table" and status.active == true then
        return true
      end
    end

    -- Battle Art 2.x's Gen 2 port has its own mod ID. Its public contract
    -- identifies the live SCREEN, while older adapters may identify the
    -- battle model. Query both exact identities; never treat an installed
    -- provider or a scene belonging to another fight as an active arena.
    for _, id in ipairs({ "BATTLE_ART_VOXEL_GEN2", "BATTLE_ART_VOXEL_FORK",
        "DRAMATIC_SHAPE", "DRAMALESS_SHAPE", "potato_voxel" }) do
      api = companionApi(id)
      local stage = type(api) == "table" and api.battleStage
      if type(stage) == "table" and type(stage.state) == "function" then
        for _, expected in ipairs({ screen, screen and screen.battle }) do
          local okState, state = pcall(stage.state, expected)
          local ownership = okState and type(state) == "table"
            and state.ownership or nil
          if type(ownership) == "table" and ownership.arena == true
              and state.staged == true
              and (state.battle == nil or state.battle == expected) then
            return true
          end
        end
      end
    end
    return false
  end

  local function drawWideBattle(screen, winW, winH)
    screen.modernBattleYieldedTo3D = nil
    screen.modernBattleViewport = nil
    -- The instance wrapper survives a live component toggle. Honour OFF on
    -- every draw, including the command menu and any later native battle.
    if mod.options:get("enabled") == false then
      return screen.classicGen2BattleWidescreen(screen, winW, winH)
    end
    if external3DBattleActive(screen)
        and type(screen.classicGen2BattleWidescreen) == "function" then
      screen.modernBattleYieldedTo3D = true
      return screen.classicGen2BattleWidescreen(screen, winW, winH)
    end
    -- A disabled move renderer must leave real native move controls visible.
    -- The wide bed alone cannot display choices or their PP.
    local moving = screen.phase == "moves" or screen.phase == "moveSelect"
    local cards = mod.suite and mod.suite.enabled("typed_move_colors")
      and mod.suite.option("typed_move_colors", "battle_colors") ~= false
      and not mod.suite.option("typed_move_colors", "text_only")
    local nativeMoves = moving and not cards
    if nativeMoves and not (mod.suite and mod.suite.uiGeometry) then
      return screen.classicGen2BattleWidescreen(screen, winW, winH)
    end
    local G = love.graphics
    local scale = math.max(1, math.floor(math.min(winH / 144, winW / 160)))
    local width = math.max(160, math.min(640, math.floor(winW / scale)))
    if mod.suite and mod.suite.uiGeometry then
      local height
      width, height, scale = mod.suite.uiGeometry(screen, winW, winH, width, 144, scale)
    end
    screen.modernBattleLastWideWidth = width
    local ox = math.floor((winW - width * scale) / 2)
    local oy = math.floor((winH - 144 * scale) / 2)
    screen.modernBattleViewport = {w=winW,h=winH,width=width,scale=scale,x=ox,y=oy}
    if screen:bgMode() ~= "world" then
      G.setColor(1, 1, 1, 1)
      G.rectangle("fill", 0, 0, winW, winH)
    end

    if not screen.modernBattleCanvas then
      screen.modernBattleCanvas = G.newCanvas(160, 144, {dpiscale=1})
      screen.modernBattleCanvas:setFilter("nearest", "nearest")
    end
    local previous = G.getCanvas()
    G.setCanvas(screen.modernBattleCanvas)
    G.clear(1, 1, 1, 1)
    G.push()
    G.origin()
    local bottomUIVisible = screen.bottomUIVisible
    if not nativeMoves then screen.bottomUIVisible = function() return false end end
    screen:drawSceneBody()
    screen.bottomUIVisible = bottomUIVisible
    G.pop()
    G.setCanvas(previous)

    G.push("all")
    G.setScissor(ox, oy, width * scale, 144 * scale)
    G.translate(ox, oy)
    G.scale(scale, scale)
    G.setColor(1, 1, 1, 1)
    G.rectangle("fill", 0, 0, width, 144)
    -- Never cut the Gen 2 field into regions.  Draw its complete native scene
    -- exactly once and centre it; only the controls below expand.  This is
    -- deliberately different from Gen 1's engine-owned semantic wide battle:
    -- a mod-level crop cannot safely infer animation, TYPE/PP or custom-art
    -- boundaries on every released Silver build.
    local sceneX = math.floor((width - 160) / 2)
    G.draw(screen.modernBattleCanvas, sceneX, 0)
    if not nativeMoves then drawWideBottom(screen, width) end
    screen.modernBattleWideWidth = width
    screen.modernBattleWide = width > 160
    screen.modernBattleKeptIntact = true
    screen.modernBattleSceneOffset = sceneX
    if Runtime.wantsHook("battle.overlay") then
      Runtime.call("battle.overlay", function() end, screen)
    end
    screen.modernBattleWideWidth = nil
    screen.modernBattleSceneOffset = nil
    G.pop()
    G.setColor(1, 1, 1, 1)
  end

  local function enabled()
    return mod.options:get("enabled") ~= false
  end

  local MeterText=mod:load("meters.lua")()
  local function installStagedHud(screen)
    local function active()
      -- Stadium's dedicated compositor already owns its HUD cards.
      return enabled() and not screen.stadium2ImporterBattleArtUiPass
        and external3DBattleActive(screen)
    end
    -- Keep the terrain visible: only the native HUD's ink gets an outline.
    -- Fresh glyph closures prevent a shadow shader leaking into the face.
    local function outlinedGlyphs(palette, invert, raw)
      local function colors(ink)
        local out = {}
        for i, color in ipairs(palette or Chrome.DEFAULT_BOX_PALETTE) do out[i] = color end
        out[4] = ink
        return out
      end
      local dark, light = colors({0,0,0}), colors({255,255,255})
      local pal = nativePaletteGlyphs(light, false, true)
      return pal or light, function(code, x, y)
        for _, offset in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
          local _, draw, finish = nativePaletteGlyphs(dark, false, true)
          if draw then draw(code,x+offset[1],y+offset[2]); finish()
          else
            love.graphics.setColor(0,0,0,1)
            Font.drawCode(code,x+offset[1],y+offset[2])
          end
        end
        local _, draw, finish = nativePaletteGlyphs(light, false, true)
        if draw then draw(code,x,y); finish()
        else love.graphics.setColor(1,1,1,1); Font.drawCode(code,x,y) end
      end, function() end
    end
    local function withOutlinedText(draw, self, popups, ...)
      local previous, printThrough, printRight, paletteBox = Chrome.paletteGlyphs,
        Chrome.printThrough, Chrome.printRightThrough, Chrome.paletteBox
      local function printText(text, tx, ty, palette, right)
        local width = Font.width(text)
        local x = tx*8 - (right and width or 0)
        local _, glyph, finish = outlinedGlyphs(palette)
        for _, code in ipairs(Font.encode(text)) do
          glyph(code,x,ty*8); x=x+Font.advanceOf(code)
        end
        finish()
        return width
      end
      -- Current Chrome printers inline their glyph shaders. Scope their
      -- entry points as well as paletteGlyphs so every text path agrees.
      Chrome.paletteGlyphs = outlinedGlyphs
      Chrome.printThrough = function(text,tx,ty,palette)
        return printText(text,tx,ty,palette,false)
      end
      Chrome.printRightThrough = function(text,tx,ty,palette)
        return printText(text,tx,ty,palette,true)
      end
      if popups and type(paletteBox) == "function" then
        Chrome.paletteBox = function(tx,ty,tw,th,palette)
          -- Only transient boxes above the dialogue: stat confirmation,
          -- Yes/No prompts and the move-forget list. Preserve the user's
          -- transparency choice for the main dialogue and command panels.
          if ty < 12 then
            local G=love.graphics
            G.push("all"); G.setShader(); G.setColor(0.10,0.12,0.16,1)
            nativeRectangle("fill",tx*8,ty*8,tw*8,th*8)
            G.pop()
            self.modernStagedPopupBounds={x=tx*8,y=ty*8,w=tw*8,h=th*8}
          end
          return paletteBox(tx,ty,tw,th,palette)
        end
      end
      self.modernStagedTextScopeActive = true
      love.graphics.push("all")
      local result = {pcall(draw,self,...)}
      love.graphics.pop()
      self.modernStagedTextScopeActive = nil
      Chrome.paletteGlyphs, Chrome.printThrough, Chrome.printRightThrough, Chrome.paletteBox =
        previous, printThrough, printRight, paletteBox
      if not result[1] then error(result[2],0) end
      return unpack(result,2)
    end
    -- Move cards own their ink. Other bottom UI keeps the native controller
    -- and box renderer, with the same outlined text as the upper HUD.
    screen.modernBattleOutlineBottom = function(native)
      return function(self, ...)
        if self.modernStagedTextScopeActive then return native(self,...) end
        self.modernStagedDialogueOutlined = nil
        self.modernStagedPopupBounds = nil
        if not active() or self.phase == "moves" or self.phase == "moveSelect" then
          return native(self,...)
        end
        local result = {withOutlinedText(native,self,true,...)}
        self.modernStagedDialogueOutlined = true
        return unpack(result)
      end
    end
    if type(screen.drawBottom) == "function" then
      screen.drawBottom = screen.modernBattleOutlineBottom(screen.drawBottom)
    end
    for _, side in ipairs({"enemy","player"}) do
      local method = side == "enemy" and "drawEnemyHud" or "drawPlayerHud"
      local native = screen[method]
      if type(native) == "function" then
        screen[method] = function(self, ...)
          local mon = self:activeMon(side)
          local visible = mon and active() and self:statusHUDVisible()
            and (side == "enemy" and self.showEnemyHud or side == "player" and self.showPlayerHud)
            and not self:hudCleared(side)
          if side == "enemy" then
            self.modernStagedEnemyMeter, self.modernStagedCaughtOutlined = nil,nil
          end
          self.modernStagedLevels = self.modernStagedLevels or {}
          self.modernStagedLevels[side] = false
          if not visible then return native(self, ...) end
          local result = {withOutlinedText(function(active, ...)
            if side == "enemy" then love.graphics.translate(0,2) end
            local values = {native(active,...)}
            if active:statusTag(mon,side) then
              local level = side == "player" and (active.shownLevel or mon.level) or mon.level
              printInk("<LV>"..tostring(level or 1),10,side == "enemy" and 1 or 8)
              active.modernStagedLevels[side] = true
            end
            return unpack(values)
          end,self,false,...)}
          self.modernStagedHudOutlined = true
          return unpack(result)
        end
      end
    end
    local nativeHp = screen.drawHpBar
    if type(nativeHp) == "function" then
      screen.drawHpBar = function(self,mon,side,tx,ty,...)
        local result = nativeHp(self,mon,side,tx,ty,...)
        if side ~= "enemy" or not active()
            or mod.options:get("enemy_hp_counter") ~= true then return result end
        local maximum=mon.maxHp or (mon.stats and mon.stats.hp) or 1
        local hp=self:hudHp(mon,side)
        local G=love.graphics
        local rectangle=G.rectangle
        G.push("all"); G.setShader()
        -- Voxel keys out white HUD paper, including one-pixel rectangles.
        -- Draw the meter's white digits through the original primitive so
        -- that filter cannot discard their faces and leave only shadows.
        G.rectangle=nativeRectangle
        local rendered={pcall(MeterText.draw,self.game.data,
          {mon={hp=hp,stats={hp=maximum}},shownHP=hp},"HP",
          (tx+2)*8,ty*8+1,48,true,nil,false,true)}
        G.rectangle=rectangle; G.pop()
        if not rendered[1] then error(rendered[2],0) end
        self.modernStagedEnemyMeter=true
        return result
      end
    end
    local hud = screen.hud
    if not hud then return end
    local nativeCaught=hud.drawCaughtIcon
    if type(nativeCaught) == "function" and type(hud.drawTile) == "function" then
      hud.drawCaughtIcon=function(self,...)
        if not active() then return nativeCaught(self,...) end
        local drawTile=self.drawTile
        self.drawTile=function(owner,key,first,tile,tx,ty,colors,mirror)
          local G=love.graphics
          G.push("all")
          local result={pcall(function()
            local dark={{0,0,0},{0,0,0},{0,0,0},{0,0,0}}
            local light={{255,255,255},{255,255,255},{255,255,255},{255,255,255}}
            for _,offset in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
              G.push(); G.translate(offset[1],offset[2])
              local ok,err=pcall(drawTile,owner,key,first,tile,tx,ty,dark,mirror)
              G.pop(); if not ok then error(err,0) end
            end
            return drawTile(owner,key,first,tile,tx,ty,light,mirror)
          end)}
          G.pop()
          if not result[1] then error(result[2],0) end
          screen.modernStagedCaughtOutlined=true
          return unpack(result,2)
        end
        local result={pcall(nativeCaught,self,...)}
        self.drawTile=drawTile
        if not result[1] then error(result[2],0) end
        return unpack(result,2)
      end
    end
    for _, method in ipairs({"drawEnemyFrame","drawPlayerFrame"}) do
      local native = hud[method]
      if type(native) == "function" then
        hud[method] = function(self, ...)
          if active() then return end
          return native(self,...)
        end
      end
    end
    local nativeExp = hud.drawExpBar
    if type(nativeExp) == "function" then
      hud.drawExpBar = function(self, fraction, tx, ty, ...)
        if not active() then
          screen.modernStagedExpPixels, screen.modernStagedExpBounds = nil, nil
          return nativeExp(self,fraction,tx,ty,...)
        end
        local G = love.graphics
        local pixels = math.floor(math.max(0,math.min(1,fraction or 0))*64)
        local x,y = tx*8,ty*8+2
        G.push("all"); G.setShader()
        G.setColor(0.16,0.20,0.27,1); G.rectangle("fill",x,y,64,4)
        G.setColor(0.25,0.65,1,1)
        if pixels>0 then G.rectangle("fill",x+64-pixels,y+1,pixels,2) end
        screen.modernStagedExpPixels = pixels
        local sx,sy = G.transformPoint(x,y)
        local ex,ey = G.transformPoint(x+64,y+4)
        screen.modernStagedExpBounds = {x=sx,y=sy,w=ex-sx,h=ey-sy}
        G.pop()
        return true
      end
    end
  end

  mod.hooks:wrap("battle.overlay", function(next, screen)
    local result = next(screen)
    if not enabled() or type(screen) ~= "table" then return result end
    if type(screen.activeMon) ~= "function"
        or type(screen.statusTag) ~= "function" then return result end

    local visible = type(screen.statusHUDVisible) ~= "function"
      or screen:statusHUDVisible()
    if not visible then return result end

    local enemy = screen:activeMon("enemy")
    local player = screen:activeMon("player")
    local enemyStatus = enemy and screen:statusTag(enemy, "enemy")
    local playerStatus = player and screen:statusTag(player, "player")
    if mod.options:get("enemy_hp_counter")==true and enemy and screen.showEnemyHud
        and not screen.modernStagedEnemyMeter
        and (not screen.hudCleared or not screen:hudCleared("enemy")) then
      local M=MeterText
      local hp=screen:hudHp(enemy,"enemy")
      local maximum=enemy.maxHp or (enemy.stats and enemy.stats.hp) or 1
      local offset=screen.modernBattleSceneOffset or 0
      local G=love.graphics
      -- Native Gen 2 has a three-pixel bar: replace that row with the
      -- suite's seven-pixel meter so the five-pixel digits stay inside it.
      G.setColor(1,1,1,1)
      G.rectangle("fill",offset+16,16,72,8)
      M.draw(screen.game.data,{mon={hp=hp,stats={hp=maximum}},shownHP=hp},
        "HP",offset+32,17,48,true,nil,false)
    end
    local wasBattle = Font.useBattleExtra(true)

    -- The native status tags occupy the level cells. These two free cells are
    -- the same side-by-side treatment Battle Info HUD uses on Gen 1.
    local wideOffset = math.max(0, (screen.modernBattleWideWidth or 160) - 160)
    local sceneOffset = math.max(0, screen.modernBattleSceneOffset or 0)
    local enemyOffset = math.floor((sceneOffset + 4) / 8)
    local playerOffset = sceneOffset > 0 and enemyOffset
      or math.floor(wideOffset / 8)
    if enemyStatus and screen.showEnemyHud
        and not (screen.modernStagedLevels and screen.modernStagedLevels.enemy)
        and (type(screen.hudCleared) ~= "function"
          or not screen:hudCleared("enemy")) then
      printInk("<LV>" .. tostring(enemy.level or 1), 10 + enemyOffset, 1)
    end
    if playerStatus and screen.showPlayerHud
        and not (screen.modernStagedLevels and screen.modernStagedLevels.player)
        and (type(screen.hudCleared) ~= "function"
          or not screen:hudCleared("player")) then
      printInk("<LV>" .. tostring(
        screen.shownLevel or player.level or 1),
        10 + playerOffset, 8)
    end

    -- Gold/Silver/Crystal already draw the native EXP track.  Do not add a
    -- second label beside it: on the centred Gen 2 field there is no spare
    -- tile cell that is valid for every nickname, HUD state and aspect ratio.
    -- Keeping the native track unlabelled also matches the cartridge battle
    -- HUD and prevents the text from drifting over the player sprite.
    Font.useBattleExtra(wasBattle)
    love.graphics.setColor(1, 1, 1, 1)
    screen.battleInfoHudGen2 = true
    return result
  end, 1000)

  mod.events:on("screen.pushed", function(event)
    local screen = type(event) == "table" and event.state or nil
    if type(screen) ~= "table" or screen.screenId ~= "Gen2BattleState"
        or screen.modernBattleWideInstalled then return end
    installDialogueWrapping(screen, "battle_hud", enabled)
    installStagedHud(screen)
    screen.modernBattleDrawChoices = function(self, palette)
      return drawChoices(self, self.modernBattleWideWidth or self.modernBattleLastWideWidth or 160, palette)
    end
    screen.modernBattleWideInstalled = true
    screen.classicGen2BattleWidescreen = screen.drawWidescreen
    screen.drawWidescreen = drawWideBattle
    local panelSize, panelScale = screen.panelSize, screen.battlePanelScale
    screen.panelSize = function(self)
      local viewport = self.modernBattleViewport
      if viewport then return viewport.width, 144 end
      return panelSize(self)
    end
    screen.battlePanelScale = function(self, w, h)
      local viewport = self.modernBattleViewport
      if viewport and viewport.w == w and viewport.h == h then return viewport.scale end
      return panelScale(self, w, h)
    end
    if mod.suite and mod.suite.guardWideDraw then mod.suite.guardWideDraw(screen) end
  end, 1000)

  mod.exports.generation = 2
  mod.log:info("native Gen 2 battle information overlay enabled")
end
