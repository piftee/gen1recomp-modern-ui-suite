-- The provider owns sprite loading. The suite owns only the selected hero.
return function(mod,qol)
  local GV=require("src.core.GameVersion")
  local providerId="crystal_animated_sprites_with_shiny_visuals"
  local game,writing
  local wrapped=setmetatable({},{__mode="k"})
  local function provider()return mod.find(providerId)end
  local function data(g,create)
    if not (g and g.save) then return end
    if create then g.save.modData=g.save.modData or {} end
    local all=g.save.modData
    if all and create then all[mod.id]=all[mod.id] or {} end
    return all and all[mod.id]
  end
  local function sprite(g)
    local d=data(g)
    if not (d and d.highlanderGender) then return end
    local girl=d.highlanderGender=="girl"
    if GV.generation and GV.generation()==2 then return girl and "kris_flip.png" or "gold_flip.png" end
    return girl and "leaf_flip.png" or "red.png"
  end
  local function apply(g)
    game=g or game
    local p=provider()
    local d=data(game)
    local selection=sprite(game)
    if not (p and d and selection) or GV.get()=="crystal" then return end
    local options=game.save.options
    local fn=p.exports and p.exports.applyOption
    if type(fn)~="function" then return end
    local function set(key,value)
      options[key]=value
      writing=true
      local ok,err=pcall(fn,key,value)
      writing=false
      if not ok then error(err,0) end
    end
    if qol.on("force_crystal_settings") then
      if not d.highlanderCrystalBefore then
        d.highlanderCrystalBefore={trainers=options.crystalTrainers,
          player=options.crystalPlayerSprite}
      end
      set("crystalTrainers","all");set("crystalPlayerSprite",selection)
    elseif d.highlanderCrystalBefore then
      local before=d.highlanderCrystalBefore
      local defaultSprite=GV.generation and GV.generation()==2 and "gold_flip.png" or "red.png"
      set("crystalTrainers",before.trainers or "both");set("crystalPlayerSprite",before.player or defaultSprite)
      options.crystalTrainers=before.trainers;options.crystalPlayerSprite=before.player
      d.highlanderCrystalBefore=nil
    end
    if not wrapped[p.exports] then
      wrapped[p.exports]=true
      p.exports.applyOption=function(key,value)
        if not writing and qol.on("force_crystal_settings") and sprite(game) then
          if key=="crystalTrainers" then value="all" end
          if key=="crystalPlayerSprite" then value=sprite(game) end
          if game and game.save and (key=="crystalTrainers" or key=="crystalPlayerSprite") then
            game.save.options[key]=value
          end
        end
        return fn(key,value)
      end
    end
  end
  local function dress(speech)
    if GV.get()=="crystal" then return end
    local p=provider()
    local selection=sprite(speech.game)
    if not (p and selection and qol.on("force_crystal_settings")) then return end
    if speech._highlanderSprite==selection then return end
    -- mod.find returns a public exports handle, not another mod's assets API.
    -- Resolve artwork through the provider's normal player.sprite hook.
    local path=require("src.mods.Runtime").call("player.sprite",function()end,nil,
      {side="front",kind="intro",data=speech.game.data})
    if not path then return end
    local ok,img=pcall(love.graphics.newImage,path)
    if not ok or not img then return end
    img:setFilter("nearest","nearest")
    speech._highlanderSprite=selection
    speech.playerPic=img;speech.playerTrueColor=true
    if GV.generation and GV.generation()==2 then
      speech.playerPicFemale=img
      speech.playerPicNow=function()return img,nil end
    end
  end
  mod.hooks:wrap("intro.oak_speech.build",function(next,steps,speech)
    steps=next(steps,speech) or steps
    if not provider() or not qol.on("force_crystal_settings") or GV.get()=="crystal" then return steps end
    for _,step in ipairs(steps) do
      if step.saveKey=="gender" or step.saveKey=="suite_gender" then return steps end
    end
    table.insert(steps,1,{id="highlander_gender",kind="choice",saveKey="suite_gender",
      text="Are you a boy?\nOr a girl?",choices={"BOY","GIRL"},values={"boy","girl"},cancelable=false})
    return steps
  end)
  mod.events:on("intro.oak_speech.answered",function(ev)
    if not ev or GV.get()=="crystal" or (ev.saveKey~="suite_gender" and ev.saveKey~="gender") or not provider() then return end
    local g=ev.speech.game
    local d=data(g,true)
    d.highlanderGender=(ev.value=="girl" or ev.value=="female") and "girl" or "boy"
    if not GV.generation or GV.generation()==1 then g.save.player.gender=d.highlanderGender end
    apply(g);dress(ev.speech)
  end)
  mod.events:on("intro.oak_speech.step",function(ev)
    if ev and ev.speech then dress(ev.speech) end
  end)
  mod.events:on("game.ready",function(ev)game=ev and (ev.game or ev);apply(game)end)
  mod.events:on("save.loaded",function(ev)apply(ev and ev.game or game)end)
  mod.events:on("mod.options_changed",function(ev)
    if ev and ev.mod==mod.id and ev.key=="qol.force_crystal_settings" then apply(game) end
  end)
  return {apply=apply,sprite=sprite}
end
