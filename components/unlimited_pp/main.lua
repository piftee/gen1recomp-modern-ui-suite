-- Optional player-side Unlimited PP. The engine's own move restrictions,
-- effects and turn controller stay authoritative; this module only gives
-- eligible player moves a temporary usable PP value while those native paths
-- run, then restores the exact stored value before returning.
return function(mod)
  mod.options:define({
    { key = "enabled", label = "UNLIMITED PP", type = "toggle",
      default = false },
  })

  local function enabled()
    return mod.options:get("enabled") == true
  end

  local function setEnabled(game, value)
    if mod.suite and mod.options and type(mod.options.set) == "function" then
      return mod.options:set(game, "enabled", value == true)
    end
    local saveOptions = game and game.save and game.save.options
    if saveOptions then
      saveOptions.modOptions = saveOptions.modOptions or {}
      saveOptions.modOptions[mod.id] = saveOptions.modOptions[mod.id] or {}
      saveOptions.modOptions[mod.id].enabled = value == true
    end
    local loader = game and game.mods
    if loader then
      loader.modOptions = loader.modOptions or {}
      loader.modOptions[mod.id] = loader.modOptions[mod.id] or {}
      loader.modOptions[mod.id].enabled = value == true
      if loader.events then
        loader.events:emit("mod.options_changed", {
          mod = mod.id, key = "enabled", value = value == true,
        })
      end
    end
    return true
  end

  -- The Suite has its own QoL hub entry. A standalone install gets the same
  -- single On/Off control in the game's ordinary Options list.
  if not mod.suite then
    mod.hooks:wrap("ui.options.rows", function(next, game, rows)
      local out = next(game, rows)
      if type(out) ~= "table" then return out end
      out[#out + 1] = {
        id = "unlimited_pp",
        label = "UNLIMITED PP",
        value = function() return enabled() and "ON" or "OFF" end,
        step = function(activeGame)
          setEnabled(activeGame, not enabled())
          -- Gen 2's custom Options rows return immediately after `step`, so
          -- they do not pass through the native menu's later save branch.
          -- Persist this one preference here; no progress/save data is
          -- written or touched.
          if activeGame and type(activeGame.writeOptions) == "function" then
            activeGame:writeOptions()
          end
          return true
        end,
      }
      return out
    end)
  end

  local unpackValues = table.unpack or unpack
  local function preservePP(moves, makeUsable, callback, ...)
    local saved = {}
    for _, move in ipairs(moves or {}) do
      if type(move) == "table" then
        saved[#saved + 1] = { move = move, pp = move.pp }
        if makeUsable and (tonumber(move.pp) or 0) <= 0 then move.pp = 1 end
      end
    end
    local result = { pcall(callback, ...) }
    for index = #saved, 1, -1 do
      saved[index].move.pp = saved[index].pp
    end
    if not result[1] then error(result[2], 0) end
    return unpackValues(result, 2, #result)
  end

  -- Keep the native PP readout honest. Stored PP is deliberately left alone,
  -- so displaying (for example) 0/35 would otherwise suggest that the move
  -- cannot be selected. This PP-only substitution borrows the engine's own
  -- printer while the native move screen draws, then adds a tiny bitmap glyph;
  -- it has no Modern UI dependency and restores the printer after draw errors.
  local function infinitePPLayout(value, move, def)
    if type(value) ~= "string" or type(move) ~= "table" then return nil end
    local current = math.max(0, math.floor(tonumber(move.pp) or 0))
    local maximum = tonumber(move.maxPp)
    if maximum == nil and def then
      local base = tonumber(def.pp)
      if base then
        maximum = base + (tonumber(move.ppUps) or 0) * math.floor(base / 5)
      end
    end
    maximum = math.max(0, math.floor(maximum or 0))
    local compact = ("%d/%d"):format(current, maximum)
    local padded = ("%2d/%2d"):format(current, maximum)
    local function layout(prefix, field)
      -- Nine deliberately-authored pixels, centred inside the native PP
      -- fraction's cell run. This avoids depending on a Unicode glyph that
      -- the ROM bitmap font does not contain.
      return {
        blank = prefix .. string.rep(" ", #field),
        glyphX = #prefix * 8 + math.floor((#field * 8 - 9) / 2),
      }
    end
    if value == padded then return layout("", padded) end
    if value == compact then return layout("", compact) end
    if value == "PP " .. padded then return layout("PP ", padded) end
    if value == "PP " .. compact then return layout("PP ", compact) end
    local tail = "PP " .. compact
    if #value > #tail and value:sub(-#tail) == tail then
      local prefix = value:sub(1, #value - #compact)
      return layout(prefix, compact)
    end
    return nil
  end

  -- The default Gen 1/2 font pages have no infinity character. Draw the same
  -- crisp 9x5 glyph in both generations instead of changing the global font:
  --   .##...##.
  --   #..#.#..#
  --   #...#...#
  --   #..#.#..#
  --   .##...##.
  local INFINITY_RUNS = {
    { 1, 2, 6, 7 }, { 0, 0, 3, 3, 5, 5, 8, 8 },
    { 0, 0, 4, 4, 8, 8 }, { 0, 0, 3, 3, 5, 5, 8, 8 },
    { 1, 2, 6, 7 },
  }
  local function drawInfinity(x, y, ink)
    local G = love and love.graphics
    if not (G and type(G.rectangle) == "function") then return false end
    if type(G.push) == "function" then G.push("all") end
    if ink then
      G.setColor(ink[1] / 255, ink[2] / 255, ink[3] / 255, 1)
    else
      G.setColor(0, 0, 0, 1)
    end
    for row, runs in ipairs(INFINITY_RUNS) do
      for index = 1, #runs, 2 do
        local first, last = runs[index], runs[index + 1]
        G.rectangle("fill", x + first, y + row - 1, last - first + 1, 1)
      end
    end
    if type(G.pop) == "function" then G.pop() end
    return true
  end

  local function withInfinitePPPrinter(owner, key, move, def, accepts,
      renderInfinity, callback, ...)
    local original = owner and owner[key]
    if type(original) ~= "function" then return callback(...) end
    owner[key] = function(value, ...)
      local layout = accepts(value, ...)
        and infinitePPLayout(value, move, def) or nil
      if layout then return renderInfinity(original, layout, value, ...) end
      return original(value, ...)
    end
    local result = { pcall(callback, ...) }
    owner[key] = original
    if not result[1] then error(result[2], 0) end
    return unpackValues(result, 2, #result)
  end

  local GameVersion = require("src.core.GameVersion")
  local generation = type(GameVersion.generation) == "function"
      and GameVersion.generation() or 1
  local activeFor

  if generation == 2 then
    local Battle = require("src.battle.gen2.Battle")
    local BattleState = require("src.ui.gen2.BattleState")
    local Chrome = require("src.ui.gen2.Chrome")
    local patch = rawget(Battle, "_unlimitedPPPatch")

    if not patch then
      patch = {
        hasUsableMoves = Battle.hasUsableMoves,
        forcedMove = Battle.forcedMove,
        usableMoves = Battle.usableMoves,
        checkObedience = Battle.checkObedience,
        useMove = Battle.useMove,
        spite = Battle.MOVE_EFFECTS and Battle.MOVE_EFFECTS.EFFECT_SPITE,
        chooseMove = BattleState.chooseMove,
        drawMoveInfoBox = BattleState.drawMoveInfoBox,
      }
      rawset(Battle, "_unlimitedPPPatch", patch)

      Battle.modUnlimitedPP = function(self, mon)
        return patch.activeFor and patch.activeFor(self, mon) or false
      end

      Battle.hasUsableMoves = function(self, mon)
        if self:modUnlimitedPP(mon) then
          local disabled = mon and mon.volatile and mon.volatile.disabled
          for _, move in ipairs((mon and mon.moves) or {}) do
            if move.id ~= disabled then return true end
          end
          return false
        end
        return patch.hasUsableMoves(self, mon)
      end

      Battle.forcedMove = function(self, mon)
        if self:modUnlimitedPP(mon) then
          return patch.preservePP(mon and mon.moves, true,
            patch.forcedMove, self, mon)
        end
        return patch.forcedMove(self, mon)
      end

      Battle.usableMoves = function(self, mon)
        if self:modUnlimitedPP(mon) then
          return patch.preservePP(mon and mon.moves, true,
            patch.usableMoves, self, mon)
        end
        return patch.usableMoves(self, mon)
      end

      Battle.checkObedience = function(self, moveId)
        if self:modUnlimitedPP(self.player) then
          return patch.preservePP(self.player and self.player.moves, true,
            patch.checkObedience, self, moveId)
        end
        return patch.checkObedience(self, moveId)
      end

      Battle.useMove = function(self, attacker, defender, moveId)
        local move = attacker and self:findMove(attacker, moveId)
        if move and self:modUnlimitedPP(attacker) then
          return patch.preservePP({ move }, true, patch.useMove,
            self, attacker, defender, moveId)
        end
        return patch.useMove(self, attacker, defender, moveId)
      end

      -- Gen 2 Spite writes directly into the live party move record. Run its
      -- native accuracy/RNG/message path, but restore player PP afterwards.
      if patch.spite then
        Battle.MOVE_EFFECTS.EFFECT_SPITE = function(self, attacker, defender,
            ...)
          if self:modUnlimitedPP(defender) then
            return patch.preservePP(defender and defender.moves, false,
              patch.spite, self, attacker, defender, ...)
          end
          return patch.spite(self, attacker, defender, ...)
        end
      end

      BattleState.chooseMove = function(self, index)
        local battle = self.battle
        local fighter = battle and battle.player
        local move = fighter and fighter.moves and fighter.moves[index]
        if move and battle:modUnlimitedPP(fighter)
            and not battle:moveDisabled(fighter, move.id) then
          return patch.preservePP({ move }, true, patch.chooseMove, self, index)
        end
        return patch.chooseMove(self, index)
      end

      -- Hook the native PP panel itself rather than the enclosing battle draw.
      -- That keeps the substitution in the precise PP context and also covers
      -- background-rendered frames, where another mod may wrap BattleState.draw.
      BattleState.drawMoveInfoBox = function(self, move, ...)
        local battle = self and self.battle
        local fighter = battle and battle.player
        if move and battle:modUnlimitedPP(fighter)
            and not battle:moveDisabled(fighter, move.id) then
          local def = self.game and self.game.data and self.game.data.moves
            and self.game.data.moves[move.id]
          return patch.withInfinitePPPrinter(Chrome, "printThrough", move,
            def, function(_, tx, ty) return tx == 5 and ty == 11 end,
            function(original, layout, _, tx, ty, palette, invert, raw)
              local result = original(layout.blank, tx, ty, palette, invert, raw)
              local ink
              if palette and type(Chrome.throughPalette) == "function" then
                local ok, resolved = pcall(Chrome.throughPalette, palette,
                  invert)
                ink = ok and resolved and resolved[4] or nil
              end
              if patch.drawInfinity(tx * 8 + layout.glyphX, ty * 8 + 1,
                  ink) then
                patch.infinityDrawCount = (patch.infinityDrawCount or 0) + 1
              end
              return result
            end,
            patch.drawMoveInfoBox, self, move, ...)
        end
        return patch.drawMoveInfoBox(self, move, ...)
      end
    end

    activeFor = function(battle, mon)
      -- Local-player-only PP would desynchronise the mirrored simulations in
      -- a link battle, so linked play deliberately keeps native PP rules.
      return enabled() and battle ~= nil and not battle.linkBattle
        and (mon == nil or mon == battle.player)
    end
    patch.activeFor = activeFor
    patch.preservePP = preservePP
    patch.withInfinitePPPrinter = withInfinitePPPrinter
    patch.drawInfinity = drawInfinity
  else
    local BattleState = require("src.battle.BattleState")
    local patch = rawget(BattleState, "_unlimitedPPPatch")

    if not patch then
      patch = {
        playerHasPP = BattleState.playerHasPP,
        update = BattleState.update,
        performMove = BattleState.performMove,
        draw = BattleState.draw,
      }
      rawset(BattleState, "_unlimitedPPPatch", patch)

      BattleState.modUnlimitedPP = function(self, battler)
        return patch.activeFor and patch.activeFor(self, battler) or false
      end

      BattleState.playerHasPP = function(self)
        if self:modUnlimitedPP(self.player) then
          for index in ipairs((self.player and self.player.curMoves) or {}) do
            if self.player.disabledSlot ~= index then return true end
          end
          return false
        end
        return patch.playerHasPP(self)
      end

      BattleState.update = function(self, ...)
        local input = self and self.input
          or (self and self.game and self.game.input)
        local selecting = self and self.phase == "moveSelect"
          and not self.moveSwapIndex and input
          and type(input.wasPressed) == "function" and input:wasPressed("a")
        local move = selecting and self.player and self.player.curMoves
          and self.player.curMoves[self.moveIndex]
        if move and self:modUnlimitedPP(self.player)
            and self.player.disabledSlot ~= self.moveIndex then
          return patch.preservePP({ move }, true, patch.update, self, ...)
        end
        return patch.update(self, ...)
      end

      BattleState.performMove = function(self, user, target, move, ...)
        if type(move) == "table" and not move.struggle
            and self:modUnlimitedPP(user) then
          return patch.preservePP({ move }, true, patch.performMove,
            self, user, target, move, ...)
        end
        return patch.performMove(self, user, target, move, ...)
      end


      BattleState.draw = function(self, ...)
        local move = self and self.phase == "moveSelect" and self.player
          and self.player.curMoves and self.player.curMoves[self.moveIndex]
        if move and self:modUnlimitedPP(self.player)
            and self.player.disabledSlot ~= self.moveIndex then
          local Font = require("src.render.Font")
          local def = self.data and self.data.moves
            and self.data.moves[move.id]
          return patch.withInfinitePPPrinter(Font, "draw", move, def,
            function(value, x, y)
              return (x == 40 and y == 88)
                or (x == 232 and y == 112
                  and type(value) == "string" and value:match("^PP%s"))
            end, function(original, layout, _, x, y, ...)
              local result = original(layout.blank, x, y, ...)
              if patch.drawInfinity(x + layout.glyphX, y + 1) then
                patch.infinityDrawCount = (patch.infinityDrawCount or 0) + 1
              end
              return result
            end, patch.draw, self, ...)
        end
        return patch.draw(self, ...)
      end
    end

    activeFor = function(battle, battler)
      if not (enabled() and battle and battle.kind ~= "link") then
        return false
      end
      return battler == nil or battler == battle.player
        or battler.isPlayer == true
    end
    patch.activeFor = activeFor
    patch.preservePP = preservePP
    patch.withInfinitePPPrinter = withInfinitePPPrinter
    patch.drawInfinity = drawInfinity
  end

  -- Visual companions can consume this without becoming a mechanics
  -- dependency. The display label is metadata; native bitmap-font layouts
  -- render the matching hand-pixelled infinity glyph described above.
  mod.exports.enabled = enabled
  mod.exports.activeFor = function(battle, mon) return activeFor(battle, mon) end
  mod.exports.label = "∞"
  mod.log:info("player-only Unlimited PP ready (default off; link battles native)")
end
