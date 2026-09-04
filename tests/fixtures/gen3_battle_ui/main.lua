-- The real overhaul reconstructs large battle dialogue from current.text in
-- finished-frame HUD links at priorities 10000/11000. Record the source seen
-- there so the suite can prove terminal control markers never reach it.
return function(mod)
  mod.options:define({
    { key = "revampedBattleUI", type = "toggle", default = true },
    { key = "revampedPokemonMenu", type = "toggle", default = true },
  })

  mod.hooks:wrap("render.hud", function(next, game, viewport)
    local result = next(game, viewport)
    local top = game and game.stack and game.stack:top() or nil
    if top and top.phase == "messages" and top.current then
      game.gen3FixtureMessage = top.current.text
    end
    return result
  end, 11000)
end
