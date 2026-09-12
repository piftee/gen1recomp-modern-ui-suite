return function(mod)
  mod.options:define({
    { key = "forgettable_hms", label = "FORGETTABLE HMS", type = "toggle",
      default = false },
    { key = "tms_forever", label = "TMS FOREVER", type = "toggle",
      default = false },
    { key = "instant_tmhm", label = "INSTANT TMS/HMS", type = "toggle",
      default = false },
    { key = "no_learn_hms", label = "NO LEARN HMS", type = "toggle",
      default = false },
    { key = "move_relearning", label = "MOVE RELEARNING", type = "toggle",
      default = false },
  })

  local function forgettableOn()
    local ok, value = pcall(mod.options.get, mod.options, "forgettable_hms")
    return mod.options:enabled() and ok and value == true
  end

  local function tmsForeverOn()
    local ok, value = pcall(mod.options.get, mod.options, "tms_forever")
    return mod.options:enabled() and ok and value == true
  end

  local function instantOn()
    local ok, value = pcall(mod.options.get, mod.options, "instant_tmhm")
    return mod.options:enabled() and ok and value == true
  end

  local function noLearnOn()
    local ok, value = pcall(mod.options.get, mod.options, "no_learn_hms")
    return mod.options:enabled() and ok and value == true
  end

  local function relearnOn()
    local ok, value = pcall(mod.options.get, mod.options, "move_relearning")
    return mod.options:enabled() and ok and value == true
  end

  local HM_MOVES = {
    CUT = true, FLY = true, SURF = true, STRENGTH = true, FLASH = true,
    WHIRLPOOL = true, WATERFALL = true,
  }

  local function isHmId(id)
    return type(id) == "string" and HM_MOVES[id] == true
  end

  local function isTmItem(data, itemId)
    if type(itemId) ~= "string" then return false end
    local item = data and data.items and data.items[itemId]
    local machine = item and item.machine
    if type(machine) == "table" then
      local kind = tostring(machine.kind or ""):lower()
      if kind == "hm" then return false end
      if kind == "tm" then return true end
    end
    return itemId:match("^TM%d") ~= nil or itemId:match("^TM_") ~= nil
  end

  local GV = require("src.core.GameVersion")
  local gen2 = GV.generation and GV.generation() == 2

  local function installLearnMenu()
    if gen2 then return end
    local ok, MoveLearnMenu = pcall(require, "src.ui.MoveLearnMenu")
    if not ok or type(MoveLearnMenu) ~= "table"
        or type(MoveLearnMenu.update) ~= "function" then
      return
    end
    if MoveLearnMenu._suiteForgettableHMs then return end
    MoveLearnMenu._suiteForgettableHMs = true
    local origUpdate = MoveLearnMenu.update
    function MoveLearnMenu:update(dt)
      local input = self.game and self.game.input
      if self.selecting and input and input.wasPressed and input:wasPressed("a")
          and not input:wasPressed("b") and not input:wasPressed("up") and not input:wasPressed("down")
          and type(self.index) == "number" and self.mon
          and type(self.mon.moves) == "table" then
        local old = self.mon.moves[self.index]
        if old and isHmId(old.id) then
          if forgettableOn() and self.newMoveId then
            local moves = self.game.data and self.game.data.moves
            local mdef = moves and moves[self.newMoveId]
            local oldDef = moves and moves[old.id]
            self.mon.moves[self.index] = {
              id = self.newMoveId,
              pp = mdef and mdef.pp or 0,
            }
            self.forgot = oldDef and oldDef.name or tostring(old.id)
            pcall(function()
              require("src.core.Sound").play(self.game.data, "Press_AB")
            end)
            if type(self.finish) == "function" then
              self:finish(true)
            end
            return
          end
          local TextBox = require("src.render.TextBox")
          local romText = require("src.core.RomText")
          self.game.stack:push(TextBox.new(self.game,
            romText(self.game.data, "_HMCantDeleteText",
              "HM techniques\ncan't be deleted!")))
          return
        end
      end
      return origUpdate(self, dt)
    end
  end

  local function installTms()
    if gen2 then return end
    local ok, ItemEffects = pcall(require, "src.inventory.ItemEffects")
    if not ok or type(ItemEffects) ~= "table" or type(ItemEffects.use) ~= "function" then
      return
    end
    if ItemEffects._suiteTmsForever then return end
    ItemEffects._suiteTmsForever = true
    local origUse = ItemEffects.use
    function ItemEffects.use(data, save, itemId, target, battle, moveIndex, ow)
      local result, payload, extra = origUse(data, save, itemId, target, battle, moveIndex, ow)
      if tmsForeverOn() and result == "learn" and isTmItem(data, itemId) then
        result = "learnkept"
      end
      return result, payload, extra
    end
  end

  local function installInstant()
    if gen2 then return end
    local ok, OverworldState = pcall(require, "src.world.OverworldController")
    if not ok or type(OverworldState) ~= "table" then return end
    if OverworldState._suiteInstantTmHm then return end
    OverworldState._suiteInstantTmHm = true

    local function tryInstantA(ow)
      if not instantOn() or not ow or not ow.player or ow.player.moving or ow.player.inputLocked then return false end
      local x,y=ow.player:facingCell()
      local facing=ow.npcAtCell and ow:npcAtCell(x,y)
      local sprite=facing and facing.def and facing.def.sprite
      if facing and sprite~="SPRITE_BOULDER" and sprite~="BOULDER" then return false end
      if type(ow.useCutFieldMove) == "function" and ow:useCutFieldMove() == "ok" then
        local fx, fy = ow.player:facingCell()
        if type(ow.tryCut) == "function" then ow:tryCut(fx, fy) return true end
      end
      if type(ow.useSurfFieldMove) == "function" and ow:useSurfFieldMove() == "ok" then
        local fx, fy = ow.player:facingCell()
        if type(ow.trySurf) == "function" then ow:trySurf(fx, fy) return true end
      end
      if type(ow.partyKnows) == "function" and ow:partyKnows("STRENGTH") then
        if not ow.strengthActive then
          local fx, fy = ow.player:facingCell()
          local npc = type(ow.npcAtCell) == "function" and ow:npcAtCell(fx, fy)
          local sprite = npc and npc.def and npc.def.sprite
          if sprite == "SPRITE_BOULDER" or sprite == "BOULDER" then
            mod.exports.useField(ow.game or require("src.core.Game"), "STRENGTH", ow:partyKnows("STRENGTH"))
            return true
          end
        end
      end
      return false
    end

    local DIG_TILESETS = {
      FOREST = true, CEMETERY = true, CAVERN = true,
      FACILITY = true, INTERIOR = true,
    }
    local function oakNotNow(game)
      local TextBox = require("src.render.TextBox")
      local name = game.save and game.save.player and game.save.player.name or "RED"
      local text = (game.data and game.data.text and game.data.text._ItemUseNotTimeText)
        or ("OAK: " .. name .. "!\nThis isn't the\ntime to use that!")
      if type(text) == "string" and text:find("%%s", 1, true) then
        text = text:format(name)
      end
      game.stack:push(TextBox.new(game, text))
    end
    local function isOutside(ow, game)
      local okMap, Map = pcall(require, "src.world.Map")
      local okField, FieldDefaults = pcall(require, "src.world.FieldDefaults")
      if okMap and Map and type(Map.isOutside) == "function" then
        local tilesets = okField and FieldDefaults.field
          and FieldDefaults.field(game.data, "outsideTilesets")
        return Map.isOutside(ow.map.def, tilesets)
      end
      local ts = ow.map and ow.map.def and ow.map.def.tileset
      return ts == "OVERWORLD" or ts == "PLATEAU"
    end
    local function openSelectMenu(ow)
      if not instantOn() or not ow then return false end
      local game = ow.game or require("src.core.Game")
      if game.stack and game.stack.top and game.stack:top() ~= ow then
        return false
      end
      local Menu = require("src.ui.Menu")
      local Screens = select(2, pcall(require, "src.ui.Screens"))
      local items = {}
      local function knows(move)
        return type(ow.partyKnows) == "function" and ow:partyKnows(move)
      end
      if knows("FLASH") then
        items[#items + 1] = {
          label = "FLASH",
          onSelect = function()
            if ow:partyKnows("FLASH") then
              mod.exports.useField(game, "FLASH", ow:partyKnows("FLASH"))
            end
          end,
        }
      end
      if knows("FLY") then
        items[#items + 1] = {
          label = "FLY",
          onSelect = function()
            if not isOutside(ow, game) then
              local TextBox = require("src.render.TextBox")
              local txt = (game.data and game.data.text and game.data.text._CannotFlyHereText)
                or "Can't FLY here."
              game.stack:push(TextBox.new(game, txt))
              return
            end
            if type(Screens) == "table" and type(Screens.push) == "function" then
              pcall(Screens.push, game, "TownMap", {
                fly = true,
                onFly = function(mapId)
                  if type(ow.flyTo) == "function" then ow:flyTo(mapId) end
                end,
              })
            end
          end,
        }
      end
      if knows("DIG") then
        items[#items + 1] = {
          label = "DIG",
          onSelect = function()
            local tileset = ow.map and ow.map.def and ow.map.def.tileset
            local mapId = ow.map and ow.map.id
            if not (DIG_TILESETS[tileset] and mapId ~= "AGATHAS_ROOM") then
              oakNotNow(game)
              return
            end
            if type(ow.beginTeleportOut) == "function" then
              ow:beginTeleportOut()
            end
          end,
        }
      end
      if knows("TELEPORT") then
        items[#items + 1] = {
          label = "TELEPORT",
          onSelect = function()
            if not isOutside(ow, game) then
              local TextBox = require("src.render.TextBox")
              local txt = (game.data and game.data.text
                and game.data.text._CannotUseTeleportNowText)
                or "Can't use TELEPORT now."
              game.stack:push(TextBox.new(game, txt))
              return
            end
            if type(ow.beginTeleportOut) == "function" then
              ow:beginTeleportOut()
            end
          end,
        }
      end
      if #items == 0 then return false end
      items[#items + 1] = { label = "CANCEL" }
      game.stack:push(Menu.new(game, items, {
        tx = 6, ty = 1, tw = 8, th = #items * 2 + 2,
      }))
      return true
    end

    if type(OverworldState.interact) == "function" then
      local origInteract = OverworldState.interact
      function OverworldState:interact()
        if tryInstantA(self) then return end
        return origInteract(self)
      end
    end
    if type(OverworldState.handleInput) == "function" then
      local origInput = OverworldState.handleInput
      function OverworldState:handleInput()
        local game = self.game or require("src.core.Game")
        local input = game and game.input
        if instantOn() and input and input.wasPressed
            and input:wasPressed("select")
            and self.player and not self.player.moving and not self.player.inputLocked then
          if openSelectMenu(self) then return end
        end
        return origInput(self)
      end
    end
  end

  local function installNoLearn()
    local FieldDefaults
    pcall(function() FieldDefaults = require("src.world.FieldDefaults") end)

    local function hmForMove(data, moveId)
      local cache = {}
      for id, def in pairs((data and data.items) or {}) do
        local m = type(def)=="table" and def.machine
        if type(m) == "table" then
          local kind = tostring(m.kind or "HM"):upper()
          local move = m.move or m.id
          if kind == "HM" and type(move) == "string" then
            cache[move] = id
          end
        end
        if type(id) == "string" and id:match("^HM_") then
          cache[id:gsub("^HM_", "")] = id
        end
      end
      return cache[moveId] or ("HM_" .. tostring(moveId))
    end

    local function ownsHm(save, hmId, moveId)
      if not save then return false end
      local keys = { hmId, "HM_" .. tostring(moveId), moveId }
      for _, bag in ipairs({ save.inventory or {}, save.bag and save.bag.TM_HM or {} }) do
        if type(bag) == "table" then
          for _, key in ipairs(keys) do
            local n = bag[key]
            if n == true or (type(n) == "number" and n > 0) then
              return true
            end
          end
        end
      end
      return false
    end

    local function badgeOwned(data, save, moveId)
      if not save then return false end
      if gen2 then
        local F = require("src.world.gen2.FieldMoves")
        return F.hasBadge(save, F.BADGE[moveId])
      end
      if FieldDefaults and type(FieldDefaults.constant) == "function" then
        local gate = (FieldDefaults.constant(data, "hmBadges") or {})[moveId]
        if gate and gate.badge then
          local b = save.inventory and save.inventory[gate.badge]
          return b == true or (type(b) == "number" and b > 0)
        end
      end
      local fallback = {
        CUT = "CASCADEBADGE", FLY = "THUNDERBADGE", SURF = "SOULBADGE",
        STRENGTH = "RAINBOWBADGE", FLASH = "BOULDERBADGE",
      }
      local badge = fallback[moveId]
      if not badge then return true end
      local b = save.inventory and save.inventory[badge]
      return b == true or (type(b) == "number" and b > 0)
    end

    local function canLearn(data, mon, moveId)
      if not mon or mon.isEgg or mon.egg then return false end
      local def = data and data.pokemon and data.pokemon[mon.species]
      for _, mv in ipairs((def and def.tmhm) or {}) do
        local id = mv
        if type(mv) == "table" then id = mv.id or mv.move or mv[1] end
        if id == moveId then return true end
      end
      return false
    end

    local function firstLearner(data, save, moveId)
      if not data or not save or not HM_MOVES[moveId] then return nil end
      if not badgeOwned(data, save, moveId) then return nil end
      local hmId = hmForMove(data, moveId)
      if not ownsHm(save, hmId, moveId) then return nil end
      for _, mon in ipairs(save.party or {}) do
        if canLearn(data, mon, moveId) then return mon end
      end
      return nil
    end

    pcall(function()
      mod.hooks:wrap("fieldmove.eligibility", function(nextFn, moveId, ctx)
        local mon = nextFn(moveId, ctx)
        if mon then return mon end
        if not noLearnOn() then return nil end
        ctx = ctx or {}
        local game = require("src.core.Game")
        return firstLearner(ctx.data or game.data, ctx.save or game.save, moveId)
      end)
    end)

    pcall(function()
      local ok, OverworldState = pcall(require, "src.world.OverworldController")
      if not ok or type(OverworldState) ~= "table" then return end
      if OverworldState._suiteNoLearnHMs then return end
      OverworldState._suiteNoLearnHMs = true
      local orig = OverworldState.partyKnows
      if type(orig) ~= "function" then return end
      function OverworldState:partyKnows(moveId)
        local mon = orig(self, moveId)
        if mon then return mon end
        if not noLearnOn() then return nil end
        local game = self.game or require("src.core.Game")
        return firstLearner(game.data, game.save, moveId)
      end
    end)

    mod.exports.firstLearner = firstLearner
    mod.exports.canLearn = canLearn
    pcall(function()
      local FIELD = {
        { move = "CUT", action = "cut" },
        { move = "SURF", action = "surf" },
        { move = "STRENGTH", action = "strength" },
        { move = "FLASH", action = "flash" },
        { move = "FLY", action = "fly" },
      }
      mod.hooks:wrap("ui.party.submenu", function(nextFn, g, items, mon, ctx)
        items = nextFn(g, items, mon, ctx) or {}
        if not noLearnOn() or not mon or (ctx and ctx.battle) then
          return items
        end
        local known = {}
        for _, row in ipairs(items) do
          if row.action then known[row.action] = true end
        end
        for _, field in ipairs(FIELD) do
          if not known[field.action] and canLearn(g.data, mon, field.move)
              and firstLearner(g.data, g.save, field.move) then
            items[#items + 1] = gen2
              and {id=field.move,label=field.move,fieldMove=true}
              or { label = field.move, action = field.action }
          end
        end
        return items
      end)
    end)
  end

  -- Follow the entire pre-evolution graph, with cycle and duplicate guards.
  local function relearnList(data, mon)
    local known, seenSpecies, seenMoves, out = {}, {}, {}, {}
    for _, move in ipairs(mon.moves or {}) do known[move.id] = true end
    local function add(id, level)
      level = tonumber(level) or 1
      if type(id) ~= "string" or not data.moves[id] or known[id]
          or seenMoves[id] or level > (mon.level or 1) then return end
      seenMoves[id] = true
      out[#out+1] = {id=id, level=level, label=data.moves[id].name or id}
    end
    local function visit(species)
      if seenSpecies[species] then return end
      seenSpecies[species] = true
      local def = data.pokemon[species] or {}
      for _, id in ipairs(def.level1Moves or def.baseMoves or {}) do add(id,1) end
      for _, row in ipairs(def.learnset or def.levelMoves or {}) do
        add(row.move or row[2], row.level or row[1])
      end
      local parents = {}
      for id, candidate in pairs(data.pokemon) do
        for _, evo in ipairs(type(candidate)=="table" and candidate.evolutions or {}) do
          if (evo.species or evo.into) == species then parents[#parents+1]=id end
        end
      end
      table.sort(parents)
      for _, id in ipairs(parents) do visit(id) end
    end
    visit(mon.species)
    table.sort(out,function(a,b) return a.level==b.level and a.id<b.id or a.level<b.level end)
    return out
  end
  local function openRelearn(game, mon)
    if mon.isEgg or mon.egg then return end
    local List = require("src.ui.ListMenu")
    local menu
    local function refresh()
      local items = relearnList(game.data,mon)
      for _, item in ipairs(items) do item.right = "L"..item.level end
      items[#items+1]={label="CANCEL",cancel=true}
      menu.items=items; menu.index=math.min(menu.index or 1,#items)
    end
    menu=List.new(game,"RELEARN",{}, {onChoose=function(item)
      if item.cancel then game.stack:pop(); return end
      if not relearnOn() then game.stack:pop(); return end
      if gen2 then
        game:learnMoveOn(mon,item.id,function() refresh() end)
      elseif #mon.moves < 4 then
        local def=game.data.moves[item.id]
        mon.moves[#mon.moves+1]={id=item.id,pp=def.pp}
        mod.events:emit("pokemon.move_learned",{mon=mon,moveId=item.id})
        game.stack:push(require("src.render.TextBox").new(game,
          (mon.nickname or mon.species).." learned\n"..item.label.."!",refresh))
      else
        require("src.ui.Screens").push(game,"MoveLearnMenu",mon,item.id,refresh)
      end
    end})
    menu.modernPartyRelearn=true
    refresh(); game.stack:push(menu)
  end
  mod.exports.relearnList=relearnList
  mod.exports.openRelearn=openRelearn
  mod.exports.useField=function(game, move, mon)
    if gen2 then return game.world:useFieldMove(move,mon) end
    -- The existing party controller owns every field animation and message.
    local Party=require("src.ui.PartyMenu")
    local page=Party.new(game)
    for i,m in ipairs(game.save.party) do if m==mon then page.index=i end end
    page.submenu=true;page.subIndex=1;page.subItems={{action=move:lower()}}
    game.stack:push(page)
    local input=game.input
    local proxy=setmetatable({wasPressed=function(_,key)return key=="a" end},{__index=input})
    game.input=proxy
    local ok,err=pcall(Party.update,page,0)
    game.input=input
    if not ok then error(err,0) end
  end
  mod.hooks:wrap("ui.party.submenu",function(next,g,items,mon,ctx)
    items=next(g,items,mon,ctx) or {}
    if not relearnOn() or not mon or mon.isEgg or mon.egg or (ctx and ctx.battle) then return items end
    for _,row in ipairs(items) do
      if row.relearn or row.action=="relearn" or row.id=="RELEARN" then return items end
    end
    table.insert(items,1,{id="RELEARN",label="RELEARN",relearn=true,
      onSelect=function(chosen,game)openRelearn(game or g,chosen or mon)end})
    return items
  end)
  installLearnMenu(); installTms(); installInstant(); installNoLearn()
  if gen2 then mod:load("gen2.lua")(mod) end
end
