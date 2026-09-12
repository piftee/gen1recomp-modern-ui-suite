-- Field learning uses the native Gen 2 dialogue/selection sequence (0.2.56).
return function(mod)
  local function on(key) return mod.options:enabled() and mod.options:get(key)==true end
  local Game2=require("src.core.Game2")
  local Screens=require("src.ui.Screens")
  local Strings=require("src.core.Strings")
  local TextBox=require("src.render.TextBox")
  local ModRuntime=require("src.mods.Runtime")
  local HM_MOVES={CUT=true,FLY=true,SURF=true,STRENGTH=true,FLASH=true,WATERFALL=true,WHIRLPOOL=true}
local function learnMoveOn(self, mon, moveId, onDone)
  local Mon = require("src.battle.gen2.Mon")
  local moveDef = (self.data.moves or {})[moveId]
  local moveName = (moveDef and moveDef.name) or moveId
  local name = mon.nickname or mon.name or mon.species or "?"
  local ok, reason, entry = Mon.learnMove(mon, moveId, self.data)
  local function finish(learned)
    if onDone then onDone(learned) end
  end
  if ok then
    -- data/text/common_3.asm:119
    return self:say(Strings("%s learned\n%s!", name, moveName),
      function() finish(true) end,
      TextBox.soundOpts(self, "Sfx_DexFanfare5079"))
  end
  if reason ~= "full" then return finish(false) end
  local askForget, pickMove, askStop
  -- DidNotLearnMoveText, then `ld b, 0` (learn.asm:110-113).
  local function decline()
    self:say(Strings("%s\ndid not learn\v%s.", name, moveName),
      function() finish(false) end)
  end
  -- ForgetMove's AskForgetMoveText + YesNoBox (learn.asm:123-127).
  askForget = function()
    self.stack:push(TextBox.new(self,
      Strings("%s is\ntrying to learn\v%s.\fBut %s\ncan't learn more\vthan four moves.\fDelete an older\nmove to make room\vfor %s?",
        name, moveName, name, moveName),
      nil, { choice = function(yes)
        if yes then return pickMove() end
        return askStop()
      end }))
  end
  -- StopLearningMoveText, whose NO is `jp c, .loop` (learn.asm:104-108).
  askStop = function()
    self.stack:push(TextBox.new(self,
      Strings("Stop learning\n%s?", moveName), nil,
      { choice = function(yes)
        if yes then return decline() end
        return askForget()
      end }))
  end
  -- engine/pokemon/learn.asm:135-166
  local function pushList()
    Screens.push(self, "Gen2MoveDeleter", {
      mon = mon,
      moves = self.data.moves,
      layout = "forget",
      onCancel = function()
        self.stack:pop() -- the move list
        self.stack:pop() -- the question it stood on
        askStop()
      end,
      onChoose = function(slot)
        local old = mon.moves[slot]
        self.stack:pop() -- the move list
        -- MoveCantForgetHMText, then `jr .loop` (learn.asm:183-197): the
        -- question stays up and the list comes back over it.
        if old and HM_MOVES[old.id] and not on("forgettable_hms") then
          return self:say(Strings("HM moves can't be\nforgotten now."), pushList)
        end
        self.stack:pop() -- the question the list stood on
        local oldDef = (self.data.moves or {})[old and old.id]
        local oldName = (oldDef and oldDef.name) or (old and old.id) or "?"
        mon.moves[slot] = entry
        -- The slot is written here rather than through Mon.learnMove, so
        -- pokemon.move_learned is raised here too.
        ModRuntime.emit("pokemon.move_learned", { mon = mon, moveId = moveId })
        -- engine/pokemon/learn.asm:225-229, data/text/common_3.asm:165-173
        self:say(Strings("1, 2 and…\1 Poof!\1\f%s forgot\n%s.\fAnd…\f%s learned\n%s!",
            name, oldName, name, moveName),
          function() finish(true) end,
          TextBox.soundOpts(self, "Sfx_DexFanfare5079",
            { pauseSounds = { "Sfx_SwitchPokemon" } }))
      end,
    })
  end
  -- MoveAskForgetText, a `done` text: the box stays while the list stands on
  -- it (learn.asm:136-137).
  pickMove = function()
    self.stack:push(TextBox.new(self, Strings("Which move should\nbe forgotten?"), nil,
      { stay = { onShown = pushList } }))
  end
  askForget()
end

  local originalLearn=Game2.learnMoveOn
  Game2.learnMoveOn=function(self,...)
    if on("forgettable_hms") then return learnMoveOn(self,...) end
    return originalLearn(self,...)
  end
  local consume=Game2.consumeItem
  if consume then Game2.consumeItem=function(self,id,...)
    if on("tms_forever") and type(id)=="string" and id:match("^TM_") then return true end
    return consume(self,id,...)
  end end
  local Battle=require("src.ui.gen2.BattleState")
  local update=Battle.update
  Battle.update=function(self,...)
    local input=self.game.input
    if on("forgettable_hms") and self.phase=="choose-forget"
        and (self.messageTimer or 0)<=0 and input:wasPressed("a")
        and not input:wasPressed("b") and not input:wasPressed("up") and not input:wasPressed("down") then
      local learn=self.pendingLearn
      local mon=learn and self.battle.party[learn.index]
      local slot=mon and mon.moves[self.forgetIndex]
      if slot and HM_MOVES[slot.id] then
        self.battle:resolveForget(learn.index,self.forgetIndex,learn.move,learn.moveName)
        self.pendingLearn=nil;self.phase="resolving"
        self:pushFront(self.battle:takeEvents());self:advanceQueue()
        return
      end
    end
    return update(self,...)
  end
  -- Gen 2 already has contextual A field moves; add the SELECT utility list
  -- through its native registered-item action, after its standing/busy gates.
  local selectMenu=Game2.useSelectItem
  if selectMenu then Game2.useSelectItem=function(self,...)
    if not on("instant_tmhm") then return selectMenu(self,...) end
    local F=require("src.world.gen2.FieldMoves")
    local world=self.world
    if not world or world:busy() or world.battleActive then return selectMenu(self,...) end
    local items={}
    for _,move in ipairs({"FLASH","FLY","DIG","TELEPORT"}) do
      local mon=F.partyMoveUser(self.save.party,move,world:fieldContext())
      if mon then
        items[#items+1]={label=move,onSelect=function()
          world:useFieldMove(move,mon)
        end}
      end
    end
    if #items==0 then return selectMenu(self,...) end
    items[#items+1]={label="CANCEL"}
    self.stack:push(require("src.ui.Menu").new(self,items,{tx=6,ty=1,tw=13,th=12}))
  end end
end
