-- Optional providers retain their controllers. Read their presentation data
-- only, and let callers fall back to the native renderer for unknown pages.
return function(mod)
  local function kanto()
    if not (mod.find and mod.find("Kanto-Reforged")) then return nil end
    local ok, api = pcall(require, "mods.Kanto-Reforged.ui.summary_ui")
    return ok and type(api) == "table" and api or nil
  end
  return {
    kanto = kanto,
    page = function(screen, generation)
      local api = kanto()
      local page = generation == 2 and (api and api.GEN2_ABILITY_PAGE or 4)
        or screen.modernKantoPage
      if not api or type(api.abilityPage) ~= "function" or screen.page ~= page
          or not screen.mon or screen.mon.isEgg then return nil end
      local ok, data = pcall(api.abilityPage, screen.mon, screen.game.data)
      if not ok or type(data) ~= "table" then return nil end
      local copy = {}
      for k, v in pairs(data) do copy[k] = v end
      copy.gender = data.gender == "♂" and "M" or (data.gender == "♀" and "F" or data.gender)
      copy.description = type(data.description) == "table"
        and table.concat(data.description, " ") or tostring(data.description or "")
      local loaded, text = pcall(require, "mods.Kanto-Reforged.battle.ability_text")
      if loaded and type(text.describe) == "function" then
        local described, description = pcall(text.describe, data.abilityId)
        if described and type(description) == "string" then copy.description = description end
      end
      return copy
    end,
    lines = function(text, width)
      local Font = require("src.render.Font")
      local out, line = {}, ""
      for word in tostring(text or ""):gmatch("%S+") do
        local candidate = line == "" and word or (line .. " " .. word)
        if Font.width(candidate) <= width then line = candidate
        else
          if line ~= "" then out[#out + 1] = line end
          line = word
          while Font.width(line) > width and Font.split and Font.spansFitting do
            local spans = Font.split(line)
            local n = math.max(1, Font.spansFitting(spans, width))
            local last = spans[n] and spans[n].to
            if not last then break end
            out[#out + 1], line = line:sub(1, last), line:sub(last + 1)
          end
        end
      end
      if line ~= "" then out[#out + 1] = line end
      return out
    end,
  }
end
