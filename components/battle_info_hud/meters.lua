-- Compact pixel meters. Five-pixel text stays readable at the native scale
-- without allocating an extra full-size numeric row below either bar.
return function()
  local Growth = require("src.pokemon.Growth")
  local PaletteFX = require("src.render.PaletteFX")
  local M = {}
  local BLACK, WHITE = { 0, 0, 0, 1 }, { 1, 1, 1, 1 }
  local BLUE = { 42 / 255, 106 / 255, 208 / 255, 1 }
  local GLYPHS = {
    ["0"] = {"111","101","101","101","111"},
    ["1"] = {"010","110","010","010","111"},
    ["2"] = {"111","001","111","100","111"},
    ["3"] = {"111","001","111","001","111"},
    ["4"] = {"101","101","111","001","001"},
    ["5"] = {"111","100","111","001","111"},
    ["6"] = {"111","100","111","101","111"},
    ["7"] = {"111","001","010","010","010"},
    ["8"] = {"111","101","111","101","111"},
    ["9"] = {"111","101","111","001","111"},
    ["/"] = {"001","001","010","100","100"},
    ["."] = {"000","000","000","000","010"},
    H = {"101","101","111","101","101"},
    P = {"110","101","110","100","100"},
    E = {"111","100","110","100","111"},
    X = {"101","101","010","101","101"},
    M = {"101","111","111","101","101"},
    A = {"010","101","111","101","101"},
    K = {"101","101","110","101","101"},
  }

  function M.width(text) return math.max(0, #text * 4 - 1) end

  function M.text(text, x, y, color)
    local g = love.graphics
    g.setColor(color or WHITE)
    for i = 1, #text do
      for row, pixels in ipairs(GLYPHS[text:sub(i, i)] or {}) do
        for column = 1, #pixels do
          if pixels:sub(column, column) == "1" then
            g.rectangle("fill", x + (i - 1) * 4 + column - 1,
              y + row - 1, 1, 1)
          end
        end
      end
    end
  end

  local function integer(value) return math.max(0, math.floor(tonumber(value) or 0)) end

  function M.values(data, battler, kind)
    local mon = battler and battler.mon or {}
    local current, maximum, capped
    if kind == "HP" then
      maximum = integer(mon.stats and mon.stats.hp)
      current = math.min(maximum, integer(battler and battler.shownHP or mon.hp))
    else
      local def = data and data.pokemon and data.pokemon[mon.species]
      local level = math.max(1, integer(mon.level))
      local cap = data and data.constants and data.constants.levelCap or 100
      capped = level >= cap
      if capped then return 0, 0, 1, true end
      local floorExp = def and Growth.expForLevel(def.growthRate, level, data.growth_rates) or 0
      local nextExp = def and Growth.expForLevel(def.growthRate, level + 1, data.growth_rates) or 1
      maximum = math.max(1, nextExp - floorExp)
      current = math.max(0, math.min(maximum, integer(mon.exp or floorExp) - floorExp))
    end
    return current, maximum, maximum > 0 and current / maximum or 0, false
  end

  local function compact(value, whole)
    if value < 1000 then return tostring(value) end
    local unit, divisor = value < 1000000 and "K" or "M", value < 1000000 and 1000 or 1000000
    if whole then return tostring(math.floor(value / divisor)) .. unit end
    return ("%.1f"):format(math.floor(value / divisor * 10) / 10):gsub("%.0$", "") .. unit
  end

  function M.readout(current, maximum, capped, width)
    if capped then return "MAX" end
    local exact = ("%d/%d"):format(current, maximum)
    if M.width(exact) <= width - 4 then return exact end
    local shortened = compact(current) .. "/" .. compact(maximum)
    if M.width(shortened) <= width - 4 then return shortened end
    return compact(current, true) .. "/" .. compact(maximum, true)
  end

  function M.draw(data, battler, kind, x, y, width, numbers, ink, markColor)
    local current, maximum, ratio, capped = M.values(data, battler, kind)
    local color = BLUE
    if kind == "HP" then
      -- Preserve Gen 1's 48-pixel green/yellow/red transition thresholds.
      local pixels = math.floor(ratio * 48)
      local name = pixels >= 27 and "GREENBAR" or pixels >= 10 and "YELLOWBAR" or "REDBAR"
      local palette = PaletteFX.pal(data, name)
      local rgb = palette and palette[3] or (name == "GREENBAR" and {0,189,0}
        or name == "YELLOWBAR" and {247,165,0} or {247,0,0})
      color = {rgb[1] / 255, rgb[2] / 255, rgb[3] / 255, 1}
    end
    local g = love.graphics
    g.setColor(BLACK)
    g.rectangle("fill", x, y, width, 7)
    local fill = math.floor((width - 2) * ratio)
    if ratio > 0 then fill = math.max(1, fill) end
    if fill > 0 then
      g.setColor(color)
      g.rectangle("fill", x + 1, y + 1, fill, 5)
    end
    if numbers then
      local text = M.readout(current, maximum, capped, width)
      local tx = x + width - 2 - M.width(text)
      -- A one-pixel dark edge protects white digits where a fill ends.
      M.text(text, tx + 1, y + 2, BLACK)
      M.text(text, tx, y + 1, WHITE)
    end
    M.text(kind == "HP" and "HP" or "XP", x - 15, y + 1, ink or BLACK)
    if markColor ~= false then PaletteFX.markTrueColor(x - 15, y, width + 15, 7) end
  end
  return M
end
