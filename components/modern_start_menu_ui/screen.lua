return function(mod, icons)
  local Font = require("src.render.Font")
  local Sound = require("src.core.Sound")
  local paletteOK, PaletteFX = pcall(require, "src.render.PaletteFX")
  if not paletteOK then PaletteFX = nil end
  local touchOK, TouchControls = pcall(require, "src.core.TouchControls")
  if not touchOK then TouchControls = nil end

  local Presentation = {}
  local SCREEN_W, SCREEN_H = 160, 144
  local PORTRAIT_MIN_H, PORTRAIT_MAX_H = 224, 400
  local PANEL_MARGIN, PANEL_W, PANEL_H = 4, 104, 136
  local CELL_W, CELL_H, COL_STEP, ROW_STEP = 30, 30, 32, 32
  local PAGE_SIZE, COLUMNS = 9, 3
  -- Tile captions duplicate the authoritative footer and made every icon
  -- fight for the top two-thirds of its cell. With captions removed, keep
  -- the native 16x16 art optically centred in the full 30px button.
  local ICON_OFFSET_X, ICON_OFFSET_Y = 7, 7
  local iconAtlas, iconQuads, iconLoadFailed, hudShader

  local WHITE, LIGHT, DARK, INK = 1, 0.82, 0.34, 0
  -- Each authored palette keeps paper, accent, body and ink far enough apart
  -- to survive the engine's four-shade post-pass. MAP intentionally has no
  -- palette: it inherits the current location, preserving combinations such
  -- as the lime/cyan route colours seen on a phone.
  local THEME_PALETTES = {
    red = {
      { 255, 247, 232 }, { 255, 154, 126 },
      { 196, 55, 70 }, { 34, 23, 28 },
    },
    blue = {
      { 244, 251, 255 }, { 113, 204, 246 },
      { 43, 116, 181 }, { 13, 34, 50 },
    },
    dmg = {
      { 224, 248, 208 }, { 136, 192, 112 },
      { 52, 104, 86 }, { 8, 24, 32 },
    },
  }
  local VALID_THEMES = { map = true, red = true, blue = true, dmg = true }
  local POSITION_RATIOS = {
    left = 0, mid_left = 0.25, center = 0.5,
    mid_right = 0.75, right = 1,
  }
  local VALID_CLOCKS = { play = true, device = true }
  local BUILTIN_IDS = {
    pokedex = true, party = true, bag = true, trainer = true, save = true,
    options = true, link = true, mods = true, quit = true,
    pokemon = true, pack = true, pokegear = true, status = true,
    option = true,
  }
  local VALUE_IDS = {
    pokemon = "party", pack = "bag",
    status = "trainer", option = "options",
  }
  local LABEL_IDS = {
    POKEDEX = "pokedex", DEX = "pokedex",
    POKEMON = "party", PARTY = "party", PKMN = "party",
    ITEM = "bag", ITEMS = "bag", ITENS = "bag", BAG = "bag", PACK = "bag",
    SAVE = "save", SALVAR = "save",
    OPTION = "options", ["<PO><KE>GEAR"] = "pokegear",
    POKEGEAR = "pokegear",
    OPTIONS = "options", OPCOES = "options", LINK = "link", MODS = "mods",
    QUIT = "quit", SAIR = "quit", SALIR = "quit",
    TRAINER = "trainer", PLAYER = "trainer",
  }
  local CUSTOM_ALIAS_LABELS = { DEX = true, PARTY = true, PKMN = true }
  local LEGACY_SHORT_LABELS = {
    pokedex = "DEX", party = "PKMN", bag = "BAG", trainer = "ID",
    save = "SAVE", options = "OPT", pokegear = "GEAR", link = "LINK",
    mods = "MODS",
    quit = "QUIT",
  }

  -- A native 3x5 caption face. The game's active font is retained as the
  -- selected-label fallback for scripts this alphabet cannot represent, but
  -- it cannot fit inside a 30px app tile. Keeping the compact alphabet as
  -- pixel rows makes captions equally crisp on every LÖVE target.
  local MINI = {
    A={"010","101","111","101","101"}, B={"110","101","110","101","110"},
    C={"011","100","100","100","011"}, D={"110","101","101","101","110"},
    E={"111","100","110","100","111"}, F={"111","100","110","100","100"},
    G={"011","100","101","101","011"}, H={"101","101","111","101","101"},
    I={"111","010","010","010","111"}, J={"001","001","001","101","010"},
    K={"101","101","110","101","101"}, L={"100","100","100","100","111"},
    M={"101","111","111","101","101"}, N={"101","111","111","111","101"},
    O={"010","101","101","101","010"}, P={"110","101","110","100","100"},
    Q={"010","101","101","111","011"}, R={"110","101","110","101","101"},
    S={"011","100","010","001","110"}, T={"111","010","010","010","010"},
    U={"101","101","101","101","111"}, V={"101","101","101","101","010"},
    W={"101","101","111","111","101"}, X={"101","101","010","101","101"},
    Y={"101","101","010","010","010"}, Z={"111","001","010","100","111"},
    ["0"]={"111","101","101","101","111"}, ["1"]={"010","110","010","010","111"},
    ["2"]={"110","001","010","100","111"}, ["3"]={"110","001","010","001","110"},
    ["4"]={"101","101","111","001","001"}, ["5"]={"111","100","110","001","110"},
    ["6"]={"011","100","110","101","010"}, ["7"]={"111","001","010","010","010"},
    ["8"]={"010","101","010","101","010"}, ["9"]={"010","101","011","001","110"},
    [":"]={"000","010","000","010","000"}, ["/"]={"001","001","010","100","100"},
    ["."]={"000","000","000","000","010"}, ["-"]={"000","000","111","000","000"},
    ["?"]={"110","001","010","000","010"}, [" "]={"000","000","000","000","000"},
  }

  local function gray(value, alpha)
    love.graphics.setColor(value, value, value, alpha or 1)
  end

  local function fill(x, y, w, h, shade)
    gray(shade)
    love.graphics.rectangle("fill", math.floor(x), math.floor(y),
      math.floor(w), math.floor(h))
  end

  local function foldLatin(text)
    text = tostring(text or "")
    return text
      :gsub("á", "A"):gsub("à", "A"):gsub("â", "A"):gsub("ã", "A")
      :gsub("ä", "A"):gsub("å", "A"):gsub("Á", "A"):gsub("À", "A")
      :gsub("Â", "A"):gsub("Ã", "A"):gsub("Ä", "A"):gsub("Å", "A")
      :gsub("ç", "C"):gsub("Ç", "C")
      :gsub("é", "E"):gsub("è", "E"):gsub("ê", "E"):gsub("ë", "E")
      :gsub("É", "E"):gsub("È", "E"):gsub("Ê", "E"):gsub("Ë", "E")
      :gsub("í", "I"):gsub("ì", "I"):gsub("î", "I"):gsub("ï", "I")
      :gsub("Í", "I"):gsub("Ì", "I"):gsub("Î", "I"):gsub("Ï", "I")
      :gsub("ñ", "N"):gsub("Ñ", "N")
      :gsub("ó", "O"):gsub("ò", "O"):gsub("ô", "O"):gsub("õ", "O")
      :gsub("ö", "O"):gsub("Ó", "O"):gsub("Ò", "O"):gsub("Ô", "O")
      :gsub("Õ", "O"):gsub("Ö", "O")
      :gsub("ú", "U"):gsub("ù", "U"):gsub("û", "U"):gsub("ü", "U")
      :gsub("Ú", "U"):gsub("Ù", "U"):gsub("Û", "U"):gsub("Ü", "U")
      :gsub("ý", "Y"):gsub("ÿ", "Y"):gsub("Ý", "Y")
  end

  local function miniText(text)
    text = foldLatin(text)
    text = text:upper()
    return (text:gsub("[^A-Z0-9:/%.%-%? ]", "?"))
  end

  local function smallWidth(text)
    local normalized = miniText(text)
    return math.max(0, #normalized * 4 - 1)
  end

  local function drawSmall(text, x, y, shade)
    local normalized = miniText(text)
    x, y = math.floor(x), math.floor(y)
    for index = 1, #normalized do
      local glyph = MINI[normalized:sub(index, index)] or MINI["?"]
      for row = 1, 5 do
        for col = 1, 3 do
          if glyph[row]:sub(col, col) == "1" then
            fill(x + (index - 1) * 4 + col - 1, y + row - 1, 1, 1,
              shade == nil and INK or shade)
          end
        end
      end
    end
    return smallWidth(normalized)
  end

  local function fitSmall(text, width)
    text = miniText(text)
    if smallWidth(text) <= width then return text end
    for count = #text - 1, 1, -1 do
      local candidate = text:sub(1, count) .. "."
      if smallWidth(candidate) <= width then return candidate end
    end
    return "."
  end

  local function centerSmall(text, x, y, width, shade)
    text = fitSmall(text, width)
    drawSmall(text, x + math.max(0, (width - smallWidth(text)) / 2), y, shade)
  end

  local function detectedId(item, game)
    local id = type(item) == "table" and item.id or nil
    if type(id) ~= "string" and type(item) == "table" then id = item.value end
    if type(id) == "string" and BUILTIN_IDS[id] then
      return VALUE_IDS[id] or id
    end
    local label = type(item) == "table" and tostring(item.label or "") or ""
    local upper = foldLatin(label):upper()
    local known = LABEL_IDS[upper]
    if known then return known end
    -- API 2 phone builds predate stable START-menu item ids. Their trainer
    -- row is labelled only with the current player name, so recognize that
    -- authoritative value before falling back to a third-party monogram.
    local player = game and game.save and game.save.player
    local playerName = player and tostring(player.name or "") or ""
    if playerName ~= "" and upper == foldLatin(playerName):upper() then
      return "trainer"
    end
    return "generic"
  end

  local function entryKey(item)
    if type(item) ~= "table" then return "label:UNKNOWN" end
    if type(item.id) == "string" and item.id ~= "" then
      return "id:" .. item.id
    end
    if type(item.value) == "string" and item.value ~= "" then
      return "value:" .. item.value
    end
    local label = miniText(item.label or "UNKNOWN")
    label = label:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return "label:" .. (label ~= "" and label or "UNKNOWN")
  end

  local function isCustomItem(item, game)
    if type(item) ~= "table" then return true end
    local id = type(item.id) == "string" and item.id or nil
    local value = type(item.value) == "string" and item.value or nil
    if id then return not BUILTIN_IDS[id] end
    if value then return not BUILTIN_IDS[value] end
    local label = foldLatin(item.label or ""):upper()
    if CUSTOM_ALIAS_LABELS[label] then return true end
    if LABEL_IDS[label] then return false end
    local player = game and game.save and game.save.player
    local playerName = player and foldLatin(player.name or ""):upper() or ""
    return playerName == "" or label ~= playerName
  end

  local function normalizedId(item, game)
    if mod and type(mod.startMenuIconOverrideFor) == "function" then
      local ok, override = pcall(mod.startMenuIconOverrideFor, item, game)
      if ok and type(override) == "string"
          and override ~= "auto" and (icons.frames or {})[override] ~= nil then
        return override
      end
    end
    return detectedId(item, game)
  end

  local function loadIconAtlas()
    if iconAtlas and iconQuads then return true end
    if iconLoadFailed then return false end
    local ok, atlas = pcall(function()
      return mod.assets:image(icons.asset)
    end)
    if not ok or not atlas then
      iconLoadFailed = true
      if mod.log and mod.log.error then
        mod.log:error("could not load %s: %s", tostring(icons.asset),
          tostring(atlas))
      end
      return false
    end

    local size = icons.size or 16
    local width, height = atlas:getDimensions()
    if height < size then
      iconLoadFailed = true
      if mod.log and mod.log.error then
        mod.log:error("%s is too small (%dx%d)", tostring(icons.asset),
          width, height)
      end
      return false
    end
    if atlas.setFilter then atlas:setFilter("nearest", "nearest") end
    local quads = {}
    for id, frame in pairs(icons.frames or {}) do
      local sourceX = frame * size
      if sourceX + size <= width then
        quads[id] = love.graphics.newQuad(sourceX, 0, size, size,
          width, height)
      end
    end
    iconAtlas, iconQuads = atlas, quads
    return true
  end

  local function drawIcon(id, x, y, label)
    local loaded = loadIconAtlas()
    local quad = loaded and (iconQuads[id] or iconQuads.generic) or nil
    if quad then
      gray(WHITE)
      love.graphics.draw(iconAtlas, quad, math.floor(x), math.floor(y))
    else
      -- A corrupt or missing atlas must never make the START menu unusable.
      -- This intentionally plain frame is a last-resort diagnostic, not the
      -- production art path.
      fill(x + 1, y + 1, 14, 14, INK)
      fill(x + 2, y + 2, 12, 12, WHITE)
    end
  end

  local function itemLabel(item)
    if type(item) ~= "table" then return "UNKNOWN" end
    return tostring(item.label or item.id or "UNKNOWN")
  end

  local function tileLabel(item, id)
    if type(item) == "table" and type(item.shortLabel) == "string"
        and item.shortLabel ~= "" then
      return item.shortLabel
    end
    if LEGACY_SHORT_LABELS[id] then return LEGACY_SHORT_LABELS[id] end
    return itemLabel(item)
  end

  local function displayPixels()
    local width, height
    if love.graphics.getPixelDimensions then
      width, height = love.graphics.getPixelDimensions()
    else
      width, height = love.graphics.getDimensions()
    end
    return tonumber(width) or SCREEN_W, tonumber(height) or SCREEN_H
  end

  local function faithfulRatioEnabled(menu)
    local options = menu and menu.game and menu.game.save
      and menu.game.save.options
    return (tonumber(options and options.faithfulRes) or 0) > 0
  end

  -- A mobile input overlay is already a screen-space composition layered over
  -- the game. Giving START a taller UI canvas at the same time changes the
  -- renderer's fit-scale input and lets the external/mobile compositor shrink
  -- both the world and the menu a second time. Keep the native surface while
  -- touch controls are visible or configured, including the controllerHidden
  -- state used by a Pocket Taco. A connected mobile gamepad is the fallback
  -- for host overlays that hide the built-in touch artwork altogether.
  local function mobileOverlayActive()
    if TouchControls then
      local okVisible, visible = pcall(TouchControls.visible, TouchControls)
      if okVisible and visible then return true end
      if TouchControls.active == true and TouchControls.enabled ~= false then
        return true
      end
    end
    local osName = love.system and love.system.getOS
      and love.system.getOS() or nil
    if (osName == "Android" or osName == "iOS")
        and love.joystick and love.joystick.getJoysticks then
      local okPads, pads = pcall(love.joystick.getJoysticks)
      if okPads and type(pads) == "table" and #pads > 0 then return true end
    end
    return false
  end

  local function responsiveSize(menu)
    if faithfulRatioEnabled(menu) or mobileOverlayActive() then
      return SCREEN_W, SCREEN_H
    end
    local pixelWidth, pixelHeight = displayPixels()
    if pixelHeight > pixelWidth then
      local scale = math.max(1, math.floor(pixelWidth / SCREEN_W))
      local height = math.min(PORTRAIT_MAX_H,
        math.floor(pixelHeight / scale))
      if height >= PORTRAIT_MIN_H then return SCREEN_W, height end
    end
    local scale = math.max(1, math.floor(math.min(
      pixelWidth / SCREEN_W, pixelHeight / SCREEN_H)))
    return math.min(640, math.max(SCREEN_W, math.floor(pixelWidth / scale))),
      SCREEN_H
  end

  local function uiSize()
    -- Never change the renderer's logical surface merely because START is
    -- open. Screen-position modes, survey zoom and native prompts all compute
    -- their composition from this 160x144 contract; a taller menu-owned
    -- surface made the map jump and then jump back when SAVE opened.
    return SCREEN_W, SCREEN_H
  end

  local function selectedOption(key, valid, fallback)
    local options = mod and mod.options
    if not (options and type(options.get) == "function") then return fallback end
    local ok, value = pcall(options.get, options, key)
    if ok and valid[value] then return value end
    return fallback
  end

  local function selectedTheme()
    return selectedOption("theme", VALID_THEMES, "map")
  end

  local function selectedPosition()
    return selectedOption("position", POSITION_RATIOS, "right")
  end

  local function selectedClock()
    return selectedOption("clock", VALID_CLOCKS, "play")
  end

  local function layoutFor(menu)
    local width, height = SCREEN_W, SCREEN_H
    -- The optional final HUD pass is already outside the stack renderer; it
    -- can use the wide display without mutating the game's UI surface.
    if menu and menu.modernStartHudPass then
      width, height = responsiveSize(menu)
    end
    width = math.max(SCREEN_W, math.floor(width))
    height = math.max(SCREEN_H, math.floor(height))

    local availableHeight = height

    local travel = math.max(0, width - PANEL_W - PANEL_MARGIN * 2)
    local position = selectedPosition()
    local panelX = PANEL_MARGIN
      + math.floor(travel * (POSITION_RATIOS[position] or 1) + 0.5)
    local panelY = PANEL_MARGIN
    if height >= PORTRAIT_MIN_H then
      panelY = math.floor((availableHeight - PANEL_H) / 2)
      panelY = math.max(PANEL_MARGIN,
        math.min(height - PANEL_H - PANEL_MARGIN, panelY))
    end
    return {
      width = width,
      height = height,
      panelX = panelX,
      panelY = panelY,
      panelW = PANEL_W,
      panelH = PANEL_H,
      gridX = panelX + 4,
      gridY = panelY + 22,
      availableHeight = availableHeight,
      position = position,
    }
  end

  local function applyPanelTheme(zones, layout)
    local colors = THEME_PALETTES[selectedTheme()]
    if not colors then return zones end
    zones = zones or {}
    -- Renderer applies later zones on top and moves their scissors with the
    -- top-right anchor, so this recolours exactly the phone shell wherever it
    -- is docked without tinting the overworld beneath it.
    zones[#zones + 1] = {
      colors = colors,
      x = layout.panelX, y = layout.panelY,
      w = layout.panelW, h = layout.panelH,
    }
    return zones
  end

  -- Overworld SGB zones describe the original 160x144 UI surface. A portrait
  -- START menu deliberately extends that transparent surface, so inherit the
  -- map palette and extend its full-screen base zone; otherwise the renderer's
  -- palette scissors would clip the lower rows at native y=144.
  local function sgbPalettes(menu, game)
    local layout = layoutFor(menu)
    local states = game and game.stack and game.stack.states or {}
    local menuIndex
    for index = #states, 1, -1 do
      if states[index] == menu then
        menuIndex = index
        break
      end
    end
    -- Some compatible START controllers keep themselves on the stack while
    -- SAVE pushes its summary, YES/NO and dialogue boxes. Those transparent
    -- overlays inherit the nearest palette owner underneath: this menu. A
    -- fixed phone-theme zone must therefore exist only while the phone is the
    -- actual top state, or its right-hand rectangle recolors half of every
    -- Save box. Returning the inherited map zones here exactly matches the
    -- palette those overlays would receive after an ordinary START pop.
    local phoneIsTop = menuIndex ~= nil and menuIndex == #states
    if menuIndex then
      for index = menuIndex - 1, 1, -1 do
        local state = states[index]
        if state and type(state.sgbPalettes) == "function" then
          local ok, zones = pcall(state.sgbPalettes, state, game)
          if ok and type(zones) == "table" and zones[1] then
            local inherited = {}
            for zoneIndex, zone in ipairs(zones) do
              local copy = {}
              for key, value in pairs(zone) do copy[key] = value end
              inherited[zoneIndex] = copy
            end
            local base = inherited[1]
            if (tonumber(base.x) or 0) == 0 and (tonumber(base.y) or 0) == 0 then
              base.w = math.max(tonumber(base.w) or 0, layout.width)
              base.h = math.max(tonumber(base.h) or 0, layout.height)
            end
            return phoneIsTop and applyPanelTheme(inherited, layout)
              or inherited
          end
        end
      end
    end
    if PaletteFX and game and game.data then
      local colors = PaletteFX.pal(game.data, "MEWMON")
      if colors then
        local base = { { colors = colors, x = 0, y = 0,
          w = layout.width, h = layout.height } }
        return phoneIsTop and applyPanelTheme(base, layout) or base
      end
    end
    return phoneIsTop and applyPanelTheme(nil, layout) or nil
  end

  local function validPalette(colors)
    if type(colors) ~= "table" or #colors < 4 then return false end
    for index = 1, 4 do
      if type(colors[index]) ~= "table" or #colors[index] < 3 then
        return false
      end
    end
    return true
  end

  local function hudPaletteFor(menu)
    local fixed = THEME_PALETTES[selectedTheme()]
    if validPalette(fixed) then return fixed end

    -- MAP normally inherits whichever SGB zone covers the panel on the
    -- cartridge canvas. Resolve that same zone for the window-space redraw,
    -- preferring later (more specific) rectangles just like Renderer does.
    local layout = layoutFor(menu)
    local x, y = layout.panelX + math.floor(layout.panelW / 2),
      layout.panelY + math.floor(layout.panelH / 2)
    local zones = sgbPalettes(menu, menu and menu.game)
    for index = type(zones) == "table" and #zones or 0, 1, -1 do
      local zone = zones[index]
      local zx, zy = tonumber(zone.x) or 0, tonumber(zone.y) or 0
      local zw, zh = tonumber(zone.w) or 0, tonumber(zone.h) or 0
      if x >= zx and x < zx + zw and y >= zy and y < zy + zh
          and validPalette(zone.colors) then
        return zone.colors
      end
    end
    local fallback = PaletteFX and menu and menu.game and menu.game.data
      and PaletteFX.pal(menu.game.data, "MEWMON") or nil
    return validPalette(fallback) and fallback
      or (PaletteFX and PaletteFX.GRAYS or nil)
  end

  local function applyHudPalette(menu)
    if not (PaletteFX and type(PaletteFX.sendColors) == "function"
        and love.graphics and type(love.graphics.newShader) == "function") then
      return nil
    end
    if hudShader == nil then
      local ok, shader = pcall(love.graphics.newShader, [[
        extern vec3 c0; extern vec3 c1; extern vec3 c2; extern vec3 c3;
        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
          vec4 p = Texel(tex, tc) * color;
          vec3 mapped = p.r > 0.83 ? c0
            : (p.r > 0.5 ? c1 : (p.r > 0.17 ? c2 : c3));
          return vec4(mapped, p.a);
        }
      ]])
      hudShader = ok and shader or false
    end
    local shader = hudShader or nil
    local colors = hudPaletteFor(menu)
    if not (shader and validPalette(colors)) then return nil end
    PaletteFX.sendColors(shader, colors)
    return shader
  end

  local function currentIndex(menu)
    if menu and menu.modernStartGen2 and menu.list then
      return menu.list.index or menu.index or 1
    end
    return menu and menu.index or 1
  end

  local function setIndex(menu, index)
    menu.index = index
    if menu.modernStartGen2 and menu.list then menu.list.index = index end
    local save = menu.game and menu.game.save
    if save and index and index > 0 then
      save.startMenuIndex = math.max(1, math.floor(index))
    end
  end

  local function playClockText(menu)
    local playTime = menu.game.save.playTime
    local hours, minutes
    if type(playTime) == "table" then
      -- Gold, Silver and Crystal keep their play clock split into fields.
      -- Gen 1 uses a single count of elapsed seconds, so accept both shapes.
      hours = math.max(0, math.floor(tonumber(playTime.hours) or 0))
      minutes = math.max(0, math.floor(tonumber(playTime.minutes) or 0)) % 60
    else
      local seconds = math.max(0, math.floor(tonumber(playTime) or 0))
      hours = math.floor(seconds / 3600)
      minutes = math.floor(seconds / 60) % 60
    end
    return ("%d:%02d"):format(hours, minutes)
  end

  local WEEKDAY_LABELS = {
    [1] = "SUN", [2] = "MON", [3] = "TUE", [4] = "WED",
    [5] = "THU", [6] = "FRI", [7] = "SAT",
  }

  local function resolvedDeviceTime(deviceTime)
    if type(deviceTime) == "table" then return deviceTime end
    if os and type(os.date) == "function" then
      local ok, value = pcall(os.date, "*t")
      if ok and type(value) == "table" then return value end
    end
  end

  local function clockTextFor(menu, deviceTime)
    if selectedClock() == "device" then
      local now = resolvedDeviceTime(deviceTime)
      if type(now) == "table" then
        local hour = tonumber(now.hour or now.hours)
        local minute = tonumber(now.min or now.minute or now.minutes)
        if hour and minute then
          return ("%02d:%02d"):format(math.floor(hour) % 24,
            math.floor(minute) % 60)
        end
      end
    end
    return playClockText(menu)
  end

  local function clockLabelFor(menu, deviceTime)
    local time = clockTextFor(menu, deviceTime)
    if selectedClock() ~= "device" then return "PLAY " .. time end
    local now = resolvedDeviceTime(deviceTime)
    local weekday = now and WEEKDAY_LABELS[tonumber(now.wday)] or nil
    return (weekday or "NOW") .. " " .. time
  end

  local function drawShell(menu, layout)
    local panelX, panelY = layout.panelX, layout.panelY
    fill(panelX, panelY, PANEL_W, PANEL_H, INK)
    fill(panelX + 2, panelY + 1, PANEL_W - 4, PANEL_H - 2, DARK)
    fill(panelX + 4, panelY + 4, PANEL_W - 8, PANEL_H - 8, WHITE)

    -- Earpiece and compact status line: selected clock on left, page on right.
    fill(panelX + 39, panelY + 3, 26, 3, INK)
    fill(panelX + 42, panelY + 3, 20, 1, LIGHT)
    local time = clockLabelFor(menu)
    drawSmall(time, panelX + 7, panelY + 9, INK)
    local count = #menu.items
    local pages = math.max(1, math.ceil(count / PAGE_SIZE))
    local index = currentIndex(menu)
    local page = count > 0 and math.floor((index - 1) / PAGE_SIZE) + 1 or 1
    local pageText = ("%d/%d"):format(page, pages)
    drawSmall(pageText, panelX + PANEL_W - 7 - smallWidth(pageText),
      panelY + 9, INK)
    fill(panelX + 4, panelY + 18, PANEL_W - 8, 1, INK)
  end

  local function drawTiles(menu, layout)
    local count = #menu.items
    if count == 0 then
      centerSmall("NO MENU ITEMS", layout.panelX + 8,
        layout.panelY + 64, PANEL_W - 16, INK)
      return
    end
    local index = currentIndex(menu)
    local pageStart = math.floor((index - 1) / PAGE_SIZE) * PAGE_SIZE + 1
    for slot = 1, PAGE_SIZE do
      local itemIndex = pageStart + slot - 1
      local item = menu.items[itemIndex]
      if not item then break end
      local col, row = (slot - 1) % COLUMNS, math.floor((slot - 1) / COLUMNS)
      local x, y = layout.gridX + col * COL_STEP,
        layout.gridY + row * ROW_STEP
      local selected = itemIndex == index
      if selected then
        fill(x - 1, y - 1, CELL_W + 2, CELL_H + 2, INK)
        fill(x + 1, y + 1, CELL_W - 2, CELL_H - 2, WHITE)
        fill(x + 11, y - 3, 8, 2, INK)
      else
        fill(x, y, CELL_W, CELL_H, LIGHT)
        fill(x + 1, y + 1, CELL_W - 2, CELL_H - 2, WHITE)
      end
      local id = normalizedId(item, menu.game)
      drawIcon(id, x + ICON_OFFSET_X, y + ICON_OFFSET_Y, itemLabel(item))
    end
  end

  local function drawFooter(menu, layout)
    local panelX, panelY = layout.panelX, layout.panelY
    fill(panelX + 4, panelY + 118, PANEL_W - 8, 1, INK)
    if #menu.items == 0 then return end
    local label = itemLabel(menu.items[currentIndex(menu)])
    local x, y, width = panelX + 8, panelY + 124, PANEL_W - 16
    -- The mini alphabet covers Latin captions. For other scripts, retain the
    -- game's active font/charmap so a localization mod's real glyphs appear
    -- instead of turning its selected label into question marks.
    local native = miniText(label):find("?", 1, true) ~= nil
    local textWidth = native and Font.width(label) or smallWidth(label)
    local function drawLabel(at)
      if native then
        gray(INK)
        Font.draw(label, math.floor(at), y - 1)
      else
        drawSmall(label, math.floor(at), y + 1, INK)
      end
    end
    if textWidth <= width then
      drawLabel(x + (width - textWidth) / 2)
      return
    end
    -- Long localized or third-party labels pass through the footer in full;
    -- icon-only tiles stay quiet, but the authoritative label is never lost.
    local gap = 18
    local travel = textWidth + gap
    -- Show the beginning immediately, pause long enough to read it, then
    -- loop two copies so the footer never becomes an unexplained blank.
    local elapsed = math.max(0, (menu.modernStartElapsed or 0) - 1)
    local offset = (elapsed * 14) % travel
    if love.graphics.setScissor then love.graphics.setScissor(x, y - 1, width, 10) end
    drawLabel(x - offset)
    drawLabel(x - offset + travel)
    if love.graphics.setScissor then love.graphics.setScissor() end
  end

  local function drawSafari(menu, layout)
    local game, ow = menu.game, menu.game.overworld
    if not (game.save.safari and ow and ow.map and ow.inSafariStepZone
        and ow:inSafariStepZone()) then return end
    local safari = game.save.safari
    local statusX, statusW = 0, layout.panelX
    local rightX = layout.panelX + layout.panelW
    local rightW = layout.width - rightX
    if rightW > statusW then statusX, statusW = rightX, rightW end
    if statusW < 48 then return end
    fill(statusX, 0, statusW, 17, INK)
    fill(statusX + 1, 1, statusW - 2, 15, WHITE)
    local steps = math.max(0, math.floor(safari.steps or 0))
    local balls = math.max(0, math.floor(safari.balls or 0))
    centerSmall(("STEP %d/500"):format(steps), statusX + 2, 2,
      statusW - 4, INK)
    centerSmall(("BALL %d"):format(balls), statusX + 2, 9,
      statusW - 4, INK)
  end

  local function move(menu, delta)
    local count = #menu.items
    if count == 0 then return end
    local current = currentIndex(menu)
    local index = ((current - 1 + delta) % count) + 1
    if index ~= current then
      setIndex(menu, index)
      menu.modernStartElapsed = 0
    end
    menu.scroll = math.floor((index - 1) / PAGE_SIZE) * PAGE_SIZE
  end

  local function update(menu, dt)
    menu.modernStartElapsed = (menu.modernStartElapsed or 0) + (dt or 0)
    if menu.modernStartGen2 and menu.phase == "confirm" then
      menu.classicStartMenuUpdate(menu, dt)
      setIndex(menu, menu.list and menu.list.index or currentIndex(menu))
      return
    end
    local input = menu.game.input
    if input:wasPressed("left") then
      move(menu, -1)
    elseif input:wasPressed("right") then
      move(menu, 1)
    elseif input:wasPressed("up") then
      move(menu, -COLUMNS)
    elseif input:wasPressed("down") then
      move(menu, COLUMNS)
    elseif input:wasPressed("a") and #menu.items > 0 then
      local index = currentIndex(menu)
      local item = menu.items[index]
      if menu.modernStartGen2 then
        menu:choose(item and item.value, index)
      else
        if not menu.noSound then Sound.play(menu.game.data, "Press_AB") end
        if not item.keepOpen then menu.game.stack:pop() end
        if type(item.onSelect) == "function" then item.onSelect() end
      end
    elseif menu.modernStartGen2 and (input:wasPressed("b")
        or input:wasPressed("start")) then
      menu:close()
    elseif menu.cancelable and (input:wasPressed("b")
        or (menu.startCloses and input:wasPressed("start"))) then
      if input:wasPressed("b") and not menu.noSound then
        Sound.play(menu.game.data, "Press_AB")
      end
      menu.game.stack:pop()
      if menu.onCancel then menu.onCancel() end
    else
      -- Preserve controller extensions installed before this presentation.
      -- Gen1MenuManager, for example, adds a SELECT shortcut that opens its
      -- item-reordering options. Our grid owns only the buttons above; any
      -- other hotkey should still reach the finished source controller.
      menu.classicStartMenuUpdate(menu, dt)
    end
    if #menu.items > 0 then setIndex(menu, currentIndex(menu)) end
  end

  local function drawConfirm(menu, layout)
    if not (menu.modernStartGen2 and menu.phase == "confirm") then return end
    local x, y, width = layout.panelX + 8, layout.panelY + 45,
      layout.panelW - 16
    fill(x, y, width, 47, INK)
    fill(x + 2, y + 2, width - 4, 43, LIGHT)
    centerSmall("RETURN TO TITLE?", x + 4, y + 7, width - 8, INK)
    local yes = menu.confirmChoice == 1
    local noX = x + width - 36
    fill(x + 8, y + 24, 28, 13, INK)
    fill(x + 9, y + 25, 26, 11, yes and DARK or LIGHT)
    fill(noX, y + 24, 28, 13, INK)
    fill(noX + 1, y + 25, 26, 11, yes and LIGHT or DARK)
    centerSmall("YES", x + 8, y + 28, 28, yes and WHITE or INK)
    centerSmall("NO", noX, y + 28, 28, yes and INK or WHITE)
  end

  local function draw(menu)
    local renderer = menu.game and menu.game.renderer
    -- Do not call setUIAnchor here. The renderer owns screen-position modes;
    -- retaining its existing centred/top/high placement prevents START from
    -- moving the world or leaving an anchor behind for the SAVE prompt.
    -- Dynamic UI normally follows the overworld's survey zoom. That is a
    -- useful default for classic screen furniture, but it makes this
    -- already-compact panel half-size when a Pocket Taco / controller
    -- overlay is paired with a zoomed-out map. Give Renderer:endFrame one
    -- FIT-scale answer while leaving Dynamic UI itself enabled. The wrapper
    -- removes itself before render.compose / render.hud mods run; the map
    -- keeps its own zoom and the phone keeps the middle alignment above.
    -- The hold is declared during the ordinary stack pass and consumed by
    -- Renderer:endFrame. Never arm it from the later HUD pass, where it would
    -- survive into the next frame.
    if not menu.modernStartHudPass and renderer and renderer.worldActive
        and renderer.uiCentered ~= true
        and not renderer.modernStartMenuScaleHold
        and type(renderer.uiScale) == "function"
        and type(renderer.fitScale) == "function" then
      local originalUIScale = renderer.uiScale
      local readableScale = renderer:fitScale()
      renderer.modernStartMenuScaleHold = true
      renderer.uiScale = function(active)
        active.uiScale = originalUIScale
        active.modernStartMenuScaleHold = nil
        return readableScale
      end
    end
    -- Wide desktop layouts keep the ordinary cartridge canvas untouched and
    -- redraw only the phone after composition. The same branch now serves
    -- both generations, restoring edge placement without reviving the old
    -- map/Save bounce caused by changing UI size or anchors.
    if not menu.modernStartHudPass then
      local pixelWidth, pixelHeight = displayPixels()
      local logicalWidth = select(1, responsiveSize(menu))
      if pixelWidth > pixelHeight and logicalWidth > SCREEN_W then return end
    end
    local layout = layoutFor(menu)
    menu.modernStartLastWideWidth = layout.width
    love.graphics.push("all")
    drawShell(menu, layout)
    drawTiles(menu, layout)
    drawFooter(menu, layout)
    drawSafari(menu, layout)
    drawConfirm(menu, layout)
    love.graphics.pop()
  end

  function Presentation.decorate(menu, game)
    if menu.modernStartMenuUI then return menu end
    menu.game = game or menu.game
    menu.classicStartMenuUpdate = menu.update
    menu.classicStartMenuDraw = menu.draw
    menu.classicStartMenuUISize = menu.uiSize
    menu.classicStartMenuSGBPalettes = menu.sgbPalettes
    menu.modernStartGen2 = type(menu.list) == "table"
      and type(menu.choose) == "function" and type(menu.close) == "function"
    menu.modernStartMenuUI = true
    menu.modernStartElapsed = 0
    menu.update = update
    menu.draw = draw
    menu.uiSize = uiSize
    menu.sgbPalettes = sgbPalettes
    if #menu.items > 0 then
      local savedIndex = menu.game and menu.game.save
        and menu.game.save.startMenuIndex
      local initial = savedIndex
        or (menu.modernStartGen2 and menu.list.index or menu.index)
      setIndex(menu, math.max(1, math.min(initial or 1, #menu.items)))
      menu.scroll = math.floor((menu.index - 1) / PAGE_SIZE) * PAGE_SIZE
    else
      menu.index, menu.scroll = 0, 0
    end
    return menu
  end

  Presentation.PAGE_SIZE = PAGE_SIZE
  Presentation.PANEL_X = SCREEN_W - PANEL_MARGIN - PANEL_W
  Presentation.PANEL_W = PANEL_W
  Presentation.PANEL_H = PANEL_H
  Presentation.iconOffsetY = ICON_OFFSET_Y
  Presentation.iconFor = normalizedId
  Presentation.detectedIconFor = detectedId
  Presentation.entryKeyFor = entryKey
  Presentation.isCustomItem = isCustomItem
  Presentation.normalizeText = miniText
  Presentation.tileLabelFor = tileLabel
  Presentation.layoutFor = layoutFor
  Presentation.responsiveSize = responsiveSize
  Presentation.uiSize = uiSize
  Presentation.sgbPalettes = sgbPalettes
  Presentation.themeFor = selectedTheme
  Presentation.positionFor = selectedPosition
  Presentation.clockFor = selectedClock
  Presentation.clockTextFor = clockTextFor
  Presentation.clockLabelFor = clockLabelFor
  Presentation.themePalettes = THEME_PALETTES
  Presentation.hudPaletteFor = hudPaletteFor
  Presentation.applyHudPalette = applyHudPalette
  Presentation.draw = draw
  Presentation.drawIcon = drawIcon
  Presentation.tileLabels = false
  Presentation.iconAsset = icons.asset
  Presentation.iconPaletteSize = icons.paletteSize
  return Presentation
end
