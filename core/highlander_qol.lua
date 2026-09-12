-- Highlander gameplay options are independent of the Unlimited PP/UI switches.
return function(mod, settings)
  local GV = require("src.core.GameVersion")
  local gen2 = GV.generation and GV.generation() == 2
  local id = "unlimited_pp"
  local schema = settings.schemas[id]
  local rows = {
    {key="running_shoes", label="RUNNING SHOES", type="choice", default="off",
      choices={{"OFF","off"},{"HOLD B","hold"},{"PRESS B","toggle"}}},
    {key="always_boosted_exp", label="BOOSTED EXP", type="toggle", default=false},
    {key="modern_exp_share", label="MODERN EXP SHARE", type="toggle", default=false},
    {key="decapitalize", label="DECAPITALIZE", type="toggle", default=false},
    {key="sparkling_hidden", label="HIDDEN SPARKLES", type="toggle", default=false},
    {key="infinite_safari", label="INFINITE SAFARI", type="toggle", default=false},
    {key="rematch_anyone", label="REMATCH ANYONE", type="toggle", default=false},
    {key="pikachu_sound", label="PIKACHU SOUND", type="choice", default="yellow",
      choices={{"YELLOW","yellow"},{"ORIGINAL","original"}}},
    {key="force_crystal_settings", label="FORCE CRYSTAL", type="toggle", default=true},
  }
  for _, row in ipairs(rows) do
    if not gen2 or (row.key~="infinite_safari" and row.key~="pikachu_sound") then
      schema[#schema+1] = row
    end
  end
  settings:registerSchema(id, schema)
  local function get(key) return settings:get(id, key) end
  local function on(key) return get(key) == true end
  local activeGame, toggled, previousMode
  local function offline(battle)
    return not battle or (battle.kind ~= "link" and not battle.linkBattle)
  end
  mod.events:on("game.ready", function(ev)
    activeGame = ev and (ev.game or ev)
    toggled = false
  end)
  mod.events:on("save.loaded", function() toggled = false end)
  local Input=require("src.core.Input")
  local inputStep=Input.step
  Input.step=function(self,...)
    local result=inputStep(self,...)
    local mode=get("running_shoes")
    if mode~=previousMode then toggled=false;previousMode=mode end
    local game=activeGame
    local top=game and game.stack and game.stack:top()
    local inField=top and top.isOverworld or (not top and game and game.phase=="play")
    if mode=="toggle" and inField and self:wasPressed("b") then toggled=not toggled end
    return result
  end
  mod.hooks:wrap("movement.speed", function(next, frames, ctx)
    frames = next(frames, ctx)
    local mode = get("running_shoes")
    if not ctx or ctx.onBike or ctx.surfing or ctx.downhill
        or (ctx.player and ctx.player.inputLocked) then return frames end
    local running = mode == "toggle" and toggled
      or mode == "hold" and ctx.input and ctx.input:isDown("b")
    return running and math.max(1, math.floor(frames / 2)) or frames
  end)
  mod.hooks:wrap("exp.gain", function(next, ctx)
    if not on("always_boosted_exp") or not offline(ctx and ctx.battle) then return next(ctx) end
    -- Never alter OT IDs, traded status, obedience or the caller's context.
    local copy = {}; for k,v in pairs(ctx) do copy[k]=v end
    copy.traded = true
    return next(copy)
  end)
  local expCapture
  mod.events:on("battle.exp_gained",function(ev)
    if expCapture and ev and ev.battle==expCapture.battle then
      expCapture.amounts[ev.mon]=ev.gained
    end
  end)
  mod.hooks:wrap("battle.exp_award", function(next, ctx)
    if not on("modern_exp_share") or not ctx or not offline(ctx.battle)
        or type(ctx.applyShare) ~= "function" then return next(ctx) end
    local battle, fought = ctx.battle, {}
    for _, mon in ipairs(ctx.alive or {}) do fought[mon] = true end
    local party = battle and (battle.party or (battle.game and battle.game.save.party)) or {}
    local nativeGen2=ctx.loser and type(battle.giveExperiencePass)=="function"
    local queue=battle and (nativeGen2 and battle.events or battle.queue)
    local function position()
      return nativeGen2 and #(queue or {}) or (battle and battle.nextInsert or 0)
    end
    local first=position()+1
    local announcements,bench={},{}
    local previousCapture=expCapture
    local capture={battle=battle,amounts={}}
    expCapture=capture
    local ok,err=pcall(function()
      -- Announce the fighters normally. Pay the bench silently, retaining all
      -- native stats, level commits, happiness and move-learning callbacks.
      for _,participants in ipairs({true,false}) do
        for index,mon in ipairs(party) do
          if (fought[mon]==true)==participants and (mon.hp or 0)>0
              and not mon.isEgg and not mon.egg then
            local before=position()
            local split=participants and 1 or 2
            if nativeGen2 then
              -- EXP.SHARE's captured halving must still be bypassed.
              battle:giveExperiencePass(ctx.loser,battle.data.pokemon[ctx.loser.species],
                {index},split,false,not participants)
            else ctx.applyShare(mon,split,participants) end
            if participants and queue and position()>before then
              if nativeGen2 then
                for i=before+1,position() do
                  if queue[i].kind=="experience" then announcements[queue[i]]=true end
                end
              else announcements[queue[before+1]]=true end
            elseif not participants then bench[#bench+1]=mon end
          end
        end
      end
    end)
    expCapture=previousCapture
    if not ok then error(err,0) end
    if not queue or #bench==0 then return end

    local low,high
    for _,mon in ipairs(bench) do
      local amount=tonumber(capture.amounts[mon])
      if amount then low=math.min(low or amount,amount);high=math.max(high or amount,amount) end
    end
    local Strings=require("src.core.Strings")
    local summary=low and (low==high
      and Strings("The rest of your\nparty got %d EXP!",low)
      or Strings("The rest of your\nparty got %d-%d EXP!",low,high))
      or Strings("The rest of your\nparty gained EXP!")
    local messages,animations,progress={},{},{}
    local last=position()
    for i=first,last do
      local row=queue[i]
      if announcements[row] then
        if nativeGen2 then
          -- Gen 2's EXP animation can consume its later level-up line.
          -- Start that animation after the party summary so levels cannot
          -- jump ahead of the shared award text.
          local message={};for key,value in pairs(row) do message[key]=value end
          message.kind="message";messages[#messages+1]=message
          local animation={};for key,value in pairs(row) do animation[key]=value end
          animation.text=nil;animations[#animations+1]=animation
        else messages[#messages+1]=row end
      else progress[#progress+1]=row end
    end
    messages[#messages+1]={kind=nativeGen2 and "message" or nil,text=summary,modernPartyExp=true}
    for _,row in ipairs(animations) do messages[#messages+1]=row end
    for _,row in ipairs(progress) do messages[#messages+1]=row end
    -- Replace only this award's rows. Earlier/later battle work stays in order.
    for i=last,first,-1 do table.remove(queue,i) end
    for i,row in ipairs(messages) do table.insert(queue,first+i-1,row) end
    if not nativeGen2 then battle.nextInsert=first+#messages-1 end
  end)

  local KEEP = {HP=true,PP=true,PC=true,TM=true,HM=true,OK=true,TV=true,
    CD=true,ID=true,KO=true,EXP=true,SS=true,VIP=true,PK=true,MN=true}
  local function decap(text)
    if type(text) ~= "string" then return text end
    -- Keep engine tokens and ROM control bytes intact. Only ASCII words in
    -- an otherwise unchanged string are case folded; user saves are untouched.
    local function words(part)
      return part:gsub("%u[%u']+", function(word)
        if KEEP[word] then return word end
        return word:sub(1,1)..word:sub(2):lower()
      end)
    end
    local out, from = {}, 1
    for first, token, last in text:gmatch("()(<[^>]+>)()") do
      out[#out+1] = words(text:sub(from,first-1)); out[#out+1]=token; from=last
    end
    out[#out+1]=words(text:sub(from))
    return table.concat(out):gsub("PokéMon","Pokémon"):gsub("PokéDex","Pokédex")
  end
  local Font = require("src.render.Font")
  for _, key in ipairs({"draw", "encode"}) do
    local original = Font[key]
    if type(original) == "function" then
      Font[key] = function(text, ...)
        return original(on("decapitalize") and decap(text) or text, ...)
      end
    end
  end

  if gen2 then
    local World=require("src.world.gen2.World")
    local Hidden=require("src.world.gen2.HiddenItems")
    local draw=World.drawWorldBody
    World.drawWorldBody=function(self,scale,...)
      local result=draw(self,scale,...)
      if not on("sparkling_hidden") or not self.map or not self.camera then return result end
      local g=love.graphics;g.push("all");scale=scale or 1
      local now=love.timer.getTime()
      for _,h in ipairs(Hidden.unfound(self.map.def,self.events)) do
        local x=(h.x*16+8-self.camera.x)*scale
        local y=(h.y*16+8-self.camera.y)*scale
        g.setColor(1,1,0.65,0.4+0.6*math.abs(math.sin(now*4+h.x+h.y)))
        g.rectangle("fill",x-3*scale,y,7*scale,scale)
        g.rectangle("fill",x,y-3*scale,scale,7*scale)
      end
      g.pop();return result
    end
  end
  if not gen2 then
    local OW = require("src.world.OverworldController")
    local safariStep = OW.safariStep
    if safariStep then
      OW.safariStep = function(self, ...)
        if on("infinite_safari") then return false end
        return safariStep(self, ...)
      end
    end
    local drawWorld = OW.drawWorld
    if drawWorld then
      OW.drawWorld = function(self, ...)
        local result = drawWorld(self, ...)
        if not on("sparkling_hidden") then return result end
        local game = self.game or activeGame
        local map, cam = self.map, self.camera
        if not (game and map and cam) then return result end
        local field, taken = game.data.field or {}, game.save.hiddenTaken or {}
        local g = love.graphics
        g.push("all")
        local now = love.timer.getTime()
        for _, group in ipairs({field.hiddenItems or {}, field.hiddenCoins or {}}) do
          for _, h in ipairs(group[map.id] or {}) do
            local key = map.id.."_"..h.x.."_"..h.y
            if not taken[key] then
              local pulse = 0.4 + 0.6 * math.abs(math.sin(now*4+h.x+h.y))
              local x,y=h.x*16+8-cam.x,h.y*16+8-cam.y-(self.bgShakeY or 0)
              g.setColor(1,1,0.65,pulse)
              g.rectangle("fill",x-3,y,7,1); g.rectangle("fill",x,y-3,1,7)
            end
          end
        end
        g.pop()
        return result
      end
    end
    local Sound = require("src.core.Sound")
    local pika = Sound.playPikaCry
    local chipCry=false
    if pika then
      Sound.playPikaCry = function(data, ...)
        if get("pikachu_sound") == "original" and GV.get() == "yellow" then
          if chipCry then return nil end
          chipCry=true
          local ok,result=pcall(Sound.playCry,data,"PIKACHU")
          chipCry=false
          if not ok then error(result,0) end
          return result
        end
        return pika(data, ...)
      end
    end
  end
  return {get=get, on=on, decapitalize=decap, offline=offline}
end
