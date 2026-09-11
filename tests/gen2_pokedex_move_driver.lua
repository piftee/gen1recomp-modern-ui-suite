-- Shared Pokédex QA includes native learnsets, move details and OFF/ON gating.
return function(game)
  return dofile(assert(os.getenv("PC_REPO"))
    .. "/mods/modern_ui_suite/tests/pokedex_parity_driver.lua")(game)
end
