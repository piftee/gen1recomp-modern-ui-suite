-- Shared native Bag proof covers both generations and responsive layouts.
return function(game)
  return assert(dofile(assert(os.getenv("PC_REPO")) ..
    "/mods/modern_ui_suite/tests/bag_layout_parity_driver.lua"))(game)
end
