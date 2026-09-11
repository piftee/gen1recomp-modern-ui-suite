-- Collection history belongs to the save, independently of portrait choices.
return function(mod)
  local Dex, activeGame, elapsed = {}, nil, 0
  local function history(game, create)
    local save = game and game.save
    if type(save) ~= "table" then return nil end
    if create then
      save.modData = type(save.modData) == "table" and save.modData or {}
      save.modData[mod.id] = type(save.modData[mod.id]) == "table" and save.modData[mod.id] or {}
      save.modData[mod.id].shinyDex = type(save.modData[mod.id].shinyDex) == "table"
        and save.modData[mod.id].shinyDex or {}
    end
    local bucket = type(save.modData) == "table" and save.modData[mod.id]
    return type(bucket) == "table" and bucket.shinyDex
  end
  function Dex.isShiny(mon)
    if type(mon) ~= "table" or mon.isEgg then return false end
    if mon.shiny == true then return true end
    local dv = mon.dvs or {}
    local a = dv.attack or dv.atk
    return type(a) == "number" and a >= 0 and a <= 15 and a % 4 >= 2
      and (dv.defense or dv.def) == 10 and (dv.speed or dv.spd) == 10
      and (dv.special or dv.spc) == 10
  end
  function Dex.has(game, species)
    local found = history(game)
    return type(found) == "table" and found[species] == true or false
  end
  function Dex.record(game, mon, species)
    if not Dex.isShiny(mon) then return false end
    species = species or mon.species
    local def = game and game.data and game.data.pokemon and game.data.pokemon[species]
    if type(def) ~= "table" or not def.dex then return false end
    local found = history(game, true)
    if not found or found[species] then return false end
    found[species] = true
    return true
  end
  function Dex.reconcile(game)
    local save = game and game.save
    if type(save) ~= "table" then return 0 end
    local visited, added = {}, 0
    local function scan(value, depth)
      if type(value) ~= "table" or visited[value] or depth > 5 then return end
      visited[value] = true
      if value.species then
        if Dex.record(game, value) then added = added + 1 end
      else
        for _, child in pairs(value) do scan(child, depth + 1) end
      end
    end
    -- Only owned/historical containers. Seen flags, encounter data and story
    -- gifts cannot prove a shiny catch and must never fill missing history.
    for _, key in ipairs({"party", "boxes", "box", "daycare", "dayCare", "hallOfFame"}) do
      scan(save[key], 0)
    end
    return added
  end
  local function gameFor(event)
    local game = type(event) == "table" and (event.game or event.state and event.state.game)
    if game and game.save then activeGame = game end
    return activeGame
  end
  for _, name in ipairs({"game.ready", "save.loaded", "save.created", "screen.pushed"}) do
    mod.events:on(name, function(event) Dex.reconcile(gameFor(event)) end, -1000)
  end
  mod.events:on("pokemon.caught", function(event)
    local game = gameFor(event)
    if type(event) == "table" then Dex.record(game, event.mon, event.species) end
    Dex.reconcile(game)
  end, -1000)
  mod.events:on("pokemon.evolved", function(event)
    if type(event) ~= "table" then return end
    local game = gameFor(event)
    Dex.record(game, event.mon, event.fromSpecies)
    Dex.record(game, event.mon, event.toSpecies)
  end, -1000)
  mod.events:on("trade.completed", function(event)
    if type(event) ~= "table" then return end
    local game = gameFor(event)
    Dex.record(game, event.sent)
    Dex.record(game, event.received)
  end, -1000)
  mod.hooks:wrap("input.step", function(next, game, dt)
    if game and game.save then activeGame = game end
    elapsed = elapsed + math.max(0, tonumber(dt) or 0)
    if elapsed >= 0.5 then elapsed = elapsed % 0.5; Dex.reconcile(activeGame) end
    return next(game, dt)
  end, -1000)
  mod.hooks:wrap("save.write", function(next, game)
    Dex.reconcile(game or activeGame)
    return next(game)
  end, 1000)
  return Dex
end
