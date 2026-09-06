-- Derive one native caught marker from the player's imported artwork.
-- No ROM pixels are included in the package; trainer rows keep their sheet.
return function(ctx)
  if not ctx.exists("battle/balls.png") then return end
  local marker = ctx.blank(8, 8)
  ctx.blit(marker, ctx.readImage("battle/balls.png"), 0, 0, 0, 0, 8, 8)
  ctx.writeImage(marker, "battle/caught_ball_mono.png")
  -- Keep the native outline and transparency, with a fixed red/white fill.
  -- The marker is independent of both the HP palette and species colours.
  marker:mapPixel(function(x, y, r, g, b, a)
    if a == 0 or r <= 0.17 then return r, g, b, a end
    if x == 3 and y == 3 then return 1, 176/255, 176/255, a end
    if y < 5 then return 232/255, 64/255, 64/255, a end
    return 1, 1, 1, a
  end)
  ctx.writeImage(marker, "battle/caught_ball.png")
end
