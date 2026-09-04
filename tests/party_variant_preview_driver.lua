-- Focused roster renderer for visualising Modern Party UI option variants.
-- Canonical settings are supplied by component_preview_adapter.lua through
-- SUITE_PREVIEW_OPTIONS; PREVIEW_PARTY_COUNT and PREVIEW_WIDE select fixtures.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local PaletteFX = require("src.render.PaletteFX")
  local Pokemon = require("src.pokemon.Pokemon")
  local Growth = require("src.pokemon.Growth")
  local Screens = require("src.ui.Screens")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/modern-ui-suite-party-variant"

  if os.getenv("PREVIEW_WIDE") == "1" then
    love.window.setMode(1280, 720, {
      resizable = true, minwidth = 640, minheight = 576,
    })
  end
  game.save.options = game.save.options or {}
  game.save.options.colors = "redpp"
  PaletteFX.setMode("redpp")

  local specs = {
    { "VENUSAUR", 52, 1.00 }, { "CHARIZARD", 50, 0.52, "PAR" },
    { "BLASTOISE", 51, 0.18 }, { "PIKACHU", 42, 0.00 },
    { "SNORLAX", 38, 0.77, "SLP" }, { "MEW", 35, 1.00 },
  }
  local count = math.max(1, math.min(#specs,
    tonumber(os.getenv("PREVIEW_PARTY_COUNT")) or #specs))
  local party = {}
  for index = 1, count do
    local spec = specs[index]
    local mon = Pokemon.new(game.data, spec[1], spec[2])
    mon.hp = math.floor(mon.stats.hp * spec[3])
    mon.status = spec[4]
    local def = game.data.pokemon[mon.species]
    local nextExp = Growth.expForLevel(def.growthRate, mon.level + 1,
      game.data.growth_rates)
    mon.exp = math.floor((mon.exp + nextExp) / 2)
    party[index] = mon
  end
  game.save.party = party

  while game.stack:top() do game.stack:pop() end
  local menu = Screens.push(game, "PartyMenu", {})
  menu.index = math.min(2, #party)
  U.wait(12)
  if not menu.modernPartyUI then
    error("MODERN UI SUITE PARTY VARIANT FAILED: modern roster is inactive", 0)
  end
  U.log("PASS Modern Party option variant rendered with", count, "members")
  assert(U.shot(game, DIR .. "/party.png"), "party screenshot failed")
end
