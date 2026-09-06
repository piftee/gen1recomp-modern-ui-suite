-- Native provider and UI integration, through the quiet isolated runner.
return function(game)
  local U = dofile(assert(os.getenv("PC_REPO")) .. "/tests/drivers/util.lua")
  local Screens = require("src.ui.Screens")
  local generation = require("src.core.GameVersion").generation()
  local suite = assert(game.mods.exports.modern_ui_suite)
  local resolve = assert(suite.menuPortrait)
  local opts = game.mods.modOptions.modern_ui_suite
  local checks = 0
  local function check(ok, why) assert(ok, why); checks = checks + 1 end
  local function clear() while game.stack:top() do game.stack:pop() end end
  clear()
  local Mon, normal, shiny
  if generation == 2 then
    game.save = require("src.core.gen2.Save").newGame({ playerName = "SPRITES", trainerId = 4321 })
    Mon = require("src.battle.gen2.Mon")
    normal = Mon.new(game.data, "CHARIZARD", 40)
    shiny = Mon.new(game.data, "CHARIZARD", 40,
      { dvs = { attack = 2, defense = 10, speed = 10, special = 10 } })
    require("src.render.GbcPalette").setMode("gbc")
  else
    Mon = require("src.pokemon.Pokemon")
    normal, shiny = Mon.new(game.data, "CHARIZARD", 40), Mon.new(game.data, "CHARIZARD", 40)
    shiny.dvs = { attack = 2, defense = 10, speed = 10, special = 10 }
    require("src.render.PaletteFX").setMode("redpp")
  end
  normal.dvs = { attack = 15, defense = 15, speed = 15, special = 15 }
  normal.shiny = false
  game.save.options = game.options or game.save.options or {}
  game.save.party = { normal, shiny }
  game.save.pokedex.seen.CHARIZARD = true
  local owned = game.save.pokedex.caught or game.save.pokedex.owned
  owned.CHARIZARD = true
  local G = love.graphics
  local time = love.timer.getTime
  local now = 20
  love.timer.getTime = function() return now end
  local function portrait(mon, animate)
    local img = resolve(game, mon, animate)
    check(img and img:typeOf("Image"), opts.menu_sprite_source .. " provides image")
    check(img:getWidth() <= 128 and img:getHeight() <= 128, "portrait is one logical frame")
    return img
  end
  local function exercise(tag)
    local first = portrait(normal, false)
    local second = portrait(shiny, false)
    check(first ~= second, tag .. " normal and shiny are distinct")
    check(first == portrait(normal, false), tag .. " frame cache is reused")
    local before = portrait(normal)
    now = now + .25
    local after = portrait(normal)
    check(before ~= after, tag .. " follows animation")
    check(first == portrait(normal, false), tag .. " explicit still portraits stay still")
    check(resolve(game, { species = "CHARIZARD", isEgg = true }) == nil, "eggs keep native placeholder")
    check(resolve(game, "NOT_A_POKEMON") == nil, "unknown species falls back")
  end
  local draws, expected, smallImages = {}, {}, {}
  local nativeDraw = G.draw
  G.draw = function(img, ...)
    if img and img.typeOf and img:typeOf("Image") then
      local w, h = img:getDimensions()
      if (w == 8 or w == 16) and h >= 32 and h <= 192 then smallImages[img] = true end
    end
    if expected[img] then
      draws[#draws + 1] = { image = img, shader = G.getShader(), args = {...} }
    end
    return nativeDraw(img, ...)
  end
  local function capture(name, subject, thumbnails)
    expected, draws, smallImages = {}, {}, {}
    if subject then
      expected[portrait(subject)] = true
    end
    U.wait(3)
    check(not love.window.hasFocus() and love.audio.getVolume() == 0, "silent nonactivating capture")
    check(U.shot(game, os.getenv("SHOT_DIR") .. "/" .. name .. ".png"), name .. " screenshot")
    if subject then
      check(#draws > 0, name .. " draws selected provider image")
      for _, call in ipairs(draws) do check(call.shader == nil, name .. " keeps source RGB") end
      if thumbnails then
        check(next(smallImages) ~= nil, name .. " draws genuine small-icon sheets")
        for _, call in ipairs(draws) do
          local width = call.image:getWidth() * math.abs(call.args[4] or 1)
          check(width > 16.01, name .. " never shrinks a portrait into a PC icon")
        end
      end
    end
    return smallImages
  end
  local function screens(tag)
    clear()
    local summary = generation == 2
      and Screens.push(game, "Gen2SummaryMenu", { save = game.save, mon = shiny })
      or Screens.push(game, "SummaryMenu", shiny)
    capture(tag .. "-summary", shiny)
    love.window.setMode(480, 900, { resizable = true })
    capture(tag .. "-summary-portrait", shiny)
    love.window.setMode(1280, 720, { resizable = true })
    clear()
    if generation == 2 then
      local dex = Screens.push(game, "Gen2PokedexMenu", { save = game.save })
      for i, row in ipairs(dex.rows) do if row.species == "CHARIZARD" then dex.index = i break end end
      dex:ensureVisible(); dex.view = "entry"
      capture(tag .. "-dex-entry", "CHARIZARD")
      dex.view = "list"; capture(tag .. "-dex-list", "CHARIZARD")
      dex:current().seen = false
      expected, draws = { [portrait("CHARIZARD")] = true }, {}
      U.wait(3); check(#draws == 0, "unseen Dex artwork remains hidden")
      dex:current().seen = true
    else
      Screens.push(game, "DexEntryMenu", "CHARIZARD")
      capture(tag .. "-dex-entry", "CHARIZARD")
    end
    clear()
    local pc
    if generation == 2 then
      local box = require("src.core.gen2.Boxes").box(game.save, 1)
      box[1], box[2] = normal, shiny
      game.save.currentBox = 1
      pc = Screens.push(game, "Gen2PcMenu", { save = game.save, bills = true })
      pc.boxIndex = 2
    else
      pc = Screens.push(game, "BoxMenu")
      pc.region, pc.partyIndex = "party", 2
    end
    capture(tag .. "-pc", shiny, true)
    love.window.setMode(480, 900, { resizable = true })
    capture(tag .. "-pc-portrait", shiny, true)
    love.window.setMode(1280, 720, { resizable = true })
    return pc
  end
  love.window.setMode(1280, 720, { resizable = true })
  local provider = game.mods.exports.BATTLE_ART_VOXEL_GEN2 or game.mods.exports.BATTLE_ART_VOXEL_FORK
  if provider then
    opts.menu_sprite_source = "battle_art"
    local art = provider.battleArt or provider.lib.require("BattleArt")
    art.duplicateSetting:setIndex(1, game)
    art.setting:sync("animated")
    art.frontAnimationSetting:setIndex(5, game)
    exercise("battle-art-gen5")
    screens("battle-art-gen5")
    for _, gen in ipairs({ 1, 2, 3, 4, 5 }) do
      art.frontAnimationSetting:setIndex(gen, game)
      portrait(normal, false); portrait(shiny, false)
    end
    art.setting:sync("static"); portrait(normal); portrait(shiny)
    art.setting:sync("rom")
    check(resolve(game, normal) == nil, "Battle Art ROM falls back")
    art.setting:sync("animated"); art.duplicateSetting:setIndex(2, game)
    check(resolve(game, normal) == nil, "Battle Art MODDED falls back")
    art.duplicateSetting:setIndex(1, game)
  end
  if game.mods.exports.crystal_animated_sprites_with_shiny_visuals then
    opts.menu_sprite_source = "crystal"
    exercise("crystal")
    screens("crystal")
    local initial = portrait(normal)
    opts.menu_sprite_source = "battle_art"
    if provider then
      check(portrait(normal) ~= initial, "live provider switch replaces Crystal")
      capture("live-switch-to-battle-art", shiny, true)
    end
    opts.menu_sprite_source = "crystal"
    check(portrait(normal) == initial, "live switch restores Crystal")
    game.save.options.crystalAnimations = "once"
    local start = portrait(normal)
    now = now + 100
    local last = portrait(normal)
    now = now + 100
    check(portrait(normal) == last, "Crystal Play Once holds its last frame")
    check(start ~= last, "Crystal Play Once begins at its first frame after a live toggle")
    game.save.options.crystalAnimations = "loop"
    local palette = generation == 2 and require("src.render.GbcPalette") or require("src.render.PaletteFX")
    palette.setMode(generation == 2 and "dmg" or "classic")
    check(portrait(normal) ~= last, "Crystal display mode invalidates color frame")
    palette.setMode(generation == 2 and "gbc" or "redpp")
  end
  -- The live PC remains open while icon choices change. Portraits keep the
  -- same provider image, and Auto returns to the exact installed icon sheets.
  opts.menu_sprite_source = provider and "battle_art" or "crystal"
  opts["party.sprite_source"] = "auto"
  local baseline = capture("icons-auto", shiny, true)
  local portraitBefore = portrait(shiny)
  local fingerprints = {}
  local function iconPixels(img)
    if fingerprints[img] then return fingerprints[img] end
    -- Gen 1's native presenter and Assets have independent image caches.
    -- Compare complete sheet pixels, not Lua object identity.
    local canvas = G.newCanvas(img:getWidth(), img:getHeight())
    local previous = G.getCanvas()
    G.push("all")
    G.setCanvas(canvas); G.origin(); G.setShader(); G.setScissor()
    G.clear(0, 0, 0, 0); G.setColor(1, 1, 1, 1)
    G.setBlendMode("replace", "premultiplied")
    nativeDraw(img, 0, 0)
    G.setCanvas(previous); G.pop()
    fingerprints[img] = love.data.hash("sha256", canvas:newImageData():getString())
    canvas:release()
    return fingerprints[img]
  end
  local function sameIcons(a, b)
    local aa, bb = {}, {}
    for img in pairs(a) do aa[iconPixels(img)] = true end
    for img in pairs(b) do bb[iconPixels(img)] = true end
    for pixels in pairs(aa) do if not bb[pixels] then return false end end
    for pixels in pairs(bb) do if not aa[pixels] then return false end end
    return true
  end
  for _, source in ipairs({ "original", "menu_pack", "follower_pack", "auto" }) do
    opts["party.sprite_source"] = source
    local icons = capture("icons-" .. source, shiny, true)
    check(portrait(shiny) == portraitBefore, "icon source never changes the large portrait")
    if game.mods.exports.unique_menu_icons then
      if source == "original" then check(not sameIcons(icons, baseline), "Original bypasses the installed icon pack") end
      if source == "menu_pack" or source == "auto" then
        check(sameIcons(icons, baseline), source .. " restores installed menu-icon artwork")
      end
    end
  end
  if generation == 2 then
    clear()
    Screens.push(game, "Gen2PartyMenu", { save = game.save })
    local partyBaseline = capture("party-icons-auto")
    check(next(partyBaseline) ~= nil, "Party draws installed small-icon sheets")
    for _, source in ipairs({ "original", "menu_pack", "follower_pack", "auto" }) do
      opts["party.sprite_source"] = source
      local icons = capture("party-icons-" .. source)
      check(next(icons) ~= nil, source .. " keeps Party small icons visible")
      if game.mods.exports.unique_menu_icons then
        if source == "original" then
          check(not sameIcons(icons, partyBaseline), "Party Original bypasses the installed icon pack")
        elseif source == "menu_pack" or source == "auto" then
          check(sameIcons(icons, partyBaseline), "Party shares the PC icon preference")
        end
      end
    end
  end
  opts.menu_sprite_source = "hgss"
  check(resolve(game, normal) == nil, "retired HGSS choice uses Default")
  opts.menu_sprite_source = "default"
  check(resolve(game, normal) == nil, "Default preserves original provider pipeline")
  clear()
  opts.menu_sprite_source = "battle_art"
  suite.settings.open(game)
  local hub = game.stack:top()
  for i, row in ipairs(hub.items) do if row.id == "menu_sprite_source" then hub.index = i end end
  capture("sprite-settings-battle-art")
  for _, name in ipairs({ "crystal", "default", "battle_art" }) do
    hub.onChoose(hub.items[hub.index], hub)
    capture("sprite-settings-" .. name)
    check(opts.menu_sprite_source == name, "native settings cycles and saves " .. name)
  end
  for i, row in ipairs(hub.items) do if row.id == "party.sprite_source" then hub.index = i end end
  check(hub.items[hub.index].right == "AUTO", "Icons setting defaults to installed mods")
  capture("icons-settings-auto")
  for _, name in ipairs({ "original", "menu_pack", "follower_pack", "auto" }) do
    hub.onChoose(hub.items[hub.index], hub)
    capture("icons-settings-" .. name)
    check(opts["party.sprite_source"] == name, "native Icons settings cycles and saves " .. name)
  end
  G.draw, love.timer.getTime = nativeDraw, time
  print("[DISCORD QA] PASS", checks, "menu sprite checks; generation", generation)
end
