-- Adapt native Gen 2 data/controllers to the same presentation used by Gen 1.
-- The shared renderer owns every common card, tab, row and text position.
return function(mod, source)
  local PaletteFX = require("src.render.PaletteFX")
  local PartyMenu = require("src.ui.gen2.PartyMenu")
  local G = love.graphics
  local function loadFile(name)
    return assert(load(assert(mod:read(name)), "@" .. mod.path .. "/" .. name))()
  end
  local function copy(record)
    local out = {}
    for k, v in pairs(record or {}) do out[k] = v end
    return out
  end
  local function width(menu)
    return menu.modernPokedexWideWidth or menu.modernPokedexLastWideWidth or 160
  end
  local function owned(menu, species)
    local dex = menu.save and menu.save.pokedex or {}
    return (dex.caught and dex.caught[species])
      or (dex.owned and dex.owned[species]) or false
  end
  local function definition(menu, species)
    local def = copy(menu.pokemon[species])
    local entry = menu.dex and menu.dex.entries and menu.dex.entries[species] or {}
    def.id, def.dex = species, entry.dex or def.dex
    def.growthRate = tostring(def.growthRate or ""):gsub("^GROWTH_", "")
    local prose = menu.newEntry and (menu.page == 2 and entry.text2 or entry.text)
      or (tostring(entry.text or "") .. " " .. tostring(entry.text2 or ""))
    local height = tonumber(entry.height)
    def.dexEntry = { kind = entry.kind, text = tostring(prose or ""):gsub("<NEXT>", " "),
      heightFt = height and math.floor(height / 100),
      heightIn = height and height % 100, weight = tonumber(entry.weight) }
    return def
  end
  -- Native Gen 2 does not carry the Gen 1 SGB UI palette table. Use the
  -- same cartridge UI ramps; display-mode remapping still applies at blit.
  local fallback = {
    BLUEMON={{255,239,255},{148,165,222},{90,123,189},{25,16,16}},
    REDMON={{255,239,255},{255,165,82},{214,82,49},{25,16,16}},
    CYANMON={{255,239,255},{173,206,239},{115,156,206},{25,16,16}},
    BROWNMON={{255,239,255},{230,165,123},{173,115,74},{25,16,16}},
    GREENMON={{255,239,255},{165,214,132},{74,165,90},{25,16,16}},
    PURPLEMON={{255,239,255},{222,181,197},{173,123,189},{25,16,16}},
  }
  local deferred, owner
  local api = loadFile("screen.lua")(mod, {
    formatText = function(text) return text:gsub("′", "'"):gsub("″", '\"') end,
    statRows = {
      {"HP","hp","GREENMON","HP"}, {"ATTACK","attack","REDMON","ATK"},
      {"DEFENSE","defense","BROWNMON","DEF"}, {"SPEED","speed","BLUEMON","SPE"},
      {"SP.ATK","specialAttack","PURPLEMON","SPA"},
      {"SP.DEF","specialDefense","PURPLEMON","SPD"},
    },
    palette = function(game, name)
      local pack = PaletteFX.gbcPack and PaletteFX.gbcPack()
      return fallback[name] or PaletteFX.pal(game.data, name)
        or pack and pack.palettes and pack.palettes[name]
        or fallback.BLUEMON
    end,
    entryOwned = function(state)
      return state.forceOwned or owned(state.nativeDex, state.def.id)
    end,
    familyKnown = function(state, member)
      return member and source.known(state.nativeDex, member.def.id)
    end,
    evolutionLabel = function(_, parent) return source.label(owner, parent) end,
    moveRows = function(state) return source.moves(state.nativeDex, state.def.id) end,
    drawSprite = function(_, def, rect)
      deferred[#deferred + 1] = {def=def, rect=rect}
    end,
    drawIcon = function(_, def, x, y, target, _, counter)
      deferred[#deferred + 1] = {def=def, icon=true, x=x, y=y, target=target, clock=counter}
    end,
  }).presentation

  local function resetEntry(menu)
    menu.modernGen2Presentation = nil
  end
  local function stateFor(menu)
    local row = menu:current()
    if not row then return nil end
    local state = menu.modernGen2Presentation
    local key = row.species .. (menu.newEntry and (":" .. tostring(menu.page)) or "")
    if not state or state.key ~= key then
      state = { key=key, nativeDex=menu, game=menu.game,
        def=definition(menu, row.species), forceOwned=menu.newEntry,
        modernDexTabbed=not menu.newEntry, modernDexPage=1,
        modernInfoScroll=0, modernMoveCursor=1, modernMoveScroll=0,
        modernDexClock=0, uiSize=function() return width(menu),144 end }
      state.modernDexFamily = {}
      for _, member in ipairs(source.family(menu, row.species)) do
        state.modernDexFamily[#state.modernDexFamily + 1] = {
          def=definition(menu, member.species), parent=member.parent }
      end
      state.modernDexPages = menu.newEntry and {{id="info",label="INFO"}} or api.buildPages(state)
      menu.modernGen2Presentation = state
    end
    state.modernDexClock = menu.entryBlink or 0
    return state
  end
  local function listState(menu)
    local state = { game=menu.game, index=menu.index, scroll=menu.scroll,
      modernDexShinyOnly=menu.modernDexShinyOnly,
      modernDexClock=menu.entryBlink or 0,
      modernDexEntries={}, uiSize=function() return width(menu),144 end }
    for _, row in ipairs(menu.rows or {}) do
      state.modernDexEntries[#state.modernDexEntries + 1] = {
        def=definition(menu,row.species), seen=row.seen, owned=row.caught or owned(menu,row.species) }
    end
    state.modernDexAllEntries = state.modernDexEntries
    if menu.modernShinySource then
      state.modernDexAllEntries = {}
      for _, row in ipairs(menu.modernShinySource) do
        state.modernDexAllEntries[#state.modernDexAllEntries+1] = {
          def=definition(menu,row.species), seen=row.seen, owned=row.caught or owned(menu,row.species) }
      end
    end
    if menu.searchResults then
      state.modernDexType = true
      state.modernDexAllEntries = {}
      local dex = menu.save and menu.save.pokedex or {}
      for species in pairs(menu.dex and menu.dex.entries or {}) do
        if menu.pokemon[species] then
          state.modernDexAllEntries[#state.modernDexAllEntries+1] = {
            def={id=species}, seen=dex.seen and dex.seen[species], owned=owned(menu,species) }
        end
      end
    end
    return state
  end
  local function drawArt(menu, art)
    if not art.icon then
      return source.drawPic(menu, {species=art.def.id,seen=true}, art.rect)
    end
    local icons = menu.modernGen2IconRenderer
    if not icons then
      icons = setmetatable({game=menu.game, pokemon=menu.pokemon,
        icons=menu.data.gen2Icons, palettes=menu.palettes, iconCache={}, clock=0}, {__index=PartyMenu})
      menu.modernGen2IconRenderer = icons
    end
    icons.clock = art.clock or 0
    local mon = {species=art.def.id, hp=1, stats={hp=1}}
    local x = art.x + math.floor((art.target-16)/2)
    local y = art.y + math.floor((art.target-16)/2)
    if not (mod.suite and mod.suite.drawMenuIcon
        and mod.suite.drawMenuIcon(menu.game, icons, mon, x, y)) then
      icons:drawIcon(mon, x, y)
    end
  end
  local function render(menu)
    local w = width(menu)
    local isEntry = menu.view == "entry"
    local state = isEntry and stateFor(menu) or listState(menu)
    if not state then return end
    owner, deferred = menu, {}
    local canvas = menu.modernGen2DexCanvas
    if not canvas or canvas:getWidth() ~= w then
      if canvas and canvas.release then canvas:release() end
      canvas = G.newCanvas(w,144);canvas:setFilter("nearest","nearest")
      menu.modernGen2DexCanvas = canvas
    end
    local previous = G.getCanvas()
    G.push("all")
    G.setCanvas(canvas);G.origin();G.setScissor();G.clear(0,0,0,0)
    if isEntry then api.entry(state,w) else api.list(state,w) end
    local actions = menu.modernGen2Actions
    local actionRect
    if actions then
      actions.modernDexOwner = state
      api.actions(actions,w)
      actionRect = api.actionGeometry(actions,state,api.listLayout(w))
    end
    G.setCanvas(previous);G.pop()
    local zones = isEntry and api.entryZones(state,menu.game,w) or api.listZones(state,menu.game,w)
    if actionRect then
      zones[#zones+1] = {x=actionRect.x,y=actionRect.y,w=actionRect.w+2,h=actionRect.h+2,
        colors=PaletteFX.GRAYS}
    end
    G.push("all");G.setColor(1,1,1,1)
    local shader = PaletteFX.shader()
    G.setShader(shader)
    for _, zone in ipairs(zones) do
      if shader then PaletteFX.sendColors(shader,zone.colors) end
      local quad = G.newQuad(zone.x,zone.y,zone.w,zone.h,w,144)
      G.draw(canvas,quad,zone.x,zone.y)
    end
    G.setShader()
    for _, art in ipairs(deferred) do drawArt(menu,art) end
    if actionRect then
      -- Restore the dialog over artwork while retaining the visible parts
      -- of the preview behind it, just as Gen 1's layered actions do.
      G.setColor(1,1,1,1);G.setShader(shader)
      if shader then PaletteFX.sendColors(shader,PaletteFX.GRAYS) end
      local r = actionRect
      G.draw(canvas,G.newQuad(r.x,r.y,r.w+2,r.h+2,w,144),r.x,r.y)
    end
    G.pop()
  end
  local function actionsFor(menu)
    menu.modernGen2Actions = {index=1, items={
      {label="DATA"}, {label="AREA"}, {label="CRY"}, {label="PRNT"}, {label="QUIT"},
    }}
  end
  local function clearShinyFilter(menu)
    if menu.modernShinySource then menu.rows=menu.modernShinySource end
    menu.modernShinySource=nil;menu.modernDexShinyOnly=false
    menu.index=math.max(1,math.min(menu.index or 1,math.max(1,#menu.rows)));menu.scroll=0
  end
  local function toggleShinyFilter(menu)
    if menu.modernDexShinyOnly then clearShinyFilter(menu);return end
    local tracker=mod.suite and mod.suite.shinyDex
    menu.modernShinySource=menu.rows
    menu.rows={}
    for _, row in ipairs(menu.modernShinySource or {}) do
      if tracker and tracker.has(menu.game,row.species) then menu.rows[#menu.rows+1]=row end
    end
    menu.modernDexShinyOnly=true;menu.index=1;menu.scroll=0
  end
  local function update(menu, input)
    if menu.modernGen2Actions then
      local action = menu.modernGen2Actions
      if input:wasPressed("b") then menu.modernGen2Actions=nil
      elseif input:wasPressed("up") then action.index=(action.index-2)%#action.items+1
      elseif input:wasPressed("down") then action.index=action.index%#action.items+1
      elseif input:wasPressed("a") then
        local label=action.items[action.index].label
        if label=="DATA" then menu.view="entry";menu.page=1;resetEntry(menu)
        elseif label=="AREA" then menu.view="area";menu.areaRegion=nil;menu.modernGen2ToolReturn="list"
        elseif label=="CRY" then menu:playCry(menu:current().species);return true
        elseif label=="PRNT" then menu:printEntry()
        elseif label=="QUIT" then menu:close() end
        menu.modernGen2Actions=nil
      end
      return true
    end
    if menu.view == "list" or menu.view == "results" then
      if input:wasPressed("left") or input:wasPressed("right") then
        toggleShinyFilter(menu);return true
      elseif input:wasPressed("a") then
        if menu:current() and menu:current().seen then actionsFor(menu) end
        return true
      elseif input:wasPressed("select") then
        clearShinyFilter(menu)
        menu.view="search";menu.searchIndex=1;menu.searchType=menu.searchType or {1,0};menu.searchResults=nil
        return true
      elseif input:wasPressed("start") then
        clearShinyFilter(menu)
        menu.view="option";menu.optionIndex=menu.modeIndex
        return true
      elseif #menu.rows == 0 and (input:wasPressed("up") or input:wasPressed("down")) then
        return true
      end
      return false
    end
    if menu.view ~= "entry" then return false end
    local state = stateFor(menu)
    if not state then return false end
    if menu.newEntry then
      if input:wasPressed("a") and state.modernInfoCanScroll
          and state.modernInfoScroll < #state.modernInfoLines-state.modernInfoVisible then
        api.moveInfoScroll(state,state.modernInfoVisible);return true
      end
      return false
    end
    local page = state.modernDexPages[state.modernDexPage]
    if state.modernMoveDetail then
      if input:wasPressed("b") then state.modernMoveDetail=false end
    elseif input:wasPressed("b") then menu.view="list";resetEntry(menu)
    elseif input:wasPressed("left") or input:wasPressed("right") then
      local delta=input:wasPressed("left") and -1 or 1
      state.modernDexPage=(state.modernDexPage-1+delta)%#state.modernDexPages+1
      state.modernInfoScroll=0;state.modernMoveCursor=1;state.modernMoveScroll=0
    elseif input:wasPressed("up") or input:wasPressed("down") then
      local delta=input:wasPressed("up") and -1 or 1
      if page.id=="family" then api.moveFamilySelection(state,delta)
      elseif page.id=="moves" then api.moveMoveSelection(state,delta)
      elseif page.id=="info" then api.moveInfoScroll(state,delta) end
    elseif input:wasPressed("a") then
      if page.id=="family" then
        local _,_,member=api.familySelection(state)
        if member then
          clearShinyFilter(menu)
          if source.focus(menu,{species=member.def.id}) then resetEntry(menu) end
        end
      elseif page.id=="moves" then
        if api.selectedMoveRow(state,api.entryLayout(width(menu))) then state.modernMoveDetail=true end
      elseif type(page.onAction)=="function" then
        page.onAction({game=menu.game,state=state,def=state.def})
      else menu:playCry(state.def.id) end
    end
    return true
  end
  return {draw=render, update=update, state=stateFor, listLayout=api.listLayout}
end
