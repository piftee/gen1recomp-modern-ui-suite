-- G9's current public summary painter supplies animated, shadow-free art.
-- Older providers continue through battle_portraits' Image adapter.
return function(mod)
  return function(game, mon)
    local source = mod.options:get("menu_sprite_source") or "battle_art"
    if source == "crystal" or source == "hgss" or type(mon) ~= "table"
        or mon.isEgg or mon.species == "UNOWN" then return nil end
    local id = "g9-battle-sprites"
    local handle = mod.find and mod.find(id)
    local api = handle and handle.exports
    local options = game.mods and game.mods.modOptions and game.mods.modOptions[id] or {}
    if options.enable_battle_sprites == false or options.summary_sprites == false
        or not api or type(api.drawSummaryFrame) ~= "function"
        or type(api.frontArt) ~= "function" then return nil end
    local subject = {}
    for key, value in pairs(mon) do subject[key] = value end
    local ok, image, pending = pcall(api.frontArt, subject)
    if not ok or (not image and pending ~= true) then return nil end
    return function(x, y, scale)
      local G = love.graphics
      local Palette = require("src.render.PaletteFX")
      local marks = Palette.trueColorRects("ui")
      local count = #marks
      G.push("all")
      G.setShader(); G.translate(x, y); G.scale(scale, scale)
      local drawn = pcall(api.drawSummaryFrame, subject, {x=0, w=56, bottom=56})
      G.pop()
      -- The provider records marks in its own 56px coordinate space. Move
      -- just those newly emitted rectangles along with its scaled drawing.
      for i = count + 1, #marks do
        local rect = marks[i]
        rect.x, rect.y = x + rect.x * scale, y + rect.y * scale
        rect.w, rect.h = rect.w * scale, rect.h * scale
      end
      return drawn
    end
  end
end
