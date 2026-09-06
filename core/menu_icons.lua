-- Small menu icons are independent of battle/summary portraits. Gen 1 uses
-- the existing Party presenter; Gen 2 selects icon definitions for a private
-- renderer view, preserving its native frames and held-item/mail markers.
return function(mod)
  local Version = require("src.core.GameVersion")
  if type(Version.generation) ~= "function" or Version.generation() ~= 2 then
    return function() return false end
  end
  local PartyMenu = require("src.ui.gen2.PartyMenu")
  local Assets = require("src.render.Assets")
  local Merge = require("src.mods.Merge")
  -- The suite installs before Loader merges icon contributions into Data.
  -- Keep the original assignments in memory for the ORIGINAL choice.
  local gameData = require("src.core.Game").data
  local original = gameData and gameData.gen2Icons
    and Merge.deepCopy(gameData.gen2Icons) or nil
  local function packEntry(game, mon, source)
    local loader = game and game.mods
    local registry = loader and loader.content and loader.content.icons
    local ops = registry and registry.ops and registry.ops[mon.species]
    if not ops then return nil end
    for i = #ops, 1, -1 do
      local op = ops[i]
      local owner = op.owner
      local handle = owner and mod.find and mod.find(owner)
      local exports = handle and handle.exports
      local menu = exports and (owner == "unique_menu_icons" or exports.ownsPartyIcons == true)
      local follower = exports and (owner == "overworld_wild_spawns"
        or owner == "PokePCFollowers_VoxelMerge" or exports.ownsFollowerIcons == true)
      if (source == "menu_pack" and menu) or (source == "follower_pack" and follower) then
        if op.op == "remove" then return nil end
        local value = op.value
        if type(value) == "string" then value = registry:get(value) end
        return value
      end
    end
  end
  return function(game, renderer, mon, x, y)
    local source = mod.options:get("party.sprite_source") or "auto"
    if source == "auto" or not mon or mon.isEgg then return false end
    local entry
    if source == "original" then
      local id = original and original.species and original.species[mon.species]
      entry = id and original.icons and original.icons[id]
    elseif source == "menu_pack" or source == "follower_pack" then
      entry = packEntry(game, mon, source)
    end
    if type(entry) ~= "table" or type(entry.image) ~= "string" then return false end
    local ok, image = pcall(Assets.image, entry.image)
    if not ok or not image then return false end
    local w, h = image:getDimensions()
    -- Gen 2's native icon contract is a 16px-wide vertical frame strip.
    if w ~= 16 or h < 16 or h % 16 ~= 0 then return false end
    local animate = mod.options:get("party.animate_icons") ~= false
    local frame = animate and math.floor((renderer.clock or 0) / 16) % (h / 16) or 0
    local proxy = setmetatable({
      iconFor = function() return image, frame end,
    }, { __index = renderer })
    local trueColor = source ~= "original" and (entry.trueColor == true
      or entry.image:find("/icon_color/", 1, true)
      or entry.image:find("/icon_gbc_red/", 1, true))
    if trueColor then proxy.palettes = false end
    -- Unique Menu Icons wraps by species. Its wrapper must not strip the
    -- palette from ORIGINAL icons just because that species has pack artwork.
    local unique = PartyMenu.__uniqueMenuIconsGoldPartyMenu
    local draw = unique and unique.originalDrawIcon or PartyMenu.drawIcon
    local G = love.graphics
    G.push("all")
    if trueColor then G.setShader() end
    local drawn, err = pcall(draw, proxy, mon, x, y)
    G.pop()
    if not drawn then error(err, 0) end
    return true
  end
end
