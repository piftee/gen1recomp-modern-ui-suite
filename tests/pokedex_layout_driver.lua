-- Compatibility entry point for the expanded shared-presentation QA.
return function(game)
  return dofile(assert(os.getenv("PC_REPO"))
    .. "/mods/modern_ui_suite/tests/pokedex_parity_driver.lua")(game)
end
