-- Short, optional pulses through LOVE's timed vibration API.
return function(mod)
  mod.options:define({
    {key="enabled",label="CONTROLLER RUMBLE",type="toggle",default=false},
    {key="intensity",label="INTENSITY",type="choice",default=0.35,
      choices={{"LOW",0.2},{"MEDIUM",0.35},{"HIGH",0.6}}},
  })
  local owned=setmetatable({},{__mode="k"})
  local function stop()
    for pad in pairs(owned) do pcall(pad.setVibration,pad,0,0);owned[pad]=nil end
  end
  local function pulse(duration)
    if mod.options:get("enabled")~=true or not mod.options:enabled() then return end
    if not (love and love.joystick and love.joystick.getJoysticks) then return end
    local intensity=tonumber(mod.options:get("intensity")) or 0.35
    for _,pad in ipairs(love.joystick.getJoysticks()) do
      if pad.isVibrationSupported and pad:isVibrationSupported() then
        local ok,active=pcall(pad.setVibration,pad,intensity,intensity*0.6,duration)
        if ok and active~=false then owned[pad]=true end
        break
      end
    end
  end
  for name,duration in pairs({["battle.move_used"]=0.08,["battle.fainted"]=0.16,
      ["battle.ball_thrown"]=0.08,["pokemon.caught"]=0.22,["pokemon.level_up"]=0.16,
      ["pokemon.evolved"]=0.24,["world.boulder_moved"]=0.1}) do
    mod.events:on(name,function()pulse(duration)end)
  end
  mod.events:always("mod.options_changed",function()
    if mod.options:get("enabled")~=true or not mod.options:enabled() then stop() end
  end)
  mod.events:always("game.ready",stop)
  mod.exports.pulse=pulse;mod.exports.stop=stop
end
