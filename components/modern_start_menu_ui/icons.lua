-- Native 16x16 one-bit frames from NikoIchu's CC0 Pixel Icons, plus a
-- matching custom Poké Ball for the party action. The source grid is copied
-- directly: no scaling, tracing, interpolation, or runtime conversion.
-- Keeping frame lookup separate from rendering lets third-party entries fall
-- back to the generic frame without taking ownership of their callback or
-- label.
return {
  asset = "assets/start_menu_icons.png",
  size = 16,
  paletteSize = 1,
  frames = {
    pokedex = 0,
    party = 1,
    bag = 2,
    trainer = 3,
    save = 4,
    options = 5,
    pokegear = 6,
    link = 7,
    mods = 8,
    quit = 9,
    generic = 10,
    auto = 11,
    quest = 12,
    map = 13,
    music = 14,
    camera = 15,
    trophy = 16,
    heart = 17,
    star = 18,
    tools = 19,
    key = 20,
    clock = 21,
    mail = 22,
    chat = 23,
    home = 24,
    shop = 25,
    chest = 26,
    battle = 27,
    potion = 28,
    bicycle = 29,
    craft = 30,
    search = 31,
  },
}
