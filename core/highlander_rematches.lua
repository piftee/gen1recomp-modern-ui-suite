return function(mod, qol)
  local GV=require("src.core.GameVersion")
  local gen2=GV.generation and GV.generation()==2
  local pending
  local function weakest(game)
    local level
    for _,mon in ipairs(game.save.party or {}) do
      if not mon.isEgg and not mon.egg then
        level=math.min(level or 100,tonumber(mon.level) or 1)
      end
    end
    return math.max(1,math.min(100,level or 1))
  end
  local function scaledSpecies(data,species,level)
    -- Walk back only across level evolutions that the new level cannot meet.
    local seen={}
    while not seen[species] do
      seen[species]=true
      local previous
      for id,def in pairs(data.pokemon) do
        for _,evo in ipairs(type(def)=="table" and def.evolutions or {}) do
          if (evo.species or evo.into)==species and tostring(evo.method):gsub("^EVOLVE_",""):lower()=="level"
              and (tonumber(evo.level) or 1)>level then previous=id end
        end
      end
      if not previous then break end
      species=previous
    end
    seen={}
    while not seen[species] do
      seen[species]=true
      local nextSpecies
      for _,evo in ipairs((data.pokemon[species] or {}).evolutions or {}) do
        local method=tostring(evo.method):gsub("^EVOLVE_",""):lower()
        if method=="level" and (tonumber(evo.level) or 101)<=level then
          nextSpecies=evo.species or evo.into;break
        end
      end
      if not nextSpecies then break end
      species=nextSpecies
    end
    return species
  end
  local function movesAt(data,species,level)
    local def=data.pokemon[species] or {}
    local list={}
    local function add(id)
      if not data.moves[id] then return end
      for i=#list,1,-1 do if list[i]==id then table.remove(list,i) end end
      list[#list+1]=id
      if #list>4 then table.remove(list,1) end
    end
    for _,id in ipairs(def.level1Moves or def.baseMoves or {}) do add(id) end
    for _,row in ipairs(def.learnset or {}) do
      if (row.level or 1)<=level then add(row.move) end
    end
    return list
  end
  mod.hooks:wrap("trainer.party",function(next,class,index,party)
    party=next(class,index,party)
    if not pending or not qol.on("rematch_anyone") then return party end
    local level=weakest(pending)
    local out={}
    for i,row in ipairs(party or {}) do
      local copy={};for k,v in pairs(row) do copy[k]=v end
      copy.level=level;copy.species=scaledSpecies(pending.data,row.species,level)
      if gen2 then
        copy=require("src.battle.gen2.Mon").new(pending.data,copy.species,level,
          {dvs=row.dvs,item=row.item})
      else copy.moves=movesAt(pending.data,copy.species,level) end
      out[i]=copy
    end
    return out
  end)
  local function construct(game,fn)
    pending=game
    local ok,result=pcall(fn)
    pending=nil
    if not ok then error(result,0) end
    return result
  end
  if not gen2 then
    local OW=require("src.world.OverworldController")
    local original=OW.talkTo
    OW.talkTo=function(self,npc)
      if not qol.on("rematch_anyone") or not npc or not npc.def
          or not npc.def.trainerClass or not self:trainerDefeated(npc) then
        return original(self,npc)
      end
      local game=self.game or require("src.core.Game")
      local healthy=false
      for _,mon in ipairs(game.save.party) do if (mon.hp or 0)>0 then healthy=true end end
      if not healthy then return original(self,npc) end
      local frozen=npc.frozen
      npc.frozen=true
      game.stack:push(require("src.render.TextBox").new(game,"Would you like\na rematch?",nil,
        {choice=function(yes)
          npc.frozen=frozen
          if not yes or not qol.on("rematch_anyone") then return original(self,npc) end
          local battle=construct(game,function()
            return require("src.battle.BattleState").newTrainer(game,npc.def.trainerClass,npc.def.trainerParty)
          end)
          battle.rematch=true
          -- Native battle money/EXP and afterBattle healing/evolution remain;
          -- first-win badges, TMs, events and story callbacks never replay.
          battle.onFinish=function(result)self:afterBattle(result,battle)end
          self:pushBattle(battle)
        end}))
    end
  else
    local World=require("src.world.gen2.World")
    local gymBadges={FALKNER="ZEPHYR",BUGSY="HIVE",WHITNEY="PLAIN",MORTY="FOG",
      CHUCK="STORM",JASMINE="MINERAL",PRYCE="GLACIER",CLAIR="RISING",
      BROCK="BOULDER",MISTY="CASCADE",LT_SURGE="THUNDER",ERIKA="RAINBOW",
      JANINE="SOUL",SABRINA="MARSH",BLAINE="VOLCANO",BLUE="EARTH"}
    local function gymRecord(world,npc)
      local mapId=world.map and world.map.id or ""
      if not mapId:upper():find("GYM",1,true) then return end
      local leader=npc and npc.def and tostring(npc.def.sprite):gsub("^SPRITE_","")
      local badge=gymBadges[leader]
      if not badge then return end
      local save=world.game.save
      local F=require("src.world.gen2.FieldMoves")
      local owned=F.hasBadge(save,badge)
      local kanto=save.player.kantoBadges or {}
      for i,name in ipairs(F.KANTO_BADGES) do
        if name==badge and (kanto[name] or kanto[i]) then owned=true end
      end
      local class=world.game.data.trainers.classes[leader]
      if owned and class then return {class=class.index,member=1},true end
    end
    local original=World.interactBody
    World.interactBody=function(self,...)
      local npc=self:facingObject()
      local record=npc and npc.def and npc.def.trainer
      local gym,beaten=gymRecord(self,npc)
      record=record or gym
      if not qol.on("rematch_anyone") or self:busy() or self.battleActive
          or (self.player and self.player.moving) or not record
          or not (beaten or self:trainerBeaten(record)) then
        return original(self,...)
      end
      local game=self.game
      game.stack:push(require("src.render.TextBox").new(game,"Would you like\na rematch?",nil,
        {choice=function(yes)
          if not yes then return original(self) end
          local trainer=self:trainerParty(record.class,record.member)
          if not trainer then return original(self) end
          construct(game,function()self:startScriptedBattle(trainer,nil,function()end)end)
        end}))
    end
  end
  return {weakest=weakest,scaledSpecies=scaledSpecies,movesAt=movesAt}
end
