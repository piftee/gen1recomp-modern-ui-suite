-- Shared Gen 1/2 ordering inside a visible category. Stable item ids keep
-- the familiar progression independent of translations and acquisition order.
return function()
  local priority = {}
  local groups = {
    { "POKE_BALL", "GREAT_BALL", "ULTRA_BALL", "MASTER_BALL", "SAFARI_BALL" },
    { "POTION", "SUPER_POTION", "HYPER_POTION", "MAX_POTION", "FRESH_WATER",
      "SODA_POP", "LEMONADE", "FULL_RESTORE" },
    { "ANTIDOTE", "AWAKENING", "BURN_HEAL", "ICE_HEAL", "PARLYZ_HEAL", "FULL_HEAL" },
    { "REVIVE", "MAX_REVIVE" },
    { "ETHER", "MAX_ETHER", "ELIXER", "MAX_ELIXER" },
    { "HP_UP", "PP_UP", "PROTEIN", "IRON", "CARBOS", "CALCIUM", "RARE_CANDY",
      "X_ATTACK", "X_DEFEND", "X_SPEED", "X_SPECIAL", "X_ACCURACY", "DIRE_HIT", "GUARD_SPEC" },
    { "FIRE_STONE", "WATER_STONE", "THUNDER_STONE", "LEAF_STONE", "MOON_STONE" },
    { "REPEL", "SUPER_REPEL", "MAX_REPEL", "ESCAPE_ROPE", "POKE_DOLL", "NUGGET" },
    { "DOME_FOSSIL", "HELIX_FOSSIL", "OLD_AMBER", "OLD_ROD", "GOOD_ROD", "SUPER_ROD" },
  }
  for group, ids in ipairs(groups) do
    for index, id in ipairs(ids) do priority[id] = group * 100 + index end
  end
  priority.ELIXIR, priority.MAX_ELIXIR = priority.ELIXER, priority.MAX_ELIXER
  priority.X_DEFENSE = priority.X_DEFEND
  priority.PARALYZE_HEAL = priority.PARLYZ_HEAL

  local function rank(entry)
    local def = entry.def or {}
    local machine = type(def.machine) == "table" and def.machine or {}
    local number = tonumber(machine.number or def.tmNumber or def.hmNumber)
    local kind = machine.kind or (def.hmNumber and "HM")
      or (tostring(entry.id):match("^HM") and "HM") or "TM"
    if not number then
      local prefix, digits = tostring(entry.id):match("^([TH]M)(%d+)$")
      kind, number = prefix or kind, tonumber(digits)
    end
    if number then return 2000 + (kind == "HM" and 100 or 0) + number end
    return priority[entry.id] or 10000
  end

  return function(a, b, descending)
    local av, bv = rank(a), rank(b)
    if av ~= bv then
      if descending then return av > bv end
      return av < bv
    end
    if a.name ~= b.name then
      if descending then return a.name > b.name end
      return a.name < b.name
    end
    if descending then return a.id > b.id end
    return a.id < b.id
  end
end
