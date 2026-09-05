-- Stable pocket keys are saved; presentation indices are resolved per menu.
return function(mod, setOption)
  local ListMenu = require("src.ui.ListMenu")
  local P = {}
  P.defaults = {
    { key = "all", label = "ALL ITEMS" },
    { key = "items", label = "ITEMS" },
    { key = "medicine", label = "MEDICINE" },
    { key = "balls", label = "BALLS" },
    { key = "machines", label = "TMs/HMs" },
    { key = "key", label = "KEY ITEMS" },
  }
  P.kanto = {
    { key = "items", label = "ITEMS" }, { key = "balls", label = "BALLS" },
    { key = "key", label = "KEY ITEMS" }, { key = "machines", label = "TMs/HMs" },
    { key = "berries", label = "BERRIES" },
  }

  function P.ordered(source, includeHidden)
    local byKey, used, out = {}, {}, {}
    for _, pocket in ipairs(source) do byKey[pocket.key] = pocket end
    local function add(key)
      if byKey[key] and not used[key] then
        used[key] = true
        if includeHidden or key ~= "all" or mod.options:get("hide_all") ~= true then
          out[#out + 1] = byKey[key]
        end
      end
    end
    local saved = mod.options:get("pocket_order")
    if type(saved) == "table" then for _, key in ipairs(saved) do add(key) end end
    for _, pocket in ipairs(source) do add(pocket.key) end
    return out
  end

  function P.opening(pockets)
    local wanted = mod.options:get("open_on") or "all"
    local items
    for index, pocket in ipairs(pockets) do
      if pocket.key == wanted then return index end
      if pocket.key == "items" then items = index end
    end
    return items or 1
  end

  function P.openOrder(game)
    local source = mod.find("Kanto-Reforged") and P.kanto or P.defaults
    local version = require("src.core.GameVersion")
    if version.generation and version.generation() == 2
        and mod.options:get("skin") == "classic_pocket" then
      source = { P.defaults[2], P.defaults[4], P.defaults[6], P.defaults[5] }
    end
    local pockets = P.ordered(source)
    local menu
    local function refresh()
      local rows = {}
      for index, pocket in ipairs(pockets) do
        rows[index] = { label = pocket.label, value = pocket.key,
          right = menu and menu.held == index and "HELD" or tostring(index) }
      end
      menu.items = rows
      menu.footer = menu.held and "SEL DROP B CANCEL" or "SEL PICK B BACK"
    end
    menu = ListMenu.new(game, "BAG POCKET ORDER", {}, {
      wrap = true, keyRepeat = true, onChoose = function() end,
      onSelectKey = function(_, active)
        if active.held then
          local from, to = active.held, active.index
          pockets[from], pockets[to] = pockets[to], pockets[from]
          active.held = nil
          local order, seen = {}, {}
          for _, pocket in ipairs(pockets) do
            order[#order + 1], seen[pocket.key] = pocket.key, true
          end
          -- Retain hidden tabs for when the player turns them back on.
          for _, pocket in ipairs(P.ordered(source, true)) do
            if not seen[pocket.key] then order[#order + 1] = pocket.key end
          end
          setOption(game, "pocket_order", order)
          if game.writeOptions then pcall(game.writeOptions, game) end
        else
          active.held = active.index
        end
        refresh()
      end,
    })
    local baseUpdate = menu.update
    menu.update = function(self, dt)
      if self.held and self.game.input:wasPressed("b") then
        self.held = nil; refresh(); return
      end
      return baseUpdate(self, dt)
    end
    menu.screenId = mod.id .. ":pocket_order"
    refresh()
    game.stack:push(menu)
    return true
  end
  return P
end
