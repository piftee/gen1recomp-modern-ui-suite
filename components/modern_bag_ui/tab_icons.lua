-- Original category glyphs: 12px family with a native 15x9 key tab icon.
-- Key is deliberately redrawn with one-pixel contours and a centred round bow.
-- O = dark contour/detail; F = light fill; H = highlight; S = shadow.
-- Filled pixel cells avoid half-pixel lines, antialiasing and inherited line width.
-- Palette ink 4 stays distinct from both the selected ink-3 and idle ink-1 tabs.
return function()
  local masks = {
    all = {
      '....OOOO....','...OH..HO...','..OOFFFFOO..','.OFFFFFFFFO.',
      '.OFHHFFFSSO.','.OFHFFFFSSO.','OOFOOOOOOFOO','OFOHFFFFSOFO',
      'OFOFFFFSSOFO','OOOFFFFSSOOO','.OOSSSSSSOO.','..OOOOOOOO..',
    },
    items = {
      '...OO..OO...','...OHOOHO...','....OOOO....','...OFFFFO...',
      '..OHFFFFSO..','.OHFFFFFSSO.','OHHFFFFFFSSO','OHFFFFFFFSSO',
      'OFFFHHFFFSSO','.OFFHFFFSSO.','..OSSSSSSO..','...OOOOOO...',
    },
    medicine = {
      '....OOOO....','...OHFFSO...','...OOOOOO...','....OHFO....',
      '...OFFFFO...','..OHFFFFSO..','..OFFOOFSO..','..OFOOOOSO..',
      '..OFFOOFSO..','..OFFFFSSO..','..OSSSSSSO..','...OOOOOO...',
    },
    balls = {
      '...OOOOOO...','..OHHFFFFO..','.OHHFFFFSSO.','.OHFFFFSSSO.',
      'OFFFFOOFSSSO','OOOOOHHOOOOO','OOOOOHHOOOOO','OHHHHOOHHHHO',
      '.OHHHHHHHHO.','.OSHHHHHSSO.','..OSSSSSSO..','...OOOOOO...',
    },
    machines = {
      '...OOOOOO...','..OHFFFFFO..','.OHHFFFFSSO.','.OHFFFFSSSO.',
      'OHFFOOOOFSSO','OFFFO..OFSSO','OFFFO..OFSSO','OFSFOOOOSSSO',
      '.OFSSSSSSSO.','.OSSSSSSSSO.','..OSSSSSSO..','...OOOOOO...',
    },
    key = {
      '...OOO.........',
      '..OHHFO........',
      '.OH...SO.......',
      'OH.....SOOOOOOO',
      'OF.....FFFFFFSO',
      'OS.....SOOFOFOO',
      '.OS...SO..O.O..',
      '..OSSSO...O.O..',
      '...OOO.........',
    },
    berries = {
      '......OO....','...OOOHFO...','..OHFFOOO...','...OOOFO....',
      '..OOFFOFOO..','.OHFFFOFFSO.','OHFFFFOFFSSO','OFFFFSOFSSSO',
      'OFFFSSOFSSSO','.OSSSOOOSSO.','..OOO...OO..','............',
    },
  }
  local gray = {O={0,0,0,1}, F={170/255,170/255,170/255,1},
    H={1,1,1,1}, S={85/255,85/255,85/255,1}}
  local bounds={}
  for key,mask in pairs(masks)do
    local x0,y0,x1,y1=12,12,-1,-1
    for row,line in ipairs(mask)do for col=1,#line do
      if line:sub(col,col)~='.'then
        x0,y0=math.min(x0,col-1),math.min(y0,row-1)
        x1,y1=math.max(x1,col-1),math.max(y1,row-1)
      end
    end end
    bounds[key]={x=x0,y=y0,w=x1-x0+1,h=y1-y0+1}
  end
  local api = {size=12,masks=masks,shades=gray,bounds=bounds}
  -- Centre opaque artwork, not transparent padding. A one-pixel margin
  -- difference is unavoidable when the interior and artwork have odd parity.
  function api.position(key,x,y,w,h)
    local b=bounds[key] or {x=0,y=0,w=12,h=12}
    return math.floor(x+(w-b.w)/2)-b.x,math.floor(y+(h-b.h)/2)-b.y
  end
  function api.draw(key,x,y,colors)
    local mask=masks[key]
    if not mask then return false end
    x,y=math.floor(x),math.floor(y)
    colors=colors or gray
    love.graphics.push('all')
    for row,line in ipairs(mask)do
      for col=1,#line do
        local color=colors[line:sub(col,col)]
        if color then
          love.graphics.setColor(unpack(color))
          love.graphics.rectangle('fill',x+col-1,y+row-1,1,1)
        end
      end
    end
    love.graphics.pop()
    return true
  end
  return api
end
