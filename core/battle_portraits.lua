-- Shared front portraits for the Dex, summary and PC. Each adapter reads the
-- active provider's settings and its own artwork; nothing is bundled/copied.
-- Decode atlas cells before drawing and keep thumbnail frames still.
return function(mod)
  local frames, sheets, definitions, sequences, serial = {}, {}, {}, {}, 0
  local function remember(cache, key, value, limit)
    serial = serial + 1
    cache[key] = { value = value or false, used = serial }
    local count, oldest, age = 0, nil, math.huge
    for k, entry in pairs(cache) do
      count = count + 1
      if entry.used < age then oldest, age = k, entry.used end
    end
    if count > limit then cache[oldest] = nil end
    return value
  end
  local function cached(cache, key)
    local entry = cache[key]
    if not entry then return nil, false end
    serial = serial + 1; entry.used = serial
    return entry.value or nil, true
  end
  local function setting(value)
    return type(value) == "table" and type(value.get) == "function" and value:get()
  end
  local function provider()
    local generation = require("src.core.GameVersion").generation()
    local ids = generation == 2
      and { "BATTLE_ART_VOXEL_GEN2", "BATTLE_ART_VOXEL_FORK" }
      or { "BATTLE_ART_VOXEL_FORK", "BATTLE_ART_VOXEL_GEN2" }
    for _, id in ipairs(ids) do
      local handle = mod.find and mod.find(id)
      local exports = handle and handle.exports
      if exports then
        local art = exports.battleArt
        if not art and exports.lib and exports.lib.require then
          local ok, value = pcall(exports.lib.require, "BattleArt")
          if ok then art = value end
        end
        if art then return { battleArt = art, lib = exports.lib }, id end
      end
    end
  end
  local function frameIndex(def, animate)
    local count = def.cells and #def.cells or tonumber(def.autoColumns or def.frames)
    if not count or count < 1 or count % 1 ~= 0 then return nil end
    if not animate or count == 1 then return 1 end
    local total, durations = 0, def.durations or {}
    for i = 1, count do total = total + math.max(1, tonumber(durations[i]) or 100) end
    local time = love.timer and love.timer.getTime and love.timer.getTime() or 0
    local elapsed = (time * 1000) % total
    for i = 1, count do
      elapsed = elapsed - math.max(1, tonumber(durations[i]) or 100)
      if elapsed < 0 then return i end
    end
    return count
  end
  local function decode(path, def, index, tag, prepare)
    local key = table.concat({ path, tostring(def), tostring(tag), index }, "|")
    local image, hit = cached(frames, key)
    if hit then return image end
    local sheet, found = cached(sheets, path)
    if not found then
      local ok, data = pcall(love.image.newImageData, path)
      sheet = remember(sheets, path, ok and data or nil, 8)
    end
    if not sheet then return remember(frames, key, nil, 96) end
    local sw, sh = sheet:getDimensions()
    if not def then return remember(frames, key, prepare(sheet:clone()), 96) end
    local x, y, w, h
    if def.cells then
      local cell = def.cells[index]
      x, y, w, h = cell.x or 0, cell.y or 0, cell.width, cell.height
    elseif def.autoColumns then
      local columns = tonumber(def.autoColumns)
      if not columns or sw % columns ~= 0 then return nil end
      w, h = sw / columns, sh
      x, y = (index - 1) * w, 0
    else
      w, h = tonumber(def.width), tonumber(def.height)
      local columns = tonumber(def.columns)
      if not columns or columns < 1 or not w or not h then return nil end
      x, y = ((index - 1) % columns) * w, math.floor((index - 1) / columns) * h
    end
    if not w or not h or w < 1 or h < 1 or x < 0 or y < 0
        or x + w > sw or y + h > sh then return remember(frames, key, nil, 96) end
    local cell = love.image.newImageData(w, h)
    cell:paste(sheet, 0, 0, x, y, w, h)
    return remember(frames, key, prepare(cell), 96)
  end
  local function image(data)
    local out = love.graphics.newImage(data)
    out:setFilter("nearest", "nearest")
    return out
  end
  local function rootFor(game, id)
    -- find() is the enabled/export gate; Loader supplies the discovered root,
    -- including user-renamed install folders. No live provider files are edited.
    local record = game and game.mods and game.mods.mods and game.mods.mods[id]
    return record and record.path
  end
  local function dataFile(game, path)
    local value, hit = cached(definitions, path)
    if hit then return value end
    local fs = game.mods.fs or love.filesystem
    local source = fs.read(path)
    local chunk = source and (loadstring or load)(source, "@" .. path)
    if chunk and setfenv then setfenv(chunk, {}) end
    local ok, data = pcall(chunk or function() end)
    return remember(definitions, path, ok and type(data) == "table" and data or nil, 12)
  end
  local function shiny(mon)
    if mon.shiny == true then return true end
    local dv = mon.dvs or {}
    local a, d = dv.attack or dv.atk, dv.defense or dv.def
    return type(a) == "number" and a % 4 >= 2 and d == 10
      and (dv.speed or dv.spd) == 10 and (dv.special or dv.spc) == 10
  end
  local function battleArt(game, mon, animate)
    local exports, id = provider()
    local art = exports and exports.battleArt
    if not art or type(art.ownsSpeciesArt) ~= "function"
        or not art.ownsSpeciesArt() then return nil end
    local mode = setting(art.setting)
    if mode == "rom" then return nil end
    local battler = { species = mon.species, mon = mon, dvs = mon.dvs,
      shiny = mon.shiny, data = game and game.data and game.data.pokemon[mon.species] }
    if mode == "static" then return art.image(mon.species, "front", battler) end
    if mode ~= "animated" then return nil end
    local lib = exports.lib
    if not lib or type(lib.require) ~= "function" then return nil end
    local animation = lib.require("AnimatedBattleArt")
    if not animation or type(animation.definitionFor) ~= "function" then return nil end
    local generation = setting(art.frontAnimationSetting)
    local def = animation.definitionFor(battler, "front")
    if generation == "gen1" or (generation == "gen2" and not def) then
      return art.generationFrontImage(mon.species, generation, battler)
    end
    if not def or type(def.image) ~= "string" then return nil end
    local index = frameIndex(def, animate)
    if not index then return nil end
    local display = art.displayMode()
    return decode(lib.mod.assets:path(def.image), def, index, id .. tostring(display),
      function(cell) return art.prepareData(cell, display) end)
  end

  local GRAY = { {255,255,255}, {170,170,170}, {85,85,85}, {0,0,0} }
  local function crystal(game, mon, animate)
    local id = "crystal_animated_sprites_with_shiny_visuals"
    local handle = mod.find and mod.find(id)
    local api = handle and handle.exports
    local root = api and rootFor(game, id)
    if not root or not api.dexFor then return nil end
    local dex = api.dexFor(mon.species)
    if not dex then return nil end
    local generation = require("src.core.GameVersion").generation()
    local variant = shiny(mon) and "shiny" or "normal"
    local colors, paletteKey
    if generation == 1 and not api.colorMode() then
      variant = api.artVariantForMode(variant)
      local palette = require("src.render.PaletteFX")
      colors = palette.effectiveColors(palette.monPal(game.data, mon.species)) or GRAY
      paletteKey = palette.mode .. mon.species
    elseif generation == 2 then
      local palette = require("src.render.GbcPalette")
      -- Crystal's own Gen 2 menu renderer bakes the gray ramp for DMG/CLASSIC.
      if palette.mode ~= "gbc" then colors, paletteKey = GRAY, "gray" end
    end
    local folder = root .. "/assets/front/" .. variant .. "/" .. dex .. "/"
    local sequence, hit = cached(sequences, folder)
    if not hit then
      local fs = game.mods.fs or love.filesystem
      local function exists(path) return fs.getInfo and fs.getInfo(path) or fs.read(path) end
      if not exists(folder .. "001.png") then
        folder = root .. "/assets/front/normal/" .. dex .. "/"
      end
      if not exists(folder .. "001.png") then return nil end
      local count = 1
      while count < 64 and exists(folder .. string.format("%03d.png", count + 1)) do
        count = count + 1
      end
      local metadata = dataFile(game, root .. "/animation_data.lua") or {}
      local durations = metadata[variant] or metadata.normal or {}
      sequence = { folder = folder, frames = count, durations = durations[tostring(dex)],
        start = love.timer.getTime() }
      remember(sequences, root .. "/assets/front/" .. variant .. "/" .. dex .. "/", sequence, 32)
    end
    local index = 1
    if animate then
      local once = game.save and game.save.options and game.save.options.crystalAnimations == "once"
      if once and not sequence.once then sequence.start = love.timer.getTime() end
      sequence.once = once
      if generation == 2 then
        local t = love.timer.getTime()
        index = once and math.min(sequence.frames, math.floor((t - sequence.start) * 12) + 1)
          or math.floor(t * 12) % sequence.frames + 1
      elseif once then
        local elapsed = (love.timer.getTime() - sequence.start) * 1000
        while index < sequence.frames and elapsed >= ((sequence.durations or {})[index] or 100) do
          elapsed = elapsed - ((sequence.durations or {})[index] or 100); index = index + 1
        end
      else
        index = frameIndex(sequence, true)
      end
    end
    return decode(sequence.folder .. string.format("%03d.png", index), nil, 1,
      paletteKey or "color", function(cell)
        if colors then
          cell:mapPixel(function(_, _, r, g, b, a)
            if a == 0 then return r, g, b, a end
            local luma = .299 * r + .587 * g + .114 * b
            local c = colors[luma > .83 and 1 or luma > .5 and 2 or luma > .17 and 3 or 4]
            return c[1]/255, c[2]/255, c[3]/255, a
          end)
        end
        return image(cell)
      end)
  end
  local function resolve(game, subject, animate)
    local source = mod.options:get("menu_sprite_source") or "battle_art"
    if source == "default" or source == "hgss" then return nil end
    local mon = type(subject) == "table" and subject or { species = subject }
    if not mon.species or mon.isEgg then return nil end
    if source == "crystal" then return crystal(game, mon, animate ~= false) end
    return battleArt(game, mon, animate ~= false)
  end

  return function(game, subject, animate)
    local ok, image = pcall(resolve, game, subject, animate)
    return ok and image or nil
  end
end
