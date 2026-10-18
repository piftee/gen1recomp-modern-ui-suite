function love.conf(t)
  t.identity='bag-icon-builder-agent'
  t.window=false
  for _,name in ipairs({'audio','sound','window','graphics','joystick','keyboard','mouse','touch','physics'}) do t.modules[name]=false end
end
