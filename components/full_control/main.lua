-- Reuse the engine's release-to-confirm binding editor and saved bindings.
-- Only opted-in playthroughs replace default aliases or display chords.
return function(mod)
  mod.options:define({
    {key="enabled",label="FULL CONTROL",type="toggle",default=false},
    {key="analog_left",label="LEFT STICK",type="toggle",default=true},
    {key="analog_right",label="RIGHT STICK",type="toggle",default=false},
  })
  local function enabled() return mod.options:get("enabled")==true end
  local Input=require("src.core.Input")
  local defaults={up={key="up",pad="dpup"},down={key="down",pad="dpdown"},
    left={key="left",pad="dpleft"},right={key="right",pad="dpright"},
    a={key="z",pad="a"},b={key="x",pad="b"},start={key="escape",pad="start"},
    select={key="tab",pad="back"},speedUp={pad="rightshoulder"},speedDown={pad="leftshoulder"}}
  local apply=Input.applyBindings
  Input.applyBindings=function(self,overlay)
    apply(self,overlay)
    if not enabled() then return end
    local keys,pads,joys,actions={},{},{},{}
    local function put(action,binding)
      if type(binding)=="string" then binding={key=binding} end
      if type(binding)~="table" then return end
      if binding.key and binding.key~="" then keys[binding.key]=action end
      local pad=binding.pad
      if pad and pad~="" then
        pads[pad]=nil;actions[pad]=nil
        local index=tonumber(pad:match("^joy(%d+)$"))
        if index then joys[index]=action
        elseif action=="speedUp" or action=="speedDown" then actions[pad]=action
        else pads[pad]=action end
      end
    end
    -- Defaults only fill unconfigured actions. Explicit bindings take priority
    -- even when a user assigns Start/Back to a different logical action.
    for action,def in pairs(defaults) do if not (overlay and overlay[action]) then put(action,def) end end
    local order={};for action in pairs(overlay or {}) do order[#order+1]=action end;table.sort(order)
    for _,action in ipairs(order) do put(action,overlay[action]) end
    self.keyBindings,self.padBindings,self.joyBindings,self.padActions=keys,pads,joys,actions
  end
  local axis=Input.gamepadaxis
  Input.gamepadaxis=function(self,pad,name,value)
    if not enabled() then return axis(self,pad,name,value) end
    local side=name:match("^(left)") or name:match("^(right)")
    local coordinate=name:sub(-1)
    if not side or (coordinate~="x" and coordinate~="y") then return axis(self,pad,name,value) end
    if mod.options:get("analog_"..side)==false then value=0 end
    self._suiteSticks=self._suiteSticks or {}
    local state=self._suiteSticks[side] or {x=0,y=0};self._suiteSticks[side]=state
    state[coordinate]=value
    local dir=state.dir
    if math.abs(state.x)>0.5 or math.abs(state.y)>0.5 then
      dir=math.abs(state.x)>=math.abs(state.y) and (state.x>0 and "right" or "left")
        or (state.y>0 and "down" or "up")
    elseif math.abs(state.x)<0.3 and math.abs(state.y)<0.3 then dir=nil end
    if dir~=state.dir then
      if state.dir then self:sourceRelease(state.dir,"suite-stick:"..side) end
      if dir then self:sourcePress(dir,"suite-stick:"..side) end
      state.dir=dir
    end
  end
  local reset=Input.reset
  Input.reset=function(self,...)
    self._suiteSticks=nil
    return reset(self,...)
  end
  local Game=require("src.core.Game")
  local GV=require("src.core.GameVersion")
  local Owner=GV.generation and GV.generation()==2 and require("src.core.Game2") or Game
  local keypressed=Owner.keypressed
  if keypressed then Owner.keypressed=function(self,key,...)
    local input=self.input or Input
    if not enabled() or not input.keyBindings[key] then return keypressed(self,key,...) end
    local top=self.stack and self.stack:top()
    if top and top.onKeyPressed then return top:onKeyPressed(key) end
    return input:keypressed(key)
  end end
  local pressed=Owner.gamepadpressed
  if pressed then Owner.gamepadpressed=function(self,pad,button)
    if not enabled() then return pressed(self,pad,button) end
    local top=self.stack and self.stack:top()
    if top and top.onGamepadPressed then return top:onGamepadPressed(button) end
    local input=self.input or Input
    local action=input.padActions and input.padActions[button]
    if action and self._cycleSpeed then return self:_cycleSpeed(action=="speedUp" and 1 or -1) end
    return input:gamepadpressed(pad,button)
  end end
  local wasEnabled=false
  local function refresh(ev)
    local game=ev and (ev.game or ev)
    if not (game and game.save) then game=Game end
    if not (game and game.save) then return end
    if not enabled() and not wasEnabled then return end
    wasEnabled=enabled()
    local input=game.input or Input
    if type(input.reset)=="function" then input:reset() end
    if type(input.applyBindings)=="function" then input:applyBindings(game.save.options and game.save.options.bindings) end
  end
  mod.events:always("game.ready",refresh)
  mod.events:always("mod.options_changed",function(ev)
    if ev and (ev.mod==mod.id or (ev.key and ev.key:match("^fullctl%."))) then refresh() end
  end)
  mod.exports.openBindings=function(game)
    local page=require("src.ui.BindingsMenu").new(game)
    page.modernUiSuiteComponent="full_control"
    game.stack:push(page)
    return true
  end
end
