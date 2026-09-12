-- Colored Pokéballs. Same seams as pokeball-colorfix: wide anim layer,
-- per-ball toss palette and wide party rows.
-- Accent colors tuned toward the official art references (Poké orange-red,
-- Great blue, Ultra gold, Master purple, Safari olive).
return function(mod)
  local BattleState = require("src.battle.BattleState")
  local AnimPlayer = require("src.battle.AnimPlayer")

  local function enabled()
    local ok, value = pcall(mod.options.get, mod.options, "colored_pokeballs")
    return mod.options:enabled() and ok and value == true
  end

  -- body, top half, outline
  local BALLS = {
    POKE_BALL   = { { 248, 248, 248 }, { 232,  80,  40 }, { 24, 24, 24 } },
    GREAT_BALL  = { { 248, 248, 248 }, {  40, 128, 208 }, { 24, 24, 24 } },
    ULTRA_BALL  = { { 248, 248, 248 }, { 232, 188,  32 }, { 24, 24, 24 } },
    MASTER_BALL = { { 248, 248, 248 }, { 152,  56, 176 }, { 24, 24, 24 } },
    SAFARI_BALL = { { 248, 248, 248 }, { 104, 148,  56 }, { 24, 24, 24 } },
  }

  if not BattleState._suiteBallColorOriginalDraw then
    BattleState._suiteBallColorOriginalDraw = BattleState.drawAnimLayer
  end
  local originalDraw = BattleState._suiteBallColorOriginalDraw
  function BattleState:drawAnimLayer(colorized)
    if enabled() and not colorized and self.wideLayout and self:wideLayout()
        and self:colorMode() then
      colorized = true
    end
    return originalDraw(self, colorized)
  end

  local BALL_VISIBLE = {
    TOSS_ANIM = true, GREATTOSS_ANIM = true, ULTRATOSS_ANIM = true,
    SHAKE_ANIM = true,
  }

  if not AnimPlayer._suiteBallColorOriginalStart then
    AnimPlayer._suiteBallColorOriginalStart = AnimPlayer.start
  end
  local originalStart = AnimPlayer._suiteBallColorOriginalStart
  function AnimPlayer:start(moveId, attackerIsPlayer, opts)
    if opts and opts.ball then self._suiteBall = opts.ball end
    self._suiteBallVisible = BALL_VISIBLE[moveId] or false
    return originalStart(self, moveId, attackerIsPlayer, opts)
  end

  if not BattleState._suiteBallColorOriginalColors then
    BattleState._suiteBallColorOriginalColors = BattleState.animSpriteColors
  end
  local originalColors = BattleState._suiteBallColorOriginalColors
  local function norm(c) return { c[1] / 255, c[2] / 255, c[3] / 255 } end

  function BattleState:animSpriteColors(s, px, py)
    local obp = s and s.obp
    local ap = self.animPlayer
    if not enabled()
        or not (ap and ap._suiteBallVisible and (obp == "f0" or obp == "f0x")) then
      return originalColors(self, s, px, py)
    end
    local pal = BALLS[ap._suiteBall or "POKE_BALL"] or BALLS.POKE_BALL
    local body, top, edge = pal[1], pal[2], pal[3]
    if obp == "f0x" then body, top = top, body end
    return { norm(body), norm(top), norm(edge) }
  end

  local ICONS = {
    [0] = { { 248, 248, 248 }, { 232,  80,  40 }, { 24, 24, 24 } },
    [1] = { { 248, 248, 248 }, { 232, 188,  32 }, { 24, 24, 24 } },
    [2] = { { 152, 152, 152 }, {  92,  92,  92 }, { 24, 24, 24 } },
    [3] = nil,
  }
  local BALLS_PNG = "save/mod-derived/modern_ui_suite/battle/highlander_balls.png"
  local icons

  local function buildIcons()
    local ok, data = pcall(love.image.newImageData, BALLS_PNG)
    if not ok or not data then return false end
    local w, h = data:getDimensions()
    local out = love.image.newImageData(w, h)
    out:paste(data, 0, 0, 0, 0, w, h)
    out:mapPixel(function(x, _, r, g, b, a)
      if a == 0 then return r, g, b, a end
      local pal = ICONS[math.floor(x / 8)]
      if not pal then return r, g, b, a end
      local c
      if r > 0.83 then c = nil
      elseif r > 0.5 then c = pal[1]
      elseif r > 0.17 then c = pal[2]
      else c = pal[3] end
      if not c then return r, g, b, a end
      return c[1] / 255, c[2] / 255, c[3] / 255, a
    end)
    local ok2, img = pcall(love.graphics.newImage, out)
    if not ok2 or not img then return false end
    local set = { img = img }
    for i = 0, 3 do
      set[i] = love.graphics.newQuad(i * 8, 0, 8, 8, img:getDimensions())
    end
    return set
  end

  if not BattleState._suiteBallColorOriginalRow then
    BattleState._suiteBallColorOriginalRow = BattleState.drawBallRow
  end
  local originalRow = BattleState._suiteBallColorOriginalRow
  function BattleState:drawBallRow(party, x, y, dx)
    if not enabled() or not (self.wideLayout and self:wideLayout()) then
      return originalRow(self, party, x, y, dx)
    end
    if icons == nil then icons = buildIcons() end
    if not icons then return originalRow(self, party, x, y, dx) end
    for i = 1, 6 do
      local mon = party[i]
      local tile = not mon and 3 or mon.hp <= 0 and 2 or mon.status and 1 or 0
      love.graphics.draw(icons.img, icons[tile], x + (i - 1) * dx, y)
    end
  end

end
