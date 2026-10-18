-- Some companion forget handlers append their result behind the remaining
-- battle dialogue. Native Gen 2 uses pushFront: learning completes before
-- the next EXP award, send-out, victory text, or evolution continuation.
return function()
  local GV = require("src.core.GameVersion")
  if not (GV.generation and GV.generation() == 2) then return end
  local Battle = require("src.battle.gen2.Battle")
  local Screen = require("src.ui.gen2.BattleState")
  if Battle._modernLearningOrder then return end
  Battle._modernLearningOrder = true
  local results = setmetatable({}, { __mode = "k" })
  local resolve = Battle.resolveForget
  local append = Screen.pushAll
  local prepend = Screen.pushFront
  if not (resolve and append and prepend) then return end

  Battle.resolveForget = function(self, ...)
    -- Only mark a fresh result batch. Never move pre-existing battle events.
    local events = self.events
    local fresh = type(events) == "table" and #events == 0
    local ok = resolve(self, ...)
    if ok and fresh and self.events == events and #events > 0 then
      results[events] = true
    end
    return ok
  end
  Screen.pushAll = function(self, events)
    if events and results[events] then
      results[events] = nil
      return prepend(self, events)
    end
    return append(self, events)
  end
  Screen.pushFront = function(self, events)
    if events then results[events] = nil end
    return prepend(self, events)
  end
end
