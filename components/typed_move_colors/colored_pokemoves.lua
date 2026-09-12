-- Colors to Pokémoves. Same seams as pokemove-colorfix: give f0 move
-- animation tiles a three-stop ramp from the move's elemental type.
-- Mid stops track Bulbapedia type-icon colors; highlight/edge keep a
-- falling brightness so 8x8 tiles do not invert.
return function(mod)
  local BattleState = require("src.battle.BattleState")
  local AnimPlayer = require("src.battle.AnimPlayer")

  local function enabled()
    local ok, value = pcall(mod.options.get, mod.options, "colored_pokemoves")
    return mod.options:enabled() and ok and value == true
  end

  -- highlight / body / edge. Body ≈ Bulbapedia type color.
  -- Normal #A8A878, Fire #F08030, Water #6890F0, Electric #F8D030,
  -- Grass #78C850, Ice #98D8D8, Fighting #C03028, Poison #A040A0,
  -- Ground #E0C068, Flying #A890F0, Psychic #F85888, Bug #A8B820,
  -- Rock #B8A038, Ghost #705898, Dragon #7038F8.
  local TYPES = {
    NORMAL   = { { 232, 232, 200 }, { 168, 168, 120 }, {  72,  72,  48 } },
    FIGHTING = { { 255, 176, 152 }, { 192,  48,  40 }, {  88,  16,  16 } },
    FLYING   = { { 216, 208, 255 }, { 168, 144, 240 }, {  64,  48, 120 } },
    POISON   = { { 224, 176, 224 }, { 160,  64, 160 }, {  72,  16,  72 } },
    GROUND   = { { 248, 232, 176 }, { 224, 192, 104 }, { 104,  72,  24 } },
    ROCK     = { { 232, 216, 144 }, { 184, 160,  56 }, {  80,  64,  16 } },
    BUG      = { { 216, 232, 120 }, { 168, 184,  32 }, {  64,  72,   8 } },
    GHOST    = { { 184, 168, 216 }, { 112,  88, 152 }, {  40,  24,  64 } },
    FIRE     = { { 255, 208, 144 }, { 240, 128,  48 }, { 136,  40,  16 } },
    WATER    = { { 176, 208, 255 }, { 104, 144, 240 }, {  32,  56, 136 } },
    GRASS    = { { 192, 240, 168 }, { 120, 200,  80 }, {  32,  88,  32 } },
    ELECTRIC = { { 255, 248, 176 }, { 248, 208,  48 }, { 136,  96,   8 } },
    PSYCHIC  = { { 255, 184, 208 }, { 248,  88, 136 }, { 120,  24,  64 } },
    ICE      = { { 208, 248, 248 }, { 152, 216, 216 }, {  48, 112, 128 } },
    DRAGON   = { { 184, 168, 255 }, { 112,  56, 248 }, {  40,  16, 112 } },
    DARK     = { { 160, 144, 136 }, { 112,  88,  72 }, {  40,  32,  24 } },
    STEEL    = { { 224, 224, 232 }, { 184, 184, 208 }, {  72,  72,  96 } },
    FAIRY    = { { 255, 216, 224 }, { 238, 153, 172 }, { 136,  64,  88 } },
  }

  local MOVES = {
    EXPLOSION    = TYPES.FIRE,
    SELFDESTRUCT = TYPES.FIRE,
    HYPER_BEAM   = { { 255, 196, 255 }, { 216, 104, 232 }, {  88,  16, 112 } },
  }

  local function rampForType(t)
    if type(t) ~= "string" or t == "" then return nil end
    return TYPES[t] or TYPES[(t:gsub("_TYPE$", ""))]
  end

  local function paletteFor(moveId, data)
    if not moveId then return nil end
    if MOVES[moveId] then return MOVES[moveId] end
    local moves = data and data.moves
    local def = moves and moves[moveId]
    if not def then return nil end
    return rampForType(def.type)
  end

  if not BattleState._suiteMoveColorOriginalDraw then
    BattleState._suiteMoveColorOriginalDraw = BattleState.drawAnimLayer
  end
  local originalDraw = BattleState._suiteMoveColorOriginalDraw
  function BattleState:drawAnimLayer(colorized)
    if enabled() and not colorized and self.wideLayout and self:wideLayout()
        and self:colorMode() then
      colorized = true
    end
    return originalDraw(self, colorized)
  end

  if not AnimPlayer._suiteMoveColorOriginalStart then
    AnimPlayer._suiteMoveColorOriginalStart = AnimPlayer.start
  end
  local originalStart = AnimPlayer._suiteMoveColorOriginalStart
  function AnimPlayer:start(moveId, attackerIsPlayer, opts)
    self._suiteMove = moveId
    return originalStart(self, moveId, attackerIsPlayer, opts)
  end

  if not BattleState._suiteMoveColorOriginalColors then
    BattleState._suiteMoveColorOriginalColors = BattleState.animSpriteColors
  end
  local originalColors = BattleState._suiteMoveColorOriginalColors
  local function norm(c) return { c[1] / 255, c[2] / 255, c[3] / 255 } end

  function BattleState:animSpriteColors(s, px, py)
    local obp = s and s.obp
    if not enabled() or (obp ~= "f0" and obp ~= "f0x") then
      return originalColors(self, s, px, py)
    end
    local ap = self.animPlayer
    local pal = ap and paletteFor(ap._suiteMove, self.data)
    if not pal then return originalColors(self, s, px, py) end
    local hi, mid, lo = pal[1], pal[2], pal[3]
    if obp == "f0x" then hi, mid = mid, hi end
    return { norm(hi), norm(mid), norm(lo) }
  end
end
