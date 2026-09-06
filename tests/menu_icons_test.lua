package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local factory = dofile("mods/modern_ui_suite/core/menu_icons.lua")
local base = { species = { CHARIZARD = "ICON_MONSTER" }, icons = {
  ICON_MONSTER = { image = "native-icon", width=16, height=32, frames=2 },
} }
local source, animate = "auto", true
local reads, depth, calls, failDraw = 0, 0, {}, false
local assets = {}
for _, path in ipairs({"native-icon", "mods/unique/icon_color/CHARIZARD.png"}) do
  assets[path] = {path=path, getDimensions=function() return 16,32 end}
end
local palette = {partyMenu={{"native colors"}}}
local nativeDraw = function(self, mon, x, y)
  if failDraw then error("draw failure") end
  local image, frame = self:iconFor(mon)
  calls[#calls+1] = {image=image, frame=frame, mon=mon, palettes=self.palettes, x=x,y=y}
end
local party = {
  drawIcon = function() error("pack wrapper must not intercept explicit Original") end,
  __uniqueMenuIconsGoldPartyMenu={originalDrawIcon=nativeDraw},
}
package.loaded["src.core.GameVersion"] = {generation=function() return 2 end}
package.loaded["src.core.Game"] = {data={gen2Icons=base}}
package.loaded["src.ui.gen2.PartyMenu"] = party
package.loaded["src.render.Assets"] = {image=function(path)
  reads=reads+1; return assert(assets[path], "missing icon")
end}
love = {graphics={push=function() depth=depth+1 end, pop=function() depth=depth-1 end,
  setShader=function() end}}
local registry = {
  ops={CHARIZARD={{owner="unique_menu_icons",op="override",value="ICON_UNIQUE"}}},
  get=function() return {image="mods/unique/icon_color/CHARIZARD.png"} end,
}
local enabled = true
local mod = {options={get=function(_,key)
  if key=="party.sprite_source" then return source end
  if key=="party.animate_icons" then return animate end
end}, find=function(id)
  if enabled and id=="unique_menu_icons" then return {exports={ownsPartyIcons=true}} end
end}
local draw = factory(mod)
-- The live registry is changed after installation, just like the loader merge.
base.species.CHARIZARD="ICON_UNIQUE"
base.icons.ICON_MONSTER.image="mutated"
local game = {mods={content={icons=registry}}}
local renderer={clock=17,palettes=palette, iconCache={}}
local mon={species="CHARIZARD",item="FLOWER_MAIL"}
T.eq(draw(game,renderer,mon,3,4),false,"Auto leaves the installed renderer in control")
T.eq(reads,0,"Auto never loads a replacement icon")
source="original"
T.eq(draw(game,renderer,mon,3,4),true,"Original uses the pre-merge native assignment")
T.eq(calls[1].image.path,"native-icon","Original remains independent from the live registry")
T.eq(calls[1].frame,1,"native two-frame icon timing is preserved")
T.eq(calls[1].mon,mon,"native item/mail drawing receives the complete original mon")
T.eq(calls[1].palettes,palette,"Original keeps the native palette")
T.eq(renderer.palettes,palette,"renderer palette is not mutated")
T.eq(renderer.iconFor,nil,"renderer methods are not mutated")
T.eq(depth,0,"drawing balances the graphics state")
source="menu_pack"
T.eq(draw(game,renderer,mon,3,4),true,"Menu Pack resolves its explicit registry contribution")
T.eq(calls[2].image.path,"mods/unique/icon_color/CHARIZARD.png","Menu Pack uses actual icon artwork")
T.eq(calls[2].palettes,false,"full-colour pack keeps source RGB")
T.eq(renderer.palettes,palette,"full-colour handling stays local to the call")
animate=false; draw(game,renderer,mon,3,4)
T.eq(calls[3].frame,0,"icon animation preference remains independent of portraits")
T.eq(draw(game,renderer,{species="CHARIZARD",isEgg=true},3,4),false,"eggs use native icon handling")
enabled=false
T.eq(draw(game,renderer,mon,3,4),false,"disabled icon pack falls back to installed handling")
enabled=true; source="follower_pack"
T.eq(draw(game,renderer,mon,3,4),false,"unavailable follower pack falls back")
source="menu_pack"; assets["mods/unique/icon_color/CHARIZARD.png"]=nil
T.eq(draw(game,renderer,mon,3,4),false,"missing icon artwork falls back without a blank override")
source="original"; failDraw=true
T.eq(pcall(draw,game,renderer,mon,3,4),false,"native draw failure propagates")
T.eq(depth,0,"graphics state is restored after failure")
T.eq(renderer.palettes,palette,"failure cannot change native palette")
T.eq(renderer.iconFor,nil,"failure cannot change native icon resolver")
T.finish("suite_menu_icons")
