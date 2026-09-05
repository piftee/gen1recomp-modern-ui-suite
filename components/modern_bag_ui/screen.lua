-- Pocket-based presentation for src/ui/BagMenu.
--
-- The built-in BagMenu already owns a large and delicate behavior surface:
-- item targeting, battle turns, field actions, toss confirmation, scripted
-- tutorial input and several screens opened after item use. This module wraps
-- that controller instead of duplicating it. Only the visible list, drawing,
-- left/right pocket navigation and filtered-list reordering live here.
return function(mod, compatibility)
  compatibility = compatibility or {}
  local BagMenu = require("src.ui.BagMenu")
  local Bag = require("src.inventory.Bag")
  local Assets = require("src.render.Assets")
  local Font = require("src.render.Font")
  local ItemEffects = require("src.inventory.ItemEffects")
  local Menu = require("src.ui.Menu")
  local PaletteFX = require("src.render.PaletteFX")
  local Strings = require("src.core.Strings")
  local Theme = require("src.ui.Theme")
  local TouchControls = require("src.core.TouchControls")

  local SCREEN_W = 160
  local SCREEN_H = 144
  local HEADER_H = 16
  local TABS_H = 20
  local FOOTER_H = 8
  local PORTRAIT_MIN_H = 224
  local PORTRAIT_MAX_H = 400
  local ROWS = 6
  local ROW_H = 15

  local WHITE = 1
  local LIGHT = 170 / 255
  local DARK = 85 / 255
  local BLACK = 0

  local function classicSkin()
    return mod.options:get("skin") == "classic_pocket"
  end

  local POCKETS = {
    { key = "all", label = "ALL ITEMS", short = "ALL", palette = "BLUEMON",
      blurb = Strings.source("Everything you are carrying.") },
    { key = "items", label = "ITEMS", short = "ITEMS", palette = "BROWNMON",
      blurb = Strings.source("Useful items for your journey.") },
    { key = "medicine", label = "MEDICINE", short = "MED", palette = "GREENMON",
      blurb = Strings.source("Items that help your POKéMON.") },
    { key = "balls", label = "POKé BALLS", short = "BALLS", palette = "REDMON",
      blurb = Strings.source("Devices for catching wild POKéMON.") },
    { key = "machines", label = "TMs/HMs", short = "TMs", palette = "PURPLEMON",
      blurb = Strings.source("Machines that teach new moves.") },
    { key = "key", label = "KEY ITEMS", short = "KEY", palette = "CYANMON",
      blurb = Strings.source("Important items for your adventure.") },
  }

  -- Kanto Reforged exposes these five pockets on its public Bag controller.
  -- The source id is retained because its controller uses "tmhm", while the
  -- Modern Bag presentation calls the same visual category "machines".
  local KANTO_POCKETS = {
    { key = "items", source = "items", label = "ITEMS", short = "ITEMS",
      palette = "BROWNMON",
      blurb = Strings.source("Useful and held items for your journey.") },
    { key = "balls", source = "balls", label = "POKé BALLS", short = "BALLS",
      palette = "REDMON",
      blurb = Strings.source("Devices for catching wild POKéMON.") },
    { key = "key", source = "key", label = "KEY ITEMS", short = "KEY",
      palette = "CYANMON",
      blurb = Strings.source("Important items for your adventure.") },
    { key = "machines", source = "tmhm", label = "TMs & HMs", short = "TMs",
      palette = "PURPLEMON",
      blurb = Strings.source("Machines that teach new moves.") },
    { key = "berries", source = "berries", label = "BERRIES", short = "BERRY",
      palette = "GREENMON",
      blurb = Strings.source("Berries that POKéMON can use or hold.") },
  }

  -- The reference skin uses compact, title-case labels in its rail rather
  -- than the all-caps names used by the modern header and tabs.
  local CLASSIC_POCKET_LABELS = {
    all = "All",
    items = "Items",
    medicine = "Meds",
    balls = "Balls",
    machines = "TMs",
    key = "Key",
    berries = "Berries",
  }

  -- The extracted reference backpack has five real compartments. All is a
  -- combined view; the remaining five categories each own one sprite region.
  -- Battle enhancers stay in Items so the navigation and artwork are 1:1.
  local CLASSIC_BAG_REGIONS = {
    all = "all",
    items = "items",
    medicine = "medicine",
    balls = "balls",
    machines = "machines",
    key = "key",
    -- Kanto's Berry pocket uses the backpack's medicine compartment; both
    -- configurations therefore keep a five-compartment sprite.
    berries = "medicine",
  }
  local CLASSIC_BAG_ASSET = mod.path .. "/assets/classic_bag_pockets.png"

  local MEDICINE = {
    POTION = true, SUPER_POTION = true, HYPER_POTION = true,
    MAX_POTION = true, FULL_RESTORE = true, FRESH_WATER = true,
    SODA_POP = true, LEMONADE = true, ANTIDOTE = true,
    BURN_HEAL = true, ICE_HEAL = true, AWAKENING = true,
    PARLYZ_HEAL = true, FULL_HEAL = true, REVIVE = true,
    MAX_REVIVE = true, RARE_CANDY = true, HP_UP = true,
    PROTEIN = true, IRON = true, CARBOS = true, CALCIUM = true,
    PP_UP = true, ETHER = true, MAX_ETHER = true,
    ELIXER = true, MAX_ELIXER = true,
  }

  local BERRIES = {
    BERRY = true, CHERI_BERRY = true, CHESTO_BERRY = true,
    PECHA_BERRY = true, RAWST_BERRY = true, ASPEAR_BERRY = true,
    PERSIM_BERRY = true, LUM_BERRY = true,
  }

  local DESCRIPTIONS = {
    POTION = Strings.source("Restores 20 HP to one POKéMON."),
    SUPER_POTION = Strings.source("Restores 50 HP to one POKéMON."),
    HYPER_POTION = Strings.source("Restores 200 HP to one POKéMON."),
    MAX_POTION = Strings.source("Fully restores one POKéMON's HP."),
    FULL_RESTORE = Strings.source("Fully restores HP and cures status."),
    FRESH_WATER = Strings.source("A refreshing drink that restores 50 HP."),
    SODA_POP = Strings.source("A fizzy drink that restores 60 HP."),
    LEMONADE = Strings.source("A sweet drink that restores 80 HP."),
    ANTIDOTE = Strings.source("Cures a poisoned POKéMON."),
    BURN_HEAL = Strings.source("Cures a burned POKéMON."),
    ICE_HEAL = Strings.source("Defrosts a frozen POKéMON."),
    AWAKENING = Strings.source("Wakes a sleeping POKéMON."),
    PARLYZ_HEAL = Strings.source("Cures a paralyzed POKéMON."),
    FULL_HEAL = Strings.source("Cures all status conditions."),
    REVIVE = Strings.source("Revives a fainted POKéMON with half HP."),
    MAX_REVIVE = Strings.source("Revives a fainted POKéMON with full HP."),
    RARE_CANDY = Strings.source("Raises one POKéMON by one level."),
    PP_UP = Strings.source("Raises the maximum PP of one move."),
    ETHER = Strings.source("Restores 10 PP to one move."),
    MAX_ETHER = Strings.source("Fully restores the PP of one move."),
    ELIXER = Strings.source("Restores 10 PP to every move."),
    MAX_ELIXER = Strings.source("Fully restores the PP of every move."),
    ESCAPE_ROPE = Strings.source("Returns you to the last POKéMON Center."),
    REPEL = Strings.source("Keeps weak wild POKéMON away briefly."),
    SUPER_REPEL = Strings.source("Keeps weak wild POKéMON away longer."),
    MAX_REPEL = Strings.source("Keeps weak wild POKéMON away the longest."),
    FIRE_STONE = Strings.source("A peculiar stone that evolves some POKéMON."),
    WATER_STONE = Strings.source("A peculiar stone that evolves some POKéMON."),
    THUNDER_STONE = Strings.source("A peculiar stone that evolves some POKéMON."),
    LEAF_STONE = Strings.source("A peculiar stone that evolves some POKéMON."),
    MOON_STONE = Strings.source("A peculiar stone that evolves some POKéMON."),
    NUGGET = Strings.source("A solid gold nugget that sells for a high price."),
    POKE_DOLL = Strings.source("A doll that can help you escape a wild battle."),
    BICYCLE = Strings.source("A folding bicycle that is faster than walking."),
    TOWN_MAP = Strings.source("A convenient map of the Kanto region."),
    ITEMFINDER = Strings.source("Checks the area for hidden items."),
    POKE_FLUTE = Strings.source("A flute with a melody that wakes sleepers."),
    OLD_ROD = Strings.source("Use it by water to fish for POKéMON."),
    GOOD_ROD = Strings.source("A good rod for fishing up POKéMON."),
    SUPER_ROD = Strings.source("The best rod for fishing up POKéMON."),
  }

  local inkShader -- false when shaders are unavailable
  local classicLabelFont -- false when direct TTF labels are unavailable
  local classicBagSprites -- false when the source sprite cannot be loaded

  local function gray(value)
    love.graphics.setColor(value, value, value, 1)
  end

  local function shaderForInk()
    if inkShader == nil then
      if not love.graphics.newShader then
        inkShader = false
      else
        local ok, shader = pcall(love.graphics.newShader, [[
          vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            vec4 pixel = Texel(tex, tc);
            return vec4(color.rgb, pixel.a * color.a);
          }
        ]])
        inkShader = ok and shader or false
      end
    end
    return inkShader or nil
  end

  local function fitText(text, maxWidth)
    text = tostring(text or "")
    maxWidth = math.max(0, math.floor(maxWidth or Font.width(text)))
    if Font.width(text) <= maxWidth then return text end
    local spans = Font.split(text)
    local count = Font.spansFitting(spans, math.max(0, maxWidth - 8))
    if count < 1 then return "" end
    return text:sub(1, spans[count].to) .. "."
  end

  local function drawTextRaw(text, x, y, shade)
    text = tostring(text or "")
    love.graphics.push("all")
    local shader = shaderForInk()
    if shader then
      love.graphics.setShader(shader)
      gray(shade == nil and WHITE or shade)
    else
      gray(BLACK)
    end
    Font.draw(text, math.floor(x), math.floor(y))
    love.graphics.pop()
    return Font.width(text)
  end

  local function drawText(text, x, y, maxWidth, shade)
    text = fitText(text, maxWidth or Font.width(tostring(text or "")))
    return drawTextRaw(text, x, y, shade)
  end

  local function moneyText(menu)
    local save = menu and menu.game and menu.game.save
    return ("¥%d"):format((save and tonumber(save.money)) or 0)
  end

  local function drawTextRight(text, right, y, maxWidth, shade)
    text = fitText(text, maxWidth)
    local width = Font.width(text)
    drawText(text, right - width, y, maxWidth, shade)
    return width
  end

  local function classicRailLabel(text, x, y, width, height)
    text = tostring(text or "")
    if classicLabelFont == nil then
      if not love.graphics.newFont then
        classicLabelFont = false
      else
        local ok, face = pcall(love.graphics.newFont,
          Font.PLAINPIXEL, 10, "mono")
        if ok and face then
          if face.setFilter then
            pcall(face.setFilter, face, "nearest", "nearest")
          end
          classicLabelFont = face
        else
          classicLabelFont = false
        end
      end
    end

    local face = classicLabelFont or nil
    if not face or not love.graphics.print then
      local fallback = fitText(text, width)
      drawText(fallback, x + math.floor((width - Font.width(fallback)) / 2),
        y + math.floor((height - 8) / 2), width, WHITE)
      return fallback
    end

    local original = text
    local spans = Font.split(original)
    local count = #spans
    while count > 1 and face:getWidth(text) > width do
      count = count - 1
      text = original:sub(1, spans[count].to) .. "."
    end
    love.graphics.push("all")
    local shader = shaderForInk()
    if shader then
      love.graphics.setShader(shader)
      gray(WHITE)
    else
      gray(BLACK)
    end
    love.graphics.setFont(face)
    love.graphics.print(text,
      math.floor(x + (width - face:getWidth(text)) / 2),
      math.floor(y + (height - face:getHeight()) / 2))
    love.graphics.pop()
    return text
  end

  local function drawCode(code, x, y, shade)
    love.graphics.push("all")
    local shader = shaderForInk()
    if shader then
      love.graphics.setShader(shader)
      gray(shade == nil and WHITE or shade)
    else
      gray(BLACK)
    end
    Font.drawCode(code, math.floor(x), math.floor(y))
    love.graphics.pop()
  end

  local function wrappedLines(text, maxWidth, maxLines)
    local lines, current = {}, ""
    for word in tostring(text or ""):gmatch("%S+") do
      local candidate = current == "" and word or (current .. " " .. word)
      if current ~= "" and Font.width(candidate) > maxWidth then
        lines[#lines + 1] = fitText(current, maxWidth)
        current = word
        if #lines >= maxLines then break end
      else
        current = candidate
      end
    end
    if #lines < maxLines and current ~= "" then
      lines[#lines + 1] = fitText(current, maxWidth)
    end
    return lines
  end

  -- Preserve the useful part of the contributor's QoL change without making
  -- every description move. Text that fits remains a conventional wrapped
  -- paragraph. When it needs more rows, keep every complete leading row still
  -- and marquee only the remaining tail through the final row. The content,
  -- viewport and selection are all part of the key, so changing any of them
  -- predictably returns the text to its beginning.
  local function allWrappedLines(text, maxWidth)
    local lines = {}
    local source = tostring(text or ""):gsub("<NEXT>", "\n")
    for paragraph in (source .. "\n"):gmatch("(.-)\n") do
      local current = ""
      for word in paragraph:gmatch("%S+") do
        local candidate = current == "" and word or (current .. " " .. word)
        if current ~= "" and Font.width(candidate) > maxWidth then
          lines[#lines + 1] = current
          current = word
        else
          current = candidate
        end
      end
      if current ~= "" then lines[#lines + 1] = current end
    end
    return lines
  end

  local function descriptionScrollState(menu, key)
    local state = menu.modernBagDescriptionScroll
    if not state or state.key ~= key then
      state = { key = key, elapsed = 0, offset = 0, overflow = false }
      menu.modernBagDescriptionScroll = state
    end
    return state
  end

  local function clearDescriptionScroll(menu)
    menu.modernBagDescriptionScroll = nil
  end

  local function drawReadableDescription(menu, key, text, x, y,
      maxWidth, maxLines, shade)
    text = tostring(text or "")
    maxWidth = math.max(8, math.floor(maxWidth or 8))
    maxLines = math.max(1, math.floor(maxLines or 1))
    local lines = allWrappedLines(text, maxWidth)
    local fits = #lines <= maxLines
    for _, line in ipairs(lines) do
      if Font.width(line) > maxWidth then fits = false break end
    end

    local stateKey = table.concat({ tostring(key or "description"), text,
      tostring(maxWidth), tostring(maxLines) }, "\31")
    local state = descriptionScrollState(menu, stateKey)
    state.overflow = not fits
    state.maxWidth, state.maxLines = maxWidth, maxLines
    if fits then
      state.offset, state.travel = 0, 0
      for index, line in ipairs(lines) do
        drawText(line, x, y + (index - 1) * 9, maxWidth, shade)
      end
      return false
    end

    local staticCount = math.max(0, maxLines - 1)
    for index = 1, staticCount do
      local line = lines[index]
      if not line or Font.width(line) > maxWidth then
        staticCount = 0
        break
      end
    end
    for index = 1, staticCount do
      drawText(lines[index], x, y + (index - 1) * 9, maxWidth, shade)
    end
    local tail = {}
    for index = staticCount + 1, #lines do tail[#tail + 1] = lines[index] end
    if #tail == 0 then tail[1] = text end
    local tailText = table.concat(tail, "  ")
    local travel = math.max(0, Font.width(tailText) - maxWidth)
    local holdStart, holdEnd, speed = 1.0, 0.75, 36
    local moving = travel / speed
    local cycle = holdStart + moving + holdEnd
    local phase = cycle > 0 and ((state.elapsed or 0) % cycle) or 0
    local offset
    if phase <= holdStart then
      offset = 0
    elseif phase < holdStart + moving then
      offset = math.min(travel, (phase - holdStart) * speed)
    else
      offset = travel
    end
    state.offset, state.travel = offset, travel
    state.tailText, state.staticLines = tailText, staticCount

    local lineY = y + staticCount * 9
    if love.graphics.setScissor then
      love.graphics.push("all")
      love.graphics.setScissor(math.floor(x), math.floor(lineY), maxWidth, 9)
      drawTextRaw(tailText, x - offset, lineY, shade)
      love.graphics.pop()
    else
      drawText(tailText, x, lineY, maxWidth, shade)
    end
    return true
  end

  local function chamfer(mode, x, y, width, height, cut)
    cut = cut or 3
    if love.graphics.polygon then
      love.graphics.polygon(mode, {
        x + cut, y, x + width - cut, y,
        x + width, y + cut, x + width, y + height - cut,
        x + width - cut, y + height, x + cut, y + height,
        x, y + height - cut, x, y + cut,
      })
    else
      love.graphics.rectangle(mode, x, y, width, height)
    end
  end

  local function displayPixels()
    local width, height
    if love.graphics.getPixelDimensions then
      width, height = love.graphics.getPixelDimensions()
    else
      width, height = love.graphics.getDimensions()
    end
    return tonumber(width) or 160, tonumber(height) or SCREEN_H
  end

  -- The touch pad is painted after the game canvas. On portrait devices its
  -- controls can occupy a large lower section of the drawable, so treating
  -- that covered area as useful Bag height produces an unnecessarily tall
  -- canvas and forces the visible Bag above it to a smaller integer scale.
  local function portraitControlsTop(pixelWidth, pixelHeight)
    if pixelHeight <= pixelWidth then return nil end
    local okVisible, visible = pcall(TouchControls.visible, TouchControls)
    if not okVisible or not visible then return nil end
    local okLayout, controls = pcall(TouchControls.layout, TouchControls)
    if not okLayout or type(controls) ~= "table" then return nil end
    local _, unitHeight = love.graphics.getDimensions()
    unitHeight = tonumber(unitHeight) or pixelHeight
    if unitHeight <= 0 then return nil end
    local dpiY = pixelHeight / unitHeight
    local top
    for _, name in ipairs({ "dpad", "a", "b", "start", "select" }) do
      local zone = controls[name]
      if type(zone) == "table" and tonumber(zone.cy)
          and tonumber(zone.w) then
        -- TouchControls' backing disc is the first visible pixel of a
        -- control, at 0.58 times its configured width above the centre.
        local y = (zone.cy - zone.w * 0.58) * dpiY
        top = top and math.min(top, y) or y
      end
    end
    if not top then return nil end
    return math.max(SCREEN_H, math.floor(top))
  end

  local function responsiveSize()
    local width, height = displayPixels()
    local portraitWindow = height > width

    -- A wide window keeps the original 144px-tall responsive surface. A
    -- phone in portrait needs the inverse treatment: lock the readable
    -- 160px width, then use the vertical pixels available at that same
    -- integer scale. This avoids both a postage-stamp Bag and resampled text.
    local portraitScale = math.max(1, math.floor(width / 160))
    local portraitHeight = math.min(PORTRAIT_MAX_H,
      math.floor(height / portraitScale))
    if portraitWindow and portraitHeight >= PORTRAIT_MIN_H then
      return 160, portraitHeight
    end

    local scale = math.max(1, math.floor(height / SCREEN_H))
    return math.max(160, math.min(400, math.floor(width / scale))), SCREEN_H
  end

  -- FAITHFUL RATIO owns the shape of the complete UI surface. On desktop the
  -- option also resizes the window, so responsiveSize happens to arrive at
  -- 160x144. Phones cannot resize their window, however: the renderer locks
  -- a 160x144 viewport inside the physical display instead. Reading only the
  -- drawable dimensions there made the Bag request a tall 160x400 canvas and
  -- defeated that lock (most visibly alongside Useful Bag).
  local function faithfulRatioEnabled(menu)
    local options = menu and menu.game and menu.game.save
      and menu.game.save.options
    return (tonumber(options and options.faithfulRes) or 0) > 0
  end

  -- Useful Bag calls the same presentation choice FULLSCREEN BAG MENUS.
  -- OFF means its native Game Boy-sized pop-out, so Modern Bag must not
  -- replace that choice with its tall-phone canvas merely because it owns the
  -- shared BagMenu presentation record.
  local function usefulBagNativeMenus(menu)
    if not compatibility.usefulBag then return false end
    local game = menu and menu.game
    local loaderOptions = game and game.mods and game.mods.modOptions
    local savedOptions = game and game.save and game.save.options
      and game.save.options.modOptions
    local bucket = loaderOptions and loaderOptions.useful_bag
    local value = bucket and bucket.fullscreen_menu
    if value == nil then
      bucket = savedOptions and savedOptions.useful_bag
      value = bucket and bucket.fullscreen_menu
    end
    return value == false
  end

  local function nativeViewportRequested(menu)
    return faithfulRatioEnabled(menu) or usefulBagNativeMenus(menu)
  end

  local function confineNativeViewport(menu)
    if not nativeViewportRequested(menu) then return end
    local renderer = menu and menu.game and menu.game.renderer
    if renderer then
      -- Game:draw may inherit BATTLE SIZE = FILL from a battle underneath the
      -- Bag. Renderer:endFrame applies that after fitScale, which stretches a
      -- correctly-sized 160x144 canvas back over the whole phone. The Bag is
      -- a native pop-out in this mode, so the later fill override must not win.
      renderer.uiFill = false
    end
  end

  local function uiSize(menu)
    if nativeViewportRequested(menu) then return SCREEN_W, SCREEN_H end
    return responsiveSize()
  end

  local function layoutFor(menu)
    local nativeViewport = nativeViewportRequested(menu)
    local width, height = uiSize(menu)
    local renderer = menu and menu.game and menu.game.renderer
    -- Renderer:uiSize still describes the previous frame while an option or
    -- state is changing. Never let that stale responsive size override the
    -- explicit faithful-ratio request.
    if not nativeViewport and renderer and renderer.uiSize then
      local rendererW, rendererH = renderer:uiSize()
      width, height = rendererW or width, rendererH or height
    end
    width = math.max(160, math.floor(width))
    height = math.max(SCREEN_H, math.floor(height))
    local canvasHeight = height

    -- Keep the full responsive canvas—and therefore its larger integer
    -- scale—but end the actual Bag composition above visible touch controls.
    -- The unused lower canvas becomes a black control bed instead of making
    -- the Bag narrower or letting controls cover its description/footer.
    local pixelWidth, pixelHeight = displayPixels()
    local controlsTop = portraitControlsTop(pixelWidth, pixelHeight)
    if controlsTop then
      local scale = math.max(1, math.floor(math.min(
        pixelWidth / width, pixelHeight / canvasHeight)))
      local offsetY = math.max(0,
        math.floor((pixelHeight - canvasHeight * scale) / 2))
      local usableHeight = math.floor((controlsTop - offsetY) / scale)
      if usableHeight >= PORTRAIT_MIN_H then
        height = math.min(height, usableHeight)
      end
    end
    local wide = width >= 196
    local stacked = not wide and height >= PORTRAIT_MIN_H

    if classicSkin() then
      local headerH = stacked and 18 or 14
      local detailH = stacked and 84 or 40
      local detailY = height - detailH
      local topRail = stacked
      local railW = topRail and width
        or (wide and math.max(56, math.floor(width * 0.25)) or 48)
      local railH = topRail and 48 or (detailY - headerH)
      local listX = topRail and 0 or railW
      local listY = topRail and (headerH + railH) or headerH
      local listW = topRail and width or (width - railW)
      local listH = detailY - listY
      local headerLeftW = menu and not menu.modernBagListConfig
        and math.max(48, Font.width(moneyText(menu)) + 4) or 48
      headerLeftW = math.min(headerLeftW, width - 28)
      local rows = math.max(4, math.min(stacked and 10 or 6,
        math.floor((listH - 5) / ROW_H)))
      return {
        skin = "classic_pocket",
        width = width, height = height, canvasHeight = canvasHeight,
        wide = wide, stacked = stacked, topRail = topRail,
        showDetails = true,
        headerH = headerH, tabsY = headerH, tabsH = 0,
        contentY = listY, footerY = detailY, footerH = detailH,
        rows = rows,
        railX = 0, railY = headerH, railW = railW,
        railH = railH,
        listX = listX, listY = listY,
        listW = listW, listH = listH,
        headerAccentX = topRail and headerLeftW
          or math.max(listX, headerLeftW),
        headerAccentW = width - (topRail and headerLeftW
          or math.max(listX, headerLeftW)),
        detailX = 0, detailY = detailY,
        detailW = width, detailH = detailH,
      }
    end

    local headerH = stacked and 24 or HEADER_H
    local tabsY = headerH
    local contentY = tabsY + TABS_H
    local expandedFooter = menu and (menu.modernPCUI or menu.modernBagPrompt)
    local footerH = stacked and 20 or (expandedFooter and 16 or FOOTER_H)
    local footerY = height - footerH
    local listY = contentY + 3

    if stacked then
      local detailMinH = 82
      local rows = math.floor((footerY - listY - detailMinH - 12) / ROW_H)
      rows = math.max(4, math.min(10, rows))
      local listH = rows * ROW_H + 8
      local detailY = listY + listH + 4
      return {
        width = width, height = height, canvasHeight = canvasHeight,
        wide = false, stacked = true, showDetails = true,
        headerH = headerH, tabsY = tabsY, tabsH = TABS_H,
        contentY = contentY, footerY = footerY, footerH = footerH,
        rows = rows,
        listX = 4, listY = listY, listW = width - 12, listH = listH,
        detailX = 4, detailY = detailY,
        detailW = width - 8, detailH = footerY - detailY - 3,
      }
    end

    local listColumnW = wide and math.floor(width * 0.54) or width - 8
    listColumnW = math.max(96, listColumnW)
    local rows = expandedFooter
      and math.max(4, math.floor((footerY - listY - 8) / ROW_H))
      or ROWS
    return {
      width = width, height = height, canvasHeight = canvasHeight,
      wide = wide, stacked = false, showDetails = wide,
      headerH = headerH, tabsY = tabsY, tabsH = TABS_H,
      contentY = contentY, footerY = footerY, footerH = footerH,
      rows = rows,
      listX = 4,
      listY = listY,
      listW = listColumnW - 4,
      listH = footerY - contentY - 6,
      detailX = listColumnW + 4,
      detailY = listY,
      detailW = width - listColumnW - 8,
      detailH = footerY - contentY - 6,
    }
  end

  local function normalizedPocket(value)
    value = tostring(value or ""):lower():gsub("[^a-z]", "")
    local aliases = {
      item = "items", items = "items", other = "items",
      medicine = "medicine", medicines = "medicine", healing = "medicine",
      ball = "balls", balls = "balls", pokeballs = "balls",
      battle = "battle", battleitems = "battle",
      tm = "machines", tms = "machines", hm = "machines",
      hms = "machines", machine = "machines", machines = "machines",
      key = "key", keyitem = "key", keyitems = "key",
      berry = "berries", berries = "berries",
    }
    return aliases[value]
  end

  local function categoryFor(game, id)
    if not id then return "items" end
    local def = game.data.items[id] or {}
    local explicit = normalizedPocket(def.bagPocket or def.pocket)
    if explicit then return explicit end
    if BERRIES[id] or def.holdEffect == "berry"
        or def.holdEffect == "berry_status" then
      return "berries"
    end
    if ItemEffects.isBall(id) or def.ball then return "balls" end
    if def.machine then return "machines" end
    if def.keyItem then return "key" end
    if MEDICINE[id] then return "medicine" end
    return "items"
  end

  local function pocketsFor(menu)
    return menu.modernBagPockets or POCKETS
  end

  local function pocketFor(menu)
    local pockets = pocketsFor(menu)
    return pockets[menu.modernBagPocket or 1] or pockets[1] or POCKETS[1]
  end

  local function syncExternalPocketIndex(menu)
    if not menu.modernBagExternalController then return end
    local sourceIds = menu.__pocketIds or {}
    local source = sourceIds[menu.__pocketIndex or 1]
    local pockets = pocketsFor(menu)
    for index, pocket in ipairs(pockets) do
      if pocket.source == source or pocket.key == source then
        menu.modernBagPocket = index
        return
      end
    end
    menu.modernBagPocket = math.max(1,
      math.min(menu.__pocketIndex or 1, #pockets))
  end

  local function listConfig(menu)
    return menu.modernBagListConfig
  end

  local function itemStore(menu)
    local config = listConfig(menu)
    if config and type(config.store) == "function" then
      return config.store(menu) or {}
    end
    return menu.game.save.inventory
  end

  local function orderedIds(menu, store)
    local config = listConfig(menu)
    if config and type(config.order) == "function" then
      return config.order(menu, store) or {}
    end
    -- Kanto filters Bag.order globally while one pocket is open. Counts and
    -- change detection need the complete order, not only the active pocket.
    if menu.modernBagExternalController then
      local order = menu.game.save.bagOrder
      if type(order) == "table" then return order end
      local ids = {}
      for id in pairs(store or {}) do ids[#ids + 1] = id end
      table.sort(ids)
      return ids
    end
    return Bag.order(menu.game.save)
  end

  local function included(menu, id)
    local config = listConfig(menu)
    return not (config and type(config.filter) == "function")
      or config.filter(menu, id)
  end

  local function makeRows(menu, pocketKey)
    local rows = {}
    local store = itemStore(menu)
    for _, id in ipairs(orderedIds(menu, store)) do
      if included(menu, id)
          and (pocketKey == "all" or categoryFor(menu.game, id) == pocketKey) then
        local def = menu.game.data.items[id]
        rows[#rows + 1] = {
          value = id,
          label = def and def.name or id,
          right = "x" .. tostring(store[id] or 0),
        }
      end
    end
    return rows
  end

  local function inventorySignature(menu)
    local parts = {}
    local store = itemStore(menu)
    for _, id in ipairs(orderedIds(menu, store)) do
      if included(menu, id) then
        parts[#parts + 1] = id .. ":" .. tostring(store[id])
      end
    end
    return table.concat(parts, "|")
  end

  local function clampList(menu)
    local count = #menu.items
    local rows = math.max(1, menu.rows or ROWS)
    menu.index = math.max(1, math.min(menu.index or 1, math.max(1, count)))
    menu.scroll = math.max(0, math.min(menu.scroll or 0,
      math.max(0, count - rows)))
    if menu.index - menu.scroll > rows then
      menu.scroll = menu.index - rows
    elseif menu.index - menu.scroll < 1 then
      menu.scroll = menu.index - 1
    end
  end

  local function rebuildPocket(menu, preserveId)
    if menu.modernBagExternalController then
      local api = menu.gen1ModernUi
      if api and type(api.switchPocket) == "function" then
        api:switchPocket(0)
      end
      syncExternalPocketIndex(menu)
      if preserveId then
        for index, item in ipairs(menu.items or {}) do
          if item.value == preserveId then
            menu.index = index
            break
          end
        end
      end
      clampList(menu)
      menu.modernBagInventorySignature = inventorySignature(menu)
      return
    end
    local key = pocketFor(menu).key
    menu.items = makeRows(menu, key)
    if preserveId then
      for index, item in ipairs(menu.items) do
        if item.value == preserveId then
          menu.index = index
          break
        end
      end
    end
    clampList(menu)
    menu.modernBagInventorySignature = inventorySignature(menu)
    if menu.modernBagSwapId and not itemStore(menu)[menu.modernBagSwapId] then
      menu.modernBagSwapId = nil
    end
  end

  local function selectedId(menu)
    local item = menu.items and menu.items[menu.index]
    return item and item.value or nil
  end

  local function swapId(menu)
    if menu.modernBagSwapId then return menu.modernBagSwapId end
    local item = menu.swapIndex and menu.items and menu.items[menu.swapIndex]
    return item and item.value or nil
  end

  local function syncInventory(menu)
    local signature = inventorySignature(menu)
    local pocket = pocketFor(menu)
    local rowsMatchPocket = true
    if pocket and pocket.key ~= "all" then
      for _, item in ipairs(menu.items or {}) do
        if item.value
            and categoryFor(menu.game, item.value) ~= pocket.key then
          rowsMatchPocket = false
          break
        end
      end
    end
    -- Native and companion item-use controllers are allowed to rebuild the
    -- Bag's rows while PartyMenu owns input. Some rebuild the cartridge's
    -- complete item list without changing inventory, so the quantity-only
    -- signature cannot notice the damage. Validate the visible membership as
    -- well and reapply the active pocket before drawing it again.
    if signature ~= menu.modernBagInventorySignature
        or not rowsMatchPocket then
      rebuildPocket(menu, selectedId(menu))
    end
  end

  local function switchPocket(menu, delta)
    if menu.modernBagExternalController then
      local api = menu.gen1ModernUi
      if api and type(api.switchPocket) == "function" then
        api:switchPocket(delta or 0)
        syncExternalPocketIndex(menu)
        clampList(menu)
        menu.modernBagInventorySignature = inventorySignature(menu)
      end
      return
    end
    local current = pocketFor(menu)
    menu.modernBagPocketState[current.key] = {
      id = selectedId(menu), index = menu.index, scroll = menu.scroll,
    }
    local pockets = pocketsFor(menu)
    menu.modernBagPocket = ((menu.modernBagPocket - 1 + delta) % #pockets) + 1
    menu.modernBagSwapId = nil
    local nextPocket = pocketFor(menu)
    local saved = menu.modernBagPocketState[nextPocket.key]
    menu.index = saved and saved.index or 1
    menu.scroll = saved and saved.scroll or 0
    rebuildPocket(menu, saved and saved.id)
  end

  local function finishSwap(menu, targetId)
    local sourceId = menu.modernBagSwapId
    menu.modernBagSwapId = nil
    if not sourceId or not targetId then return end
    local order = Bag.order(menu.game.save)
    local sourceIndex, targetIndex
    for index, id in ipairs(order) do
      if id == sourceId then sourceIndex = index end
      if id == targetId then targetIndex = index end
    end
    if sourceIndex and targetIndex then
      order[sourceIndex], order[targetIndex] = order[targetIndex], order[sourceIndex]
      local ok = menu.game and menu.game.data
      if ok then require("src.core.Sound").play(menu.game.data, "Swap") end
    end
    rebuildPocket(menu, sourceId)
  end

  local function reorder(menu, item)
    if not item then return end
    if menu.modernBagSwapId then
      finishSwap(menu, item.value)
    else
      menu.modernBagSwapId = item.value
    end
  end

  local function categoryRanks(menu)
    local ranks = {}
    local nextRank = 1
    for _, pocket in ipairs(pocketsFor(menu)) do
      if pocket.key ~= "all" and ranks[pocket.key] == nil then
        ranks[pocket.key] = nextRank
        nextRank = nextRank + 1
      end
    end
    return ranks, nextRank
  end

  -- Sort the canonical Bag order in place so quantities, item ownership and
  -- every native item action remain untouched. Category sorts deliberately
  -- preserve the player's existing order inside each pocket; this makes the
  -- operation useful as a quick grouping command without destroying a
  -- carefully arranged medicine or TM list.
  local function sortBag(menu, kind, descending)
    if listConfig(menu) then return false end
    local save = menu.game and menu.game.save
    local store = save and save.inventory
    if type(store) ~= "table" then return false end

    local selected = selectedId(menu)
    local entries = {}
    for index, id in ipairs(orderedIds(menu, store)) do
      if store[id] and not Bag.isBadge(id) then
        local def = menu.game.data.items[id] or {}
        entries[#entries + 1] = {
          id = id,
          original = index,
          name = tostring(def.name or id):lower(),
          category = categoryFor(menu.game, id),
        }
      end
    end

    local ranks, unknownRank = categoryRanks(menu)
    table.sort(entries, function(a, b)
      if kind == "category" then
        local av = ranks[a.category] or unknownRank
        local bv = ranks[b.category] or unknownRank
        if av ~= bv then
          if descending then return av > bv end
          return av < bv
        end
        return a.original < b.original
      end
      if a.name ~= b.name then
        if descending then return a.name > b.name end
        return a.name < b.name
      end
      if descending then return a.id > b.id end
      return a.id < b.id
    end)

    local order = save.bagOrder
    if type(order) ~= "table" then
      order = {}
      save.bagOrder = order
    end
    for index = #order, 1, -1 do order[index] = nil end
    for index, entry in ipairs(entries) do order[index] = entry.id end
    menu.modernBagSwapId = nil
    rebuildPocket(menu, selected)
    return true
  end

  local function openSortMenu(menu)
    if listConfig(menu) then return false end
    menu.modernBagSwapId = nil
    local choices = {
      { label = Strings("CATEGORY ASC"), kind = "category" },
      { label = Strings("CATEGORY DESC"), kind = "category",
        descending = true },
      { label = Strings("NAMES A-Z"), kind = "name" },
      { label = Strings("NAMES Z-A"), kind = "name", descending = true },
    }
    local rows = {}
    for index, choice in ipairs(choices) do
      local kind, descending = choice.kind, choice.descending
      rows[index] = {
        label = choice.label,
        onSelect = function()
          sortBag(menu, kind, descending)
        end,
      }
    end

    -- Menu's rows are bottom-anchored, so the slightly taller box leaves a
    -- dedicated heading band without introducing a second menu controller.
    local sortMenu = Menu.new(menu.game, rows, {
      tx = 2, ty = 3, tw = 16, th = 9, rowStep = 1.5,
      startCloses = true,
    })
    sortMenu.modernBagSortMenu = true
    local drawRows = sortMenu.draw
    sortMenu.draw = function(self)
      drawRows(self)
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(Strings("SORT BY"), (self.tx + 1) * 8,
        (self.ty + 1) * 8)
      love.graphics.setColor(1, 1, 1, 1)
    end
    menu.game.stack:push(sortMenu)
    return true
  end

  local function pocketCounts(menu)
    local counts = { all = 0, items = 0, medicine = 0, balls = 0,
      machines = 0, key = 0, berries = 0 }
    local store = itemStore(menu)
    for _, id in ipairs(orderedIds(menu, store)) do
      if included(menu, id) then
        counts.all = counts.all + 1
        local category = categoryFor(menu.game, id)
        counts[category] = (counts[category] or 0) + 1
      end
    end
    return counts
  end

  local function drawPocketSymbol(key, x, y, size)
    x, y, size = math.floor(x), math.floor(y), math.max(8, math.floor(size))
    local unit = math.max(1, math.floor(size / 8))
    if key == "all" then
      gray(DARK)
      love.graphics.rectangle("line", x + 2 * unit, y + unit,
        size - 4 * unit, 3 * unit)
      love.graphics.rectangle("fill", x, y + 3 * unit,
        2 * unit, size - 4 * unit)
      love.graphics.rectangle("fill", x + size - 2 * unit, y + 3 * unit,
        2 * unit, size - 4 * unit)
      love.graphics.rectangle("fill", x + 2 * unit, y + 2 * unit,
        size - 4 * unit, size - 2 * unit)
      gray(LIGHT)
      love.graphics.rectangle("fill", x + 3 * unit, y + 3 * unit,
        size - 6 * unit, size - 4 * unit)
      gray(DARK)
      love.graphics.rectangle("line", x + 3 * unit, y + 5 * unit,
        size - 6 * unit, 2 * unit)
    elseif key == "items" then
      gray(LIGHT)
      if love.graphics.polygon then
        love.graphics.polygon("fill", x + size / 2, y,
          x + size, y + size / 2, x + size / 2, y + size,
          x, y + size / 2)
      else
        love.graphics.rectangle("fill", x + unit, y + unit,
          size - 2 * unit, size - 2 * unit)
      end
      gray(DARK)
      love.graphics.rectangle("fill", x + size / 2 - unit / 2,
        y + 2 * unit, unit, size - 4 * unit)
    elseif key == "medicine" then
      gray(DARK)
      love.graphics.rectangle("fill", x + 3 * unit, y,
        size - 6 * unit, 2 * unit)
      gray(LIGHT)
      love.graphics.rectangle("fill", x + 2 * unit, y + 2 * unit,
        size - 4 * unit, size - 2 * unit)
      gray(BLACK)
      love.graphics.rectangle("fill", x + 3 * unit, y + 4 * unit,
        size - 6 * unit, unit)
      love.graphics.rectangle("fill", x + size / 2 - unit / 2,
        y + 3 * unit, unit, 3 * unit)
    elseif key == "balls" then
      gray(LIGHT)
      love.graphics.circle("fill", x + size / 2, y + size / 2, size / 2)
      gray(DARK)
      love.graphics.rectangle("fill", x, y + size / 2 - unit / 2,
        size, unit)
      gray(BLACK)
      love.graphics.circle("fill", x + size / 2, y + size / 2, 2 * unit)
      gray(WHITE)
      love.graphics.circle("fill", x + size / 2, y + size / 2, unit)
    elseif key == "battle" then
      gray(LIGHT)
      love.graphics.rectangle("fill", x + 3 * unit, y,
        2 * unit, size)
      love.graphics.rectangle("fill", x, y + 3 * unit,
        size, 2 * unit)
      gray(DARK)
      love.graphics.rectangle("fill", x + 2 * unit, y + 2 * unit,
        4 * unit, 4 * unit)
    elseif key == "machines" then
      gray(LIGHT)
      love.graphics.circle("fill", x + size / 2, y + size / 2, size / 2)
      gray(DARK)
      love.graphics.circle("fill", x + size / 2, y + size / 2, 3 * unit)
      gray(BLACK)
      love.graphics.circle("fill", x + size / 2, y + size / 2, unit)
    elseif key == "key" then
      gray(LIGHT)
      love.graphics.circle("line", x + 2 * unit, y + 2 * unit, 2 * unit)
      love.graphics.rectangle("fill", x + 3 * unit, y + 3 * unit,
        size - 3 * unit, 2 * unit)
      love.graphics.rectangle("fill", x + 6 * unit, y + 5 * unit,
        2 * unit, 2 * unit)
    elseif key == "berries" then
      gray(LIGHT)
      love.graphics.circle("fill", x + size / 2, y + size / 2 + unit,
        3 * unit)
      gray(DARK)
      love.graphics.rectangle("fill", x + 4 * unit, y,
        unit, 3 * unit)
      love.graphics.rectangle("fill", x + 5 * unit, y + unit,
        2 * unit, unit)
      gray(BLACK)
      love.graphics.rectangle("fill", x + 3 * unit, y + 4 * unit,
        unit, unit)
    end
  end

  local function drawBackdrop(layout)
    gray(BLACK)
    love.graphics.rectangle("fill", 0, 0,
      layout.width, layout.canvasHeight or layout.height)
    gray(WHITE)
    love.graphics.rectangle("fill", 0, 0, layout.width, layout.height)
    gray(LIGHT)
    for x = -layout.height, layout.width, 24 do
      love.graphics.line(x, layout.contentY, x + layout.height, layout.footerY)
    end
  end

  local function drawHeader(menu, layout)
    local pocket = pocketFor(menu)
    local config = listConfig(menu)
    gray(DARK)
    love.graphics.rectangle("fill", 0, 0, layout.width, layout.headerH)

    local capacity
    if config and type(config.capacity) == "function" then
      capacity = tostring(config.capacity(menu) or "")
    else
      capacity = ("%d/%d"):format(Bag.slots(menu.game.save),
        Bag.capacity(menu.game.data))
    end
    local capacityW = math.min(math.floor(layout.width * 0.36),
      math.max(24, Font.width(capacity) + 2))
    local left = Strings(config and config.header or moneyText(menu))
    local leftW = math.min(math.floor(layout.width * 0.42),
      math.max(32, Font.width(left) + 2))
    local headerY = layout.stacked and 2 or 4
    drawText(left, 5, headerY, leftW, WHITE)
    drawTextRight(capacity, layout.width - 5, headerY, capacityW, WHITE)
    menu.modernBagHeaderCash = config and nil or left

    local label
    if config then
      label = (layout.wide or layout.stacked)
        and (config.label or config.short) or config.short
    else
      label = (layout.wide or layout.stacked) and pocket.label or pocket.short
    end
    -- The right side already reports the total slot count. Repeating the
    -- active pocket count after the label made ALL ITEMS read like
    -- "ALL ITEMS 4646/255" once the Bag held 46 unique items.
    local center = Strings(label)
    local centerX = layout.stacked and 5 or (5 + leftW + 3)
    local centerRight = layout.stacked and (layout.width - 5)
      or (layout.width - 5 - capacityW - 3)
    local centerWidth = math.max(0, centerRight - centerX)
    center = fitText(center, centerWidth)
    menu.modernBagHeaderBounds = {
      cash = not config, leftX = 5,
      leftRight = 5 + math.min(leftW, Font.width(left)),
      titleX = centerX, titleRight = centerRight,
      capacityLeft = layout.width - 5 - capacityW,
      twoRows = layout.stacked and true or false,
    }
    drawText(center, centerX + (centerWidth - Font.width(center)) / 2,
      layout.stacked and 13 or 4,
      centerWidth, WHITE)
  end

  local function drawTabs(menu, layout, counts)
    gray(LIGHT)
    love.graphics.rectangle("fill", 0, layout.tabsY, layout.width, layout.tabsH)
    local pockets = pocketsFor(menu)
    local gap = layout.width >= 210 and 3 or 1
    local available = layout.width - 8 - gap * (#pockets - 1)
    local tabW = math.floor(available / #pockets)
    local totalW = tabW * #pockets + gap * (#pockets - 1)
    local x0 = math.floor((layout.width - totalW) / 2)

    for index, pocket in ipairs(pockets) do
      local x = x0 + (index - 1) * (tabW + gap)
      local active = index == menu.modernBagPocket
      if active then
        gray(BLACK)
        chamfer("fill", x, layout.tabsY + 1, tabW, layout.tabsH - 1, 2)
        gray(DARK)
        chamfer("fill", x + 1, layout.tabsY + 2,
          tabW - 2, layout.tabsH - 3, 2)
      else
        gray(WHITE)
        chamfer("fill", x, layout.tabsY + 3,
          tabW, layout.tabsH - 5, 2)
      end
      local iconSize = math.min(10, tabW - 4)
      drawPocketSymbol(pocket.key,
        x + math.floor((tabW - iconSize) / 2), layout.tabsY + 4, iconSize)
      gray(active and WHITE or DARK)
      local markerW = math.min(tabW - 6, math.max(2, counts[pocket.key] or 0))
      love.graphics.rectangle("fill", x + math.floor((tabW - markerW) / 2),
        layout.tabsY + layout.tabsH - 3, markerW, 2)
    end
  end

  local function drawList(menu, layout)
    gray(BLACK)
    chamfer("fill", layout.listX + 2, layout.listY + 2,
      layout.listW, layout.listH, 4)
    gray(WHITE)
    chamfer("fill", layout.listX, layout.listY,
      layout.listW, layout.listH, 4)
    gray(LIGHT)
    chamfer("fill", layout.listX + 2, layout.listY + 2,
      layout.listW - 4, layout.listH - 4, 3)

    if #menu.items == 0 then
      local config = listConfig(menu)
      local empty = config and config.empty
      local line1 = Strings(empty and empty[1] or "THIS POCKET")
      local line2 = Strings(empty and empty[2] or "IS EMPTY")
      drawText(line1, layout.listX + (layout.listW - Font.width(line1)) / 2,
        layout.listY + 31, layout.listW - 12, DARK)
      drawText(line2, layout.listX + (layout.listW - Font.width(line2)) / 2,
        layout.listY + 43, layout.listW - 12, DARK)
      return
    end

    for row = 1, layout.rows do
      local index = menu.scroll + row
      local item = menu.items[index]
      if not item then break end
      local y = layout.listY + 4 + (row - 1) * ROW_H
      local selected = index == menu.index
      if selected then
        gray(BLACK)
        chamfer("fill", layout.listX + 4, y - 1,
          layout.listW - 8, 13, 2)
        gray(DARK)
        chamfer("fill", layout.listX + 5, y,
          layout.listW - 10, 11, 2)
      elseif row % 2 == 0 then
        gray(WHITE)
        love.graphics.rectangle("fill", layout.listX + 5, y - 1,
          layout.listW - 10, 13)
      end

      local shade = selected and WHITE or BLACK
      local quantity = item.right or ""
      local qWidth = Font.width(quantity)
      drawText(item.label, layout.listX + 17, y + 1,
        layout.listW - qWidth - 30, shade)
      drawTextRight(quantity, layout.listX + layout.listW - 8, y + 1,
        qWidth + 8, shade)
      if selected then
        drawCode(Theme.cursor, layout.listX + 7, y + 1, shade)
      elseif item.value == swapId(menu) then
        drawCode(Theme.cursorHollow, layout.listX + 7, y + 1, BLACK)
      end
    end

    if menu.scroll > 0 then
      gray(DARK)
      if love.graphics.polygon then
        love.graphics.polygon("fill", layout.listX + layout.listW - 8,
          layout.listY + 4, layout.listX + layout.listW - 4,
          layout.listY + 4, layout.listX + layout.listW - 6,
          layout.listY + 1)
      else
        love.graphics.rectangle("fill", layout.listX + layout.listW - 7,
          layout.listY + 2, 3, 2)
      end
    end
    if menu.scroll + layout.rows < #menu.items then
      gray(DARK)
      if love.graphics.polygon then
        love.graphics.polygon("fill", layout.listX + layout.listW - 8,
          layout.listY + layout.listH - 4, layout.listX + layout.listW - 4,
          layout.listY + layout.listH - 4, layout.listX + layout.listW - 6,
          layout.listY + layout.listH - 1)
      else
        love.graphics.rectangle("fill", layout.listX + layout.listW - 7,
          layout.listY + layout.listH - 3, 3, 2)
      end
    end
  end

  local function itemDescription(menu, id)
    if not id then return Strings("Return to the previous screen.") end
    local def = menu.game.data.items[id] or {}
    if type(def.description) == "string" and def.description ~= "" then
      return Strings(def.description)
    end
    if DESCRIPTIONS[id] then return Strings(DESCRIPTIONS[id]) end
    if def.machine then
      local move = menu.game.data.moves and menu.game.data.moves[def.machine.move]
      local moveName = move and move.name or def.machine.move
      return Strings("Teaches %s to a compatible POKéMON.", moveName)
    end
    local category = categoryFor(menu.game, id)
    if category == "balls" then
      return Strings("A device for catching wild POKéMON.")
    elseif category == "medicine" then
      return Strings("A medicine used to help a POKéMON.")
    elseif category == "battle" then
      return Strings("An item intended for use in battle.")
    elseif category == "key" then
      return Strings("An important item for your adventure.")
    elseif category == "berries" then
      return Strings("A Berry that a POKéMON can use or hold.")
    end
    return Strings("A useful item for your journey.")
  end

  local function drawDetails(menu, layout)
    if not layout.showDetails then return end
    local pocket = pocketFor(menu)

    if layout.stacked then
      gray(BLACK)
      chamfer("fill", layout.detailX + 2, layout.detailY + 2,
        layout.detailW, layout.detailH, 4)
      gray(WHITE)
      chamfer("fill", layout.detailX, layout.detailY,
        layout.detailW, layout.detailH, 4)
      gray(LIGHT)
      chamfer("fill", layout.detailX + 2, layout.detailY + 2,
        layout.detailW - 4, layout.detailH - 4, 3)

      local item = menu.items[menu.index]
      local config = listConfig(menu)
      local caption = config and config.direction
        or (item and categoryFor(menu.game, item.value) or pocket.key)
      drawText(caption:upper(), layout.detailX + 6, layout.detailY + 5,
        layout.detailW - 12, DARK)
      local status = config and type(config.detailStatus) == "function"
        and config.detailStatus(menu)
      if status and status ~= "" then
        drawTextRight(status, layout.detailX + layout.detailW - 6,
          layout.detailY + 5, math.floor(layout.detailW * 0.42), DARK)
      end

      local category = item and categoryFor(menu.game, item.value) or pocket.key
      local iconSize = math.min(28, math.max(20, layout.detailH - 56))
      drawPocketSymbol(category, layout.detailX + 8, layout.detailY + 20,
        iconSize)
      local textX = layout.detailX + iconSize + 14
      local textW = layout.detailX + layout.detailW - 6 - textX
      local name = item and item.label
        or (config and config.emptyName) or pocket.label
      local nameLines = wrappedLines(name, textW, 2)
      for index, line in ipairs(nameLines) do
        drawText(line, textX, layout.detailY + 24 + (index - 1) * 9,
          textW, BLACK)
      end
      local description = item and itemDescription(menu, item.value)
        or Strings(config and config.blurb or pocket.blurb)
      local descriptionY = layout.detailY + 20 + iconSize + 4
      local descriptionW = layout.detailW - 12
      local maxLines = math.max(2, math.floor(
        (layout.detailY + layout.detailH - 4 - descriptionY) / 9))
      if item and not config and not menu.modernBagPrompt
          and not swapId(menu) then
        drawReadableDescription(menu, item.value, description,
          layout.detailX + 6, descriptionY, descriptionW, maxLines, DARK)
      else
        clearDescriptionScroll(menu)
        for index, line in ipairs(wrappedLines(
            description, descriptionW, maxLines)) do
          drawText(line, layout.detailX + 6,
            descriptionY + (index - 1) * 9, descriptionW, DARK)
        end
      end
      return
    end

    gray(BLACK)
    chamfer("fill", layout.detailX + 2, layout.detailY + 2,
      layout.detailW, layout.detailH, 4)
    gray(DARK)
    chamfer("fill", layout.detailX, layout.detailY,
      layout.detailW, layout.detailH, 4)
    gray(BLACK)
    chamfer("fill", layout.detailX + 2, layout.detailY + 2,
      layout.detailW - 4, layout.detailH - 4, 3)

    local item = menu.items[menu.index]
    local config = listConfig(menu)
    local caption = config and config.direction
      or (item and categoryFor(menu.game, item.value) or pocket.key)
    caption = caption:upper()
    drawText(caption, layout.detailX + 6, layout.detailY + 5,
      layout.detailW - 12, LIGHT)

    if item then
      local category = categoryFor(menu.game, item.value)
      local iconSize = 24
      drawPocketSymbol(category,
        layout.detailX + math.floor((layout.detailW - iconSize) / 2),
        layout.detailY + 17, iconSize)
      local nameLines = wrappedLines(item.label, layout.detailW - 12, 2)
      for index, line in ipairs(nameLines) do
        drawText(line,
          layout.detailX + (layout.detailW - Font.width(line)) / 2,
          layout.detailY + 45 + (index - 1) * 9,
          layout.detailW - 12, WHITE)
      end
      local descriptionY = layout.detailY + 58
        + math.max(0, #nameLines - 1) * 9
      local descriptionLines
      if config then
        descriptionLines = math.max(1, math.floor(
          (layout.detailY + layout.detailH - 2 - descriptionY - 8) / 9) + 1)
      else
        descriptionLines = math.max(1, math.floor(
          (layout.detailY + layout.detailH - 4 - descriptionY) / 9))
      end
      local description = itemDescription(menu, item.value)
      if not config and not menu.modernBagPrompt and not swapId(menu) then
        drawReadableDescription(menu, item.value, description,
          layout.detailX + 6, descriptionY,
          layout.detailW - 12, descriptionLines, LIGHT)
      else
        clearDescriptionScroll(menu)
        local lines = wrappedLines(description,
          layout.detailW - 12, descriptionLines)
        for index, line in ipairs(lines) do
          drawText(line, layout.detailX + 6,
            descriptionY + (index - 1) * 9,
            layout.detailW - 12, LIGHT)
        end
      end
    else
      drawPocketSymbol(pocket.key,
        layout.detailX + math.floor((layout.detailW - 28) / 2),
        layout.detailY + 20, 28)
      local lines = wrappedLines(
        Strings(config and config.blurb or pocket.blurb),
        layout.detailW - 12, 3)
      clearDescriptionScroll(menu)
      for index, line in ipairs(lines) do
        drawText(line, layout.detailX + 6,
          layout.detailY + 58 + (index - 1) * 9,
          layout.detailW - 12, LIGHT)
      end
    end

  end

  local function drawFooter(menu, layout)
    gray(DARK)
    love.graphics.rectangle("fill", 0, layout.footerY,
      layout.width, layout.footerH)
    local config = listConfig(menu)
    if config or menu.modernBagPrompt then
      local lines
      local status = config and menu.footer or menu.modernBagPrompt
      if status then
        lines = wrappedLines(Strings(status):gsub("\n", " "),
          layout.width - 8, 2)
      elseif config and layout.wide then
        lines = { Strings("L/R POCKET  A SELECT  B BACK") }
      else
        lines = { Strings("L/R POCKET"), Strings("A SELECT  B BACK") }
      end
      if #lines == 0 then lines = { "" } end
      local step = 8
      local y = layout.footerY
        + math.max(0, math.floor((layout.footerH - #lines * step) / 2))
      for index, line in ipairs(lines) do
        line = fitText(line, layout.width - 8)
        drawText(line, (layout.width - Font.width(line)) / 2,
          y + (index - 1) * step, layout.width - 8, WHITE)
      end
      return
    end
    if layout.stacked then
      local line1, line2
      if swapId(menu) then
        line1 = Strings("CHOOSE NEW POSITION")
        line2 = Strings("A PLACE  B BACK")
      else
        line1 = Strings("L/R POCKET START SORT")
        line2 = Strings("A USE  B BACK")
      end
      line1 = fitText(line1, layout.width - 8)
      line2 = fitText(line2, layout.width - 8)
      drawText(line1, (layout.width - Font.width(line1)) / 2,
        layout.footerY + 1, layout.width - 8, WHITE)
      drawText(line2, (layout.width - Font.width(line2)) / 2,
        layout.footerY + 11, layout.width - 8, WHITE)
      return
    end

    local message
    if swapId(menu) then
      message = Strings("CHOOSE A NEW POSITION")
    elseif layout.wide then
      message = Strings("L/R POCKET  START SORT  A SELECT  B BACK")
    else
      message = Strings("START SORT  B BACK")
    end
    message = fitText(message, layout.width - 8)
    drawText(message, (layout.width - Font.width(message)) / 2,
      layout.footerY, layout.width - 8, WHITE)
  end

  -- A second skin inspired by the late-era Pocket Bag: a black title strip,
  -- woven blue pocket rail, red active-pocket frame, clean white item sheet
  -- and a full-width description card. It keeps the same controller and
  -- responsive layout contract as the modern skin.
  local function drawClassicBackdrop(layout)
    gray(BLACK)
    love.graphics.rectangle("fill", 0, 0,
      layout.width, layout.canvasHeight or layout.height)
    gray(WHITE)
    love.graphics.rectangle("fill", 0, 0, layout.width, layout.height)
    gray(BLACK)
    love.graphics.rectangle("fill", 0, 0, layout.width, layout.headerH)

    gray(LIGHT)
    love.graphics.rectangle("fill", layout.railX, layout.railY,
      layout.railW, layout.railH)
    for y = layout.railY, layout.railY + layout.railH - 1, 4 do
      local phase = math.floor((y - layout.railY) / 4) % 2
      for x = layout.railX + phase * 2,
          layout.railX + layout.railW - 1, 4 do
        gray(DARK)
        love.graphics.rectangle("fill", x, y, 2, 2)
        gray(WHITE)
        love.graphics.rectangle("fill", x + 2, y + 2, 2, 2)
      end
    end
  end

  local function drawClassicHeader(menu, layout)
    local pocket = pocketFor(menu)
    local config = listConfig(menu)
    local left = Strings(config and (config.header or "POCKET")
      or moneyText(menu))
    local capacity
    if config and type(config.capacity) == "function" then
      capacity = tostring(config.capacity(menu) or "")
    else
      capacity = ("%d/%d"):format(Bag.slots(menu.game.save),
        Bag.capacity(menu.game.data))
    end
    local capacityW = math.min(math.floor(layout.width * 0.36),
      math.max(24, Font.width(capacity) + 2))
    local leftW = math.min(layout.width - capacityW - 28,
      math.max(layout.topRail and 48 or layout.railW,
        Font.width(left) + 4))
    drawText(left, 2,
      math.max(2, math.floor((layout.headerH - 8) / 2)),
      leftW - 2, WHITE)
    menu.modernBagHeaderCash = config and nil or left

    local titleSource
    if config then
      titleSource = layout.topRail and (config.short or config.label)
        or (config.label or config.short)
    else
      titleSource = layout.topRail and pocket.short or pocket.label
    end
    local title = Strings(titleSource)
    local titleX = layout.topRail and leftW or math.max(layout.listX, leftW)
    local titleW = layout.topRail
      and math.max(24, layout.width - titleX - capacityW - 4)
      or math.max(24, layout.width - titleX - capacityW - 4)
    title = fitText(title, titleW)
    menu.modernBagHeaderBounds = {
      cash = not config, leftX = 2,
      leftRight = 2 + math.min(leftW - 2, Font.width(left)),
      titleX = titleX, titleRight = titleX + titleW,
      capacityLeft = layout.width - 3 - capacityW,
      twoRows = false,
    }
    drawText(title,
      titleX + math.max(2, math.floor((titleW - Font.width(title)) / 2)),
      math.max(2, math.floor((layout.headerH - 8) / 2)), titleW, LIGHT)
    drawTextRight(capacity, layout.width - 3,
      math.max(2, math.floor((layout.headerH - 8) / 2)), capacityW, WHITE)
  end

  local function classicRailBoxes(layout)
    if layout.topRail then
      return {
        bagX = layout.railX + 4,
        bagY = layout.railY + 6,
        bagW = 48,
        bagH = 36,
        pocketX = layout.railX + 56,
        pocketY = layout.railY + 10,
        pocketW = layout.railW - 60,
        pocketH = 28,
      }
    end
    local margin = layout.wide and 5 or 3
    local bagH = layout.wide and 36 or 30
    local bagY = layout.railY + 4
    local pocketH = layout.wide and 28 or 25
    local pocketY = math.min(layout.railY + layout.railH - pocketH - 5,
      bagY + bagH + 8)
    return {
      bagX = layout.railX + margin,
      bagY = bagY,
      bagW = layout.railW - margin * 2,
      bagH = bagH,
      pocketX = layout.railX + margin,
      pocketY = pocketY,
      pocketW = layout.railW - margin * 2,
      pocketH = pocketH,
    }
  end

  local function classicBagRegionAt(x, y)
    -- The reference screenshot is in Items and visibly selects the left-side
    -- compartment. Continue from there through the main and two front pockets
    -- before ending at the right-side Key Items compartment.
    if x >= 4 and x <= 5 and y >= 8 and y <= 18 then return "items" end
    if x >= 12 and x <= 21 and y >= 2 and y <= 10 then return "medicine" end
    if x >= 12 and x <= 21 and y >= 12 and y <= 13 then return "balls" end
    if x >= 12 and x <= 21 and y >= 15 and y <= 17 then return "machines" end
    if x >= 27 and x <= 28 and y >= 9 and y <= 18 then return "key" end
  end

  local function loadClassicBagSprites()
    if classicBagSprites ~= nil then return classicBagSprites or nil end
    if not (love.image and love.image.newImageData
        and love.graphics and love.graphics.newImage) then
      classicBagSprites = false
      return nil
    end

    local sprites = {}
    local spritePockets = {}
    for _, pocket in ipairs(POCKETS) do spritePockets[#spritePockets + 1] = pocket end
    for _, pocket in ipairs(KANTO_POCKETS) do
      spritePockets[#spritePockets + 1] = pocket
    end
    for _, pocket in ipairs(spritePockets) do
      local okData, data = pcall(Assets.imageData, CLASSIC_BAG_ASSET)
      if not okData or not data or not data.mapPixel then
        classicBagSprites = false
        return nil
      end
      data:mapPixel(function(x, y, r, g, b, a)
        local region = classicBagRegionAt(x, y)
        local active = region
          and (CLASSIC_BAG_REGIONS[pocket.key] or pocket.key) == region

        -- The source screenshot shows its left pocket selected. Neutralize
        -- that fill first, then apply the same black fill as every other
        -- selected compartment so all five states behave consistently.
        if region == "items" and r < 0.17 then
          local shade = active and BLACK or WHITE
          return shade, shade, shade, a
        end
        if active and r > 0.83 and g > 0.83 and b > 0.83 then
          return BLACK, BLACK, BLACK, a
        end
        return r, g, b, a
      end)
      local okImage, image = pcall(love.graphics.newImage, data)
      if not okImage or not image then
        classicBagSprites = false
        return nil
      end
      if image.setFilter then image:setFilter("nearest", "nearest") end
      sprites[pocket.key] = image
    end
    classicBagSprites = sprites
    return sprites
  end

  local function drawClassicPocketBag(key, x, y, width, height)
    local sprites = loadClassicBagSprites()
    local sprite = sprites and (sprites[key] or sprites.all)
    if sprite and love.graphics.draw then
      local sw, sh = sprite:getDimensions()
      gray(WHITE)
      love.graphics.draw(sprite,
        math.floor(x + (width - sw) / 2),
        math.floor(y + (height - sh) / 2))
      return true
    end

    -- Headless tests and damaged installs still receive a safe fallback.
    local size = math.min(26, height - 8, width - 8)
    drawPocketSymbol("all", x + math.floor((width - size) / 2),
      y + math.floor((height - size) / 2), size)
    return false
  end

  local function drawClassicRail(menu, layout)
    local pocket = pocketFor(menu)
    local boxes = classicRailBoxes(layout)

    gray(BLACK)
    love.graphics.rectangle("fill", boxes.bagX - 1, boxes.bagY - 1,
      boxes.bagW + 2, boxes.bagH + 2)
    gray(WHITE)
    love.graphics.rectangle("fill", boxes.bagX, boxes.bagY,
      boxes.bagW, boxes.bagH)
    drawClassicPocketBag(pocket.key, boxes.bagX, boxes.bagY,
      boxes.bagW, boxes.bagH)
    menu.modernBagClassicPocketArt = pocket.key
    menu.modernBagClassicPocketRegion = CLASSIC_BAG_REGIONS[pocket.key]

    gray(DARK)
    love.graphics.rectangle("fill", boxes.pocketX - 1, boxes.pocketY - 1,
      boxes.pocketW + 2, boxes.pocketH + 2)
    gray(BLACK)
    love.graphics.rectangle("fill", boxes.pocketX + 2, boxes.pocketY + 2,
      boxes.pocketW - 4, boxes.pocketH - 4)
    local label = CLASSIC_POCKET_LABELS[pocket.key] or pocket.short
    menu.modernBagClassicPocketLabel = classicRailLabel(Strings(label),
      boxes.pocketX + 4, boxes.pocketY + 2,
      boxes.pocketW - 8, boxes.pocketH - 4)
  end

  local function drawClassicList(menu, layout)
    gray(BLACK)
    if layout.topRail then
      love.graphics.rectangle("fill", layout.listX, layout.listY - 1,
        layout.listW, 1)
    else
      love.graphics.rectangle("fill", layout.listX - 1, layout.listY,
        1, layout.listH)
    end
    gray(WHITE)
    love.graphics.rectangle("fill", layout.listX, layout.listY,
      layout.listW, layout.listH)

    if #menu.items == 0 then
      local config = listConfig(menu)
      local empty = config and config.empty
      local line1 = Strings(empty and empty[1] or "THIS POCKET")
      local line2 = Strings(empty and empty[2] or "IS EMPTY")
      drawText(line1,
        layout.listX + (layout.listW - Font.width(line1)) / 2,
        layout.listY + 22, layout.listW - 8, BLACK)
      drawText(line2,
        layout.listX + (layout.listW - Font.width(line2)) / 2,
        layout.listY + 34, layout.listW - 8, BLACK)
      return
    end

    for row = 1, layout.rows do
      local index = menu.scroll + row
      local item = menu.items[index]
      if not item then break end
      local y = layout.listY + 6 + (row - 1) * ROW_H
      local selected = index == menu.index
      local quantity = item.right or ""
      local qWidth = Font.width(quantity)
      if selected then
        drawCode(Theme.cursor, layout.listX + 8, y, DARK)
      elseif item.value == swapId(menu) then
        drawCode(Theme.cursorHollow, layout.listX + 8, y, BLACK)
      end
      drawText(item.label, layout.listX + 20, y,
        layout.listW - qWidth - 28, BLACK)
      drawTextRight(quantity, layout.width - 4, y, qWidth + 4, BLACK)
    end

    if menu.scroll + layout.rows < #menu.items then
      drawCode(Theme.moreArrow, layout.width - 10,
        layout.listY + layout.listH - 10, BLACK)
    end
  end

  local function drawClassicDetails(menu, layout)
    gray(BLACK)
    love.graphics.rectangle("fill", layout.detailX + 2,
      layout.detailY + 2, layout.detailW - 4, layout.detailH - 2)
    gray(WHITE)
    love.graphics.rectangle("fill", layout.detailX + 4,
      layout.detailY + 4, layout.detailW - 8, layout.detailH - 6)
    gray(BLACK)
    local x, y = layout.detailX + 6, layout.detailY + 6
    local w, h = layout.detailW - 12, layout.detailH - 10
    love.graphics.rectangle("fill", x, y, w, 1)
    love.graphics.rectangle("fill", x, y + h - 1, w, 1)
    love.graphics.rectangle("fill", x, y, 1, h)
    love.graphics.rectangle("fill", x + w - 1, y, 1, h)

    local config = listConfig(menu)
    local status = config and menu.footer or menu.modernBagPrompt
    local text
    if status then
      text = Strings(status):gsub("\n", " ")
    elseif swapId(menu) then
      local swapping = swapId(menu)
      local def = menu.game.data.items[swapping] or {}
      text = Strings("Choose a new position for %s.",
        def.name or swapping)
    else
      local item = menu.items[menu.index]
      text = item and itemDescription(menu, item.value)
        or Strings(config and config.blurb or pocketFor(menu).blurb)
    end
    local textX = layout.detailX + 10
    local textY = layout.detailY + 10
    local textW = layout.detailW - 20
    local maxLines = math.max(2, math.floor((layout.detailH - 18) / 9))
    if config and config.direction then
      drawText(fitText(Strings(config.direction), textW),
        textX, textY, textW, BLACK)
      textY = textY + 10
      maxLines = math.max(1, maxLines - 1)
    end
    local item = menu.items[menu.index]
    if item and not config and not status and not swapId(menu) then
      drawReadableDescription(menu, item.value, text,
        textX, textY, textW, maxLines, BLACK)
    else
      clearDescriptionScroll(menu)
      for index, line in ipairs(wrappedLines(text, textW, maxLines)) do
        drawText(line, textX, textY + (index - 1) * 9, textW, BLACK)
      end
    end
  end

  local function drawClassic(menu, layout)
    drawClassicBackdrop(layout)
    drawClassicHeader(menu, layout)
    drawClassicRail(menu, layout)
    drawClassicList(menu, layout)
    drawClassicDetails(menu, layout)
  end

  local function draw(menu)
    confineNativeViewport(menu)
    syncInventory(menu)
    local layout = layoutFor(menu)
    menu.rows = layout.rows
    clampList(menu)
    if layout.skin == "classic_pocket" then
      drawClassic(menu, layout)
      gray(WHITE)
      return
    end
    local counts = pocketCounts(menu)
    drawBackdrop(layout)
    drawHeader(menu, layout)
    drawTabs(menu, layout, counts)
    drawList(menu, layout)
    drawDetails(menu, layout)
    drawFooter(menu, layout)
    gray(WHITE)
  end

  local function sgbPalettes(menu, game)
    local data = game and game.data
    if not data then return nil end
    local layout = layoutFor(menu)
    if layout.skin == "classic_pocket" then
      local base = PaletteFX.pal(data, "MEWMON")
        or PaletteFX.pal(data, "BLUEMON")
      if not base then return nil end
      local blue = PaletteFX.pal(data, "BLUEMON") or base
      local green = PaletteFX.pal(data, "GREENMON") or base
      local red = PaletteFX.pal(data, "REDMON") or base
      local purple = PaletteFX.pal(data, "PURPLEMON") or base
      local config = listConfig(menu)
      local mode = config and PaletteFX.pal(data, config.modePalette) or nil
      local boxes = classicRailBoxes(layout)
      local zones = {
        { colors = base, x = 0, y = 0,
          w = layout.width, h = layout.canvasHeight or layout.height },
        { colors = mode or purple, x = layout.headerAccentX, y = 0,
          w = layout.headerAccentW, h = layout.headerH },
        { colors = blue, x = layout.railX, y = layout.railY,
          w = layout.railW, h = layout.railH },
        { colors = green, x = boxes.bagX - 1, y = boxes.bagY - 1,
          w = boxes.bagW + 2, h = boxes.bagH + 2 },
        { colors = red, x = boxes.pocketX - 1, y = boxes.pocketY - 1,
          w = boxes.pocketW + 2, h = boxes.pocketH + 2 },
      }
      if mode then
        zones[#zones + 1] = {
          colors = mode, x = layout.detailX, y = layout.detailY,
          w = layout.detailW, h = layout.detailH,
        }
      end
      if #menu.items > 0 then
        zones[#zones + 1] = {
          colors = red,
          x = layout.listX + 6,
          y = layout.listY + 4
            + (menu.index - menu.scroll - 1) * ROW_H,
          w = 12, h = 11,
        }
      end
      return zones
    end
    local pocket = pocketFor(menu)
    local config = listConfig(menu)
    local base = PaletteFX.pal(data, "BLUEMON")
      or PaletteFX.pal(data, "MEWMON")
    local accent = PaletteFX.pal(data, pocket.palette) or base
    local mode = config and PaletteFX.pal(data, config.modePalette) or nil
    if not base then return nil end
    local zones = {
      { colors = base, x = 0, y = 0,
        w = layout.width, h = layout.canvasHeight or layout.height },
      { colors = mode or accent, x = 0, y = 0,
        w = layout.width, h = layout.contentY },
    }
    if layout.showDetails then
      zones[#zones + 1] = {
        colors = mode or accent,
        x = layout.detailX, y = layout.detailY,
        w = layout.detailW, h = layout.detailH,
      }
    end
    if #menu.items > 0 then
      zones[#zones + 1] = {
        colors = accent,
        x = layout.listX + 4,
        y = layout.listY + 3 + (menu.index - menu.scroll - 1) * ROW_H,
        w = layout.listW - 8, h = 13,
      }
    end
    return zones
  end

  local function update(menu, dt)
    local description = menu.modernBagDescriptionScroll
    if description then
      description.elapsed = (description.elapsed or 0)
        + math.max(0, tonumber(dt) or 0)
    end
    local layout = layoutFor(menu)
    menu.rows = layout.rows
    clampList(menu)
    syncInventory(menu)
    local input = menu.game.input
    if not (input and input.wasPressed) then
      return menu.modernBagBaseUpdate(menu, dt)
    end
    if input:wasPressed("left") then
      switchPocket(menu, -1)
      return
    elseif input:wasPressed("right") then
      switchPocket(menu, 1)
      return
    elseif not listConfig(menu) and input:wasPressed("start") then
      openSortMenu(menu)
      return
    end
    -- ListMenu closes an empty list on A as a legacy convenience. Pocket
    -- tabs remain open instead, so the player can continue browsing them.
    if #menu.items == 0 and input:wasPressed("a") then return end
    return menu.modernBagBaseUpdate(menu, dt)
  end

  -- Transparent native prompts and classic sub-screens normally make the
  -- renderer fall back to 160x144 as soon as they reach the top of the
  -- stack. Keep the responsive Bag/PC surface instead. Most classic overlays
  -- remain centred in it; quantity selectors attach to the selected row so
  -- they read as a pop-out from the item that opened them. This covers
  -- USE/TOSS, quantity and YES/NO boxes, text, party targeting and move
  -- selection without replacing any of their controllers.
  local function installOverlayBridge(game)
    local stack = game and game.stack
    if not stack or stack.__modernBagOverlayBridge then return end
    local originalPush = stack.push
    if type(originalPush) ~= "function" then return end
    stack.__modernBagOverlayBridge = true
    stack.push = function(self, state, ...)
      local owner
      for index = #(self.states or {}), 1, -1 do
        local candidate = self.states[index]
        if candidate and candidate.modernBagUI then
          owner = candidate
          break
        end
      end

      if owner and state and not state.modernBagUI
          and (not state.uiSize or not state.isOpaque)
          and not state.__modernBagResponsiveOverlay then
        state.__modernBagResponsiveOverlay = true
        state.uiSize = function() return owner:uiSize() end
        state.holdsUIAnchors = true
        state.isWideBattleLayout = function() return true end

        local function overlayOffset(active)
          local width, height = active:uiSize()
          local offsetX = math.max(0, math.floor((width - SCREEN_W) / 2))
          local offsetY = math.max(0, math.floor((height - SCREEN_H) / 2))
          local QuantityBox = require("src.ui.QuantityBox")
          if getmetatable(active) ~= QuantityBox
              or type(owner.modernBagLayoutInfo) ~= "function" then
            return offsetX, offsetY
          end

          local layout = owner:modernBagLayoutInfo()
          local priced = active.unitPrice ~= nil
          local threeDigits = not priced and active.max >= 100
          local sourceTX = priced and 7 or (threeDigits and 14 or 15)
          local boxTiles = priced and 13 or (threeDigits and 6 or 5)
          local boxW, boxH = boxTiles * 8, 3 * 8
          local row = math.max(0,
            (owner.index or 1) - (owner.scroll or 0) - 1)
          local selectedTop = layout.listY + 3 + row * ROW_H
          local targetY = selectedTop - math.floor((boxH - 13) / 2)
          local targetX
          if layout.skin ~= "classic_pocket"
              and layout.showDetails and not layout.stacked then
            -- Straddle the seam: a small overlap joins the box to the row,
            -- while most of it opens into the details column.
            targetX = layout.listX + layout.listW - 6
          else
            -- A portrait list has no free column, so replace the selected
            -- row's quantity at its right edge instead of leaving the screen.
            targetX = layout.listX + layout.listW - boxW - 5
          end
          targetX = math.max(0, math.min(width - boxW, targetX))
          targetY = math.max(layout.contentY,
            math.min(layout.footerY - boxH, targetY))
          active.__modernBagAnchorKind = "selection"
          active.__modernBagAnchorX = targetX
          active.__modernBagAnchorY = targetY
          return targetX - sourceTX * 8, targetY - 9 * 8
        end

        local baseDraw = state.draw
        if type(baseDraw) == "function" then
          state.draw = function(active)
            local width, height = active:uiSize()
            local offsetX, offsetY = overlayOffset(active)
            local originalMark = PaletteFX.markTrueColor
            PaletteFX.markTrueColor = function(x, y, w, h)
              return originalMark(x + offsetX, y + offsetY, w, h)
            end
            love.graphics.push("all")
            if active.isOpaque and (offsetX > 0 or offsetY > 0) then
              gray(BLACK)
              love.graphics.rectangle("fill", 0, 0, width, height)
            end
            love.graphics.translate(offsetX, offsetY)
            local ok, result = pcall(baseDraw, active)
            love.graphics.pop()
            PaletteFX.markTrueColor = originalMark
            if not ok then error(result, 0) end
            return result
          end
        end

        local basePalettes = state.sgbPalettes
        if type(basePalettes) == "function" then
          state.sgbPalettes = function(active, activeGame)
            local zones = basePalettes(active, activeGame)
            if not zones then return nil end
            local offsetX, offsetY = overlayOffset(active)
            local shifted = {}
            for index, zone in ipairs(zones) do
              local copy = {}
              for key, value in pairs(zone) do copy[key] = value end
              copy.x = (copy.x or 0) + offsetX
              copy.y = (copy.y or 0) + offsetY
              shifted[index] = copy
            end
            return shifted
          end
        end
      end
      return originalPush(self, state, ...)
    end
  end

  local function installTossPrompts(menu, item)
    local actionMenu = menu.game.stack:top()
    local tossRow
    for _, row in ipairs(actionMenu and actionMenu.items or {}) do
      if tostring(row.label or ""):upper() == "TOSS" then
        tossRow = row
        break
      end
    end
    if not tossRow or type(tossRow.onSelect) ~= "function"
        or actionMenu.__modernBagTossPrompts then
      return
    end
    actionMenu.__modernBagTossPrompts = true
    local chooseToss = tossRow.onSelect
    tossRow.onSelect = function()
      local result = chooseToss()
      local quantity = menu.game.stack:top()
      local QuantityBox = require("src.ui.QuantityBox")
      if getmetatable(quantity) ~= QuantityBox
          or type(quantity.onDone) ~= "function" then
        return result
      end

      menu.modernBagPrompt = Strings("How many?")
      local finishQuantity = quantity.onDone
      quantity.onDone = function(qty)
        if qty then
          menu.modernBagPrompt = Strings("Toss %s?", item.label)
        else
          menu.modernBagPrompt = nil
        end
        local finished = finishQuantity(qty)
        if qty then
          local choice = menu.game.stack:top()
          local ChoiceBox = require("src.ui.ChoiceBox")
          if getmetatable(choice) == ChoiceBox
              and type(choice.onChoose) == "function" then
            local confirm = choice.onChoose
            choice.onChoose = function(yes)
              menu.modernBagPrompt = nil
              return confirm(yes)
            end
          else
            menu.modernBagPrompt = nil
          end
        end
        return finished
      end
      return result
    end
  end

  local function bagQolInfo(menu)
    local scroll = menu.modernBagDescriptionScroll or {}
    local bounds = menu.modernBagHeaderBounds or {}
    return {
      money = moneyText(menu),
      headerCash = menu.modernBagHeaderCash,
      header = bounds,
      descriptionOverflow = scroll.overflow and true or false,
      descriptionOffset = tonumber(scroll.offset) or 0,
      descriptionTravel = tonumber(scroll.travel) or 0,
      descriptionElapsed = tonumber(scroll.elapsed) or 0,
      descriptionStaticLines = tonumber(scroll.staticLines) or 0,
      descriptionTail = scroll.tailText,
    }
  end

  local function decorateList(menu, config)
    installOverlayBridge(menu.game)
    menu.modernBagListConfig = config or {}
    menu.modernPCUI = true
    menu.modernBagBaseUpdate = menu.update
    menu.modernBagPocket = 1
    menu.modernBagPocketState = {}
    menu.modernBagSwapId = nil
    menu.rows = layoutFor(menu).rows
    menu.draw = draw
    menu.update = update
    menu.sgbPalettes = sgbPalettes
    menu.uiSize = uiSize
    menu.isWideBattleLayout = function() return true end
    menu.holdsUIAnchors = true
    menu.modernBagUI = true
    menu.modernBagLayout = "pc-pockets"
    menu.modernBagPockets = POCKETS
    menu.modernBagCategoryFor = function(_, id)
      return categoryFor(menu.game, id)
    end
    menu.modernBagLayoutInfo = function() return layoutFor(menu) end
    menu.modernBagQolInfo = bagQolInfo
    menu.modernBagSwitchPocket = switchPocket
    menu.modernBagRefresh = rebuildPocket
    rebuildPocket(menu)
    return menu
  end

  return {
    decorateList = decorateList,
    new = function(game, opts)
      installOverlayBridge(game)
      local upstream = compatibility.kantoReforged
        and compatibility.upstreamBagScreen
      local menu = upstream and upstream.new(game, opts)
        or BagMenu.new(game, opts)
      local externalController = upstream ~= nil
        and type(menu.__pocketIndex) == "number"
        and type(menu.__pocketIds) == "table"
        and type(menu.gen1ModernUi) == "table"
        and type(menu.gen1ModernUi.switchPocket) == "function"
      local baseChoose = menu.onChoose
      menu.modernBagBaseUpdate = menu.update
      -- Bag lists are circular: moving past either end continues from the
      -- opposite end. ListMenu owns the actual movement, scrolling and key
      -- repeat, so enabling its native wrap flag keeps stock, companion and
      -- Kanto Reforged controllers on the same path.
      menu.wrap = true
      menu.modernBagPocket = 1
      menu.modernBagPocketState = {}
      menu.modernBagSwapId = nil
      menu.modernBagExternalController = externalController
      menu.modernBagPockets = externalController and KANTO_POCKETS or POCKETS
      syncExternalPocketIndex(menu)
      menu.rows = layoutFor(menu).rows

      if not externalController then
        menu.onSelectKey = function(item, list)
          reorder(list, item)
        end
      end
      menu.onChoose = function(item, list)
        if not externalController and list.modernBagSwapId then
          finishSwap(list, item and item.value)
          return
        end
        local result = baseChoose(item, list)
        if item and item.value then installTossPrompts(list, item) end
        return result
      end

      menu.draw = draw
      menu.update = update
      menu.sgbPalettes = sgbPalettes
      menu.uiSize = uiSize
      menu.isWideBattleLayout = function() return true end
      -- The responsive Bag is one composed surface. In DYNAMIC UI mode a
      -- TextBox normally docks itself to the window edge, but its 160px
      -- source rect is declared in classic coordinates while this screen is
      -- wider. The renderer would then cut out the wrong canvas region and
      -- reassemble part of the Bag as dialogue (# wide Bag text seam).
      -- Battles solve the same composition problem by holding UI anchors;
      -- keep Bag messages (item failures, toss confirmations, etc.) inside
      -- this surface as well.
      menu.holdsUIAnchors = true
      menu.modernBagUI = true
      menu.modernBagLayout = "pockets"
      menu.modernBagCategoryFor = function(_, id) return categoryFor(game, id) end
      menu.modernBagLayoutInfo = function() return layoutFor(menu) end
      menu.modernBagQolInfo = bagQolInfo
      menu.modernBagSwitchPocket = switchPocket
      menu.modernBagRefresh = rebuildPocket
      menu.modernBagSort = sortBag
      menu.modernBagOpenSort = openSortMenu
      rebuildPocket(menu)
      return menu
    end,
  }
end
