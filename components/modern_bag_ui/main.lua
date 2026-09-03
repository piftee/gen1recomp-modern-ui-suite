-- Modern Bag UI retains the built-in BagMenu controller and replaces its
-- presentation plus the small amount of navigation needed for pocket tabs.
-- Every item effect, target picker, battle turn, toss prompt and callback
-- continues to run through src/ui/BagMenu.lua.
return function(mod)
  local SKINS = {
    { label = "MODERN", value = "modern" },
    { label = "POCKET", value = "classic_pocket" },
  }

  local optionSchema = {
    { key = "skin", label = "BAG SKIN", type = "choice",
      default = "modern",
      choices = {
        { SKINS[1].label, SKINS[1].value },
        { SKINS[2].label, SKINS[2].value },
      } },
  }
  mod.options:define(optionSchema)

  local usefulBag = mod.find("useful_bag")
  local kantoReforged = mod.find("Kanto-Reforged")

  local function optionValue(game, owner, key, default)
    if owner == mod.id then
      local value = mod.options:get(key)
      if value == nil then return default end
      return value
    end
    local loader = game and game.mods
    local bucket = loader and loader.modOptions
      and loader.modOptions[owner]
    local value = bucket and bucket[key]
    if value == nil then
      local saved = game and game.save and game.save.options
        and game.save.options.modOptions
      bucket = saved and saved[owner]
      value = bucket and bucket[key]
    end
    if value == nil and loader and loader.optionSchemas then
      for _, row in ipairs(loader.optionSchemas[owner] or {}) do
        if row.key == key then value = row.default break end
      end
    end
    if value == nil then return default end
    return value
  end

  local function skinIndex(game)
    local current = optionValue(game, mod.id, "skin", "modern")
    for index, skin in ipairs(SKINS) do
      if skin.value == current then return index end
    end
    return 1
  end

  local function setOption(game, owner, key, value)
    if owner == mod.id then return mod.options:set(game, key, value) end
    local options = game and game.save and game.save.options
    if options then
      options.modOptions = options.modOptions or {}
      options.modOptions[owner] = options.modOptions[owner] or {}
      options.modOptions[owner][key] = value
    end
    local loader = game and game.mods
    if loader then
      loader.modOptions = loader.modOptions or {}
      loader.modOptions[owner] = loader.modOptions[owner] or {}
      loader.modOptions[owner][key] = value
      if loader.events then
        loader.events:emit("mod.options_changed",
          { mod = owner, key = key, value = value })
      end
    end
  end

  local function bagOptionRows()
    local rows = {
      {
        id = "modern_bag_ui_skin",
        label = "BAG SKIN",
        value = function(game) return SKINS[skinIndex(game)].label end,
        step = function(game, direction)
          local index = (skinIndex(game) - 1 + (direction or 1))
            % #SKINS + 1
          setOption(game, mod.id, "skin", SKINS[index].value)
          return true
        end,
      },
    }
    if usefulBag then
      rows[#rows + 1] = {
        id = "modern_bag_ui_useful_fullscreen",
        label = "FULLSCREEN BAG",
        value = function(game)
          return optionValue(game, "useful_bag", "fullscreen_menu", true)
            and "ON" or "OFF"
        end,
        step = function(game)
          local current = optionValue(
            game, "useful_bag", "fullscreen_menu", true)
          setOption(game, "useful_bag", "fullscreen_menu", not current)
          return true
        end,
      }
    end
    if kantoReforged then
      rows[#rows + 1] = {
        id = "modern_bag_ui_kanto_give",
        label = "BAG GIVE",
        value = function(game)
          return optionValue(game, "Kanto-Reforged", "bag_give", true)
            and "ON" or "OFF"
        end,
        step = function(game)
          local current = optionValue(
            game, "Kanto-Reforged", "bag_give", true)
          setOption(game, "Kanto-Reforged", "bag_give", not current)
          return true
        end,
      }
    end
    return rows
  end

  local function openBagOptions(game)
    local OptionsMenu = require("src.ui.OptionsMenu")
    local page = OptionsMenu.new(game)
    -- OptionsMenu.new invokes this hook while constructing itself. Replace
    -- both its source rows and its already-grouped visible rows. Gen 2 caches
    -- that view during construction, so changing only page.rows leaves the
    -- parent Options list active underneath the apparent submenu.
    local rows = bagOptionRows()
    page.rows, page.view = rows, rows
    page.index, page.scroll, page.sub = 1, 0, true
    game.stack:push(page)
    return true
  end

  -- Keep the game's main Options list compact: one Bag entry opens a native
  -- Options-style page containing this mod's setting and, when installed,
  -- Useful Bag's presentation toggle. The mod manager remains available for
  -- changing either mod separately.
  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    local out = next(game, rows)
    if type(out) ~= "table" then return out end
    out[#out + 1] = {
      id = "modern_bag_ui_options",
      label = "BAG OPTIONS",
      value = function() return "OPEN" end,
      activate = openBagOptions,
      -- Older engine builds treated every custom row as a stepper. Current
      -- OptionsMenu prefers activate, so Left/Right stay inert and A opens.
      step = openBagOptions,
    }
    return out
  end)

  local GameVersion = require("src.core.GameVersion")
  if type(GameVersion.generation) == "function"
      and GameVersion.generation() == 2 then
    return mod:load("gen2.lua")(mod, {
      skins = SKINS,
      skinIndex = skinIndex,
    })
  end

  local function loadFactory(filename)
    local source, readErr = mod:read(filename)
    if not source then
      mod.log:error("%s is missing (%s); reinstall the mod", filename,
        tostring(readErr or "unknown read error"))
      return nil
    end

    local chunk, compileErr = load(source, "@" .. mod.path .. "/" .. filename)
    if not chunk then
      mod.log:error("%s did not compile: %s", filename, tostring(compileErr))
      return nil
    end

    local ok, factory = pcall(chunk)
    if not ok or type(factory) ~= "function" then
      mod.log:error("%s must return a factory function: %s", filename,
        tostring(factory))
      return nil
    end
    return factory
  end

  -- Compile both parts before installing either one so a damaged archive
  -- cannot leave half of the mod active.
  local makeScreen = loadFactory("screen.lua")
  local makeInventory = loadFactory("inventory.lua")
  if not makeScreen or not makeInventory then return end

  -- Kanto Reforged owns a real five-pocket Bag controller. Capture that
  -- controller before replacing the shared screen record so the Modern Bag
  -- can decorate it instead of silently falling back to the stock BagMenu.
  local upstreamBagScreen = mod.content.screens:get("BagMenu")
  local compatibility = {
    usefulBag = mod.find("useful_bag") ~= nil,
    kantoReforged = kantoReforged ~= nil,
    upstreamBagScreen = kantoReforged and upstreamBagScreen or nil,
  }
  local screenOK, bagScreen = pcall(makeScreen, mod, compatibility)
  if not screenOK or type(bagScreen) ~= "table"
      or type(bagScreen.new) ~= "function" then
    mod.log:error("bag screen factory failed: %s", tostring(bagScreen))
    return
  end

  local inventoryOK, inventory = pcall(
    makeInventory, mod, bagScreen, compatibility)
  if not inventoryOK or type(inventory) ~= "table"
      or type(inventory.playerPC) ~= "table"
      or type(inventory.playerPC.new) ~= "function" then
    mod.log:error("inventory extension factory failed: %s", tostring(inventory))
    return
  end

  -- Other bag mods can also register BagMenu. Their optional dependency edge
  -- lets them install controller/storage behavior first; Modern Bag then owns
  -- the shared presentation record while retaining compatible controllers.
  if mod.content.screens:get("BagMenu") then
    mod.content.screens:override("BagMenu", bagScreen)
  else
    mod.content.screens:register("BagMenu", bagScreen)
  end
  mod.content.screens:register("PlayerPC", inventory.playerPC)
  mod.exports.inventoryLimits = inventory.limits
  mod.exports.skins = SKINS
  mod.exports.activeSkin = function() return SKINS[skinIndex()].value end
  mod.log:info("modern pocket bag enabled (%d slots, x%d stacks)",
    inventory.limits.slots, inventory.limits.stack)
end
