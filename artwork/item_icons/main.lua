-- Deterministic atlas compiler. No window, audio or graphics device is created.
local root=assert(os.getenv('BAG_ICON_BUILD_ROOT'))
local specs=dofile(root..'/recipes.lua')
local C={ink={.12,.16,.22,1},white={1,.97,.84,1},gold={.95,.67,.20,1},green={.28,.68,.39,1},brown={.55,.34,.23,1},red={.91,.31,.38,1},blue={.26,.60,.83,1}}
local function hsv(h,s,v)
 h=(h or 180)%360/60;local i=math.floor(h);local f=h-i
 local p,q,t=v*(1-s),v*(1-s*f),v*(1-s*(1-f))
 return ({ {v,t,p,1},{q,v,p,1},{p,v,t,1},{p,q,v,1},{t,p,v,1},{v,p,q,1} })[i+1]
end
local function pixel(im,x,y,c)
 x,y=math.floor(x),math.floor(y);if x>=0 and y>=0 and x<im:getWidth() and y<im:getHeight() then im:setPixel(x,y,unpack(c)) end
end
local function rect(im,x,y,w,h,c) for yy=y,y+h-1 do for xx=x,x+w-1 do pixel(im,xx,yy,c) end end end
local function line(im,x0,y0,x1,y1,c)
 local n=math.max(math.abs(x1-x0),math.abs(y1-y0));if n==0 then pixel(im,x0,y0,c);return end
 for i=0,n do pixel(im,math.floor(x0+(x1-x0)*i/n+.5),math.floor(y0+(y1-y0)*i/n+.5),c) end
end
local function oval(im,x,y,rx,ry,c)
 for yy=math.floor(y-ry),math.ceil(y+ry) do for xx=math.floor(x-rx),math.ceil(x+rx) do
  if ((xx-x)/rx)^2+((yy-y)/ry)^2<=1 then pixel(im,xx,yy,c) end
 end end
end
local function poly(im,points,c)
 for y=0,23 do for x=0,23 do local inside=false;local j=#points
  for i=1,#points do local a,b=points[i],points[j]
   if (a[2]>y)~=(b[2]>y) and x<(b[1]-a[1])*(y-a[2])/(b[2]-a[2])+a[1] then inside=not inside end;j=i
  end
  if inside then pixel(im,x,y,c) end
 end end
end
local glyph={['_']='000000000000111',[' ']='000000000000000',
 ['0']='111101101101111',['1']='010110010010111',['2']='111001111100111',['3']='111001111001111',['4']='101101111001001',['5']='111100111001111',['6']='111100111101111',['7']='111001010010010',['8']='111101111101111',['9']='111101111001111',
 A='010101111101101',B='110101110101110',C='011100100100011',D='110101101101110',E='111100110100111',F='111100110100100',G='011100101101011',H='101101111101101',I='111010010010111',J='001001001101010',K='101101110101101',L='100100100100111',M='101111111101101',N='101111111111101',O='010101101101010',P='110101110100100',Q='010101101011001',R='110101110101101',S='011100010001110',T='111010010010010',U='101101101101111',V='101101101101010',W='101101111111101',X='101101010101101',Y='101101010010010',Z='111001010100111',['+']='000010111010000',['?']='110001010000010'}
local function text(im,s,x,y,c,scale)
 scale=scale or 1
 for n=1,#s do local g=glyph[s:sub(n,n)] or glyph['?'];for i=1,15 do if g:sub(i,i)=='1' then rect(im,x+((n-1)*4+(i-1)%3)*scale,y+math.floor((i-1)/3)*scale,scale,scale,c) end end end
end
local function badge(im,s,col)
 local w=#s*4+1;rect(im,23-w,16,w,8,C.ink);rect(im,24-w,17,w-2,6,col or C.blue);text(im,s,24-w,17,C.white)
end
local symbols={
 dot={'0000000','0001000','0011100','0011100','0001000'},bars={'0110110','0110110','0110110','0110110','0110110'},u={'1100011','1100011','1100011','0111110'},star={'0001000','0001000','1111111','0111110','0011100','0110110','1100011'},
 leaf={'0000110','0001110','0011110','0111100','0111000','1100000'},weight={'0011100','0010100','0111110','1111111','1111111'},up={'0001000','0011100','0111110','0001000','0001000'},hook={'0001000','0001000','0001000','1001000','1111000'},bolt={'0001100','0011000','0111110','0001100','0011000','0110000'},hand={'0011000','1111100','1111110','0111110','0011100'},moon={'0011110','0111000','1110000','1110000','0111000','0011110'},heart={'0110110','1111111','1111111','0111110','0011100','0001000'},net={'1111111','1010101','1111111','1010101','1111111'},gs={'1100111','1000100','1010110','1110001','0000111'},flame={'0001000','0011100','0011100','0111110','1111111','0111110'},drop={'0001000','0011100','0011100','0111110','0111110','0011100'},sun={'0001000','0101010','0011100','1111111','0011100','0101010','0001000'},flower={'0011100','0111110','1110111','0111110','0011100'},wave={'1100110','0110011','0000000','1100110','0110011'},snow={'1001001','0101010','0011100','1111111','0011100','0101010','1001001'},face={'1111111','1010101','1111111','1011101','1100011'},spiral={'1111111','1000001','1011101','1010101','1010001','1011111'},cloud={'0011100','0111110','1111111','1111111'},note={'0001111','0001001','0001001','0111001','1111011','0110011'}}
local function symbol(im,key,x,y,col)
 for yy,row in ipairs(assert(symbols[key],key)) do for xx=1,#row do if row:sub(xx,xx)=='1' then pixel(im,x+xx-1,y+yy-1,col) end end end
end
local function readImage(path) local f=assert(io.open(path,'rb'));local bytes=f:read('*a');f:close();return love.image.newImageData(love.filesystem.newFileData(bytes,path:match('[^/]+$'))) end
local openmon=readImage(root..'/sources/openmon.png')
local generated={}
for _,name in ipairs({'balls','lure','map','teeth','disc'}) do generated[name]=readImage(root..'/sources/'..name..'-imagegen.png') end
-- The generated sheet has clean gutters but not exact equal cell spacing.
-- Detect occupied row/column bands to avoid importing a neighboring ball edge.
local function bands(counts)
 local out,start,last={},nil,nil
 for i,n in ipairs(counts)do
  if n>6 then
   if last and i-last>6 then out[#out+1]={start-1,last-1};start=nil end
   start=start or i;last=i
  end
 end
 if start then out[#out+1]={start-1,last-1}end
 return out
end
local balls=generated.balls;local rows={}
for y=0,balls:getHeight()-1 do local n=0;for x=0,balls:getWidth()-1 do local _,_,_,a=balls:getPixel(x,y);if a>.5 then n=n+1 end end;rows[y+1]=n end
local ballCrops={}
for _,row in ipairs(bands(rows))do
 local columns={}
 for x=0,balls:getWidth()-1 do local n=0;for y=row[1],row[2]do local _,_,_,a=balls:getPixel(x,y);if a>.5 then n=n+1 end end;columns[x+1]=n end
 for _,column in ipairs(bands(columns))do ballCrops[#ballCrops+1]={column[1],row[1],column[2]-column[1]+1,row[2]-row[1]+1}end
end
assert(#ballCrops==14,'Expected fourteen isolated generated ball regions, got '..#ballCrops)
local function sample(src,x,y,w,h,im,hue,saturation,square)
 local x0,y0,x1,y1=x+w,y+h,x,y
 for yy=y,y+h-1 do for xx=x,x+w-1 do local _,_,_,a=src:getPixel(xx,yy);if a>.5 then x0=math.min(x0,xx);y0=math.min(y0,yy);x1=math.max(x1,xx);y1=math.max(y1,yy) end end end
 local bw,bh=x1-x0+1,y1-y0+1;local scale=math.min(22/bw,22/bh)
 local dw,dh=math.max(1,math.floor(bw*scale+.5)),math.max(1,math.floor(bh*scale+.5));if square then dw,dh=22,22 end;local dx,dy=math.floor((24-dw)/2),math.floor((24-dh)/2)
 for yy=0,dh-1 do for xx=0,dw-1 do
  local r,g,b,a=src:getPixel(math.min(x1,x0+math.floor((xx+.5)*bw/dw)),math.min(y1,y0+math.floor((yy+.5)*bh/dh)))
  if a>.5 then
   if hue then local max,min=math.max(r,g,b),math.min(r,g,b);local sat=max>0 and (max-min)/max or 0
    if sat>.18 and max>.2 then local c=hsv(hue,saturation or sat,max);r,g,b=c[1],c[2],c[3] end
   end
   pixel(im,dx+xx,dy+yy,{math.floor(r*31+.5)/31,math.floor(g*31+.5)/31,math.floor(b*31+.5)/31,1})
  end
 end end
end
local function make(s)
 local im=love.image.newImageData(24,24);local mid=hsv(s.hue or 185,.65,.83);local dark=hsv(s.hue or 185,.65,.48);local light=hsv(s.hue or 185,.30,1)
 local k=s.kind
 if k=='openmon' then local n=s.cell-1;sample(openmon,n%10*32,math.floor(n/10)*32,32,32,im,s.hue)
 elseif k=='generated' then local src=generated[s.source]
  if s.source=='balls' then local c=ballCrops[s.cell];sample(src,c[1],c[2],c[3],c[4],im,nil,nil,true)
  else sample(src,0,0,src:getWidth(),src:getHeight(),im,s.hue,s.saturation,s.ball)end
 elseif k=='gem' then
  poly(im,{{6,2},{17,2},{23,10},{16,22},{7,22},{1,12}},C.ink);poly(im,{{7,4},{16,4},{20,10},{15,20},{8,20},{3,12}},mid);poly(im,{{7,4},{12,4},{8,12},{3,12}},light);poly(im,{{15,6},{20,10},{15,20},{11,17}},dark)
 elseif k=='apricorn' then
  if s.badge=='W' then mid={.84,.87,.89,1};dark={.45,.52,.58,1};light=C.white elseif s.badge=='K' then mid={.28,.31,.4,1};dark=C.ink;light={.53,.56,.66,1} end
  oval(im,12,13,9,9,C.ink);oval(im,12,13,7,7,mid);oval(im,14,15,4,5,dark);rect(im,7,8,3,4,light);line(im,11,4,13,1,C.brown);poly(im,{{12,3},{20,1},{17,6},{12,5}},C.green)
 elseif k=='card' or k=='mail' then
  rect(im,2,5,20,14,C.ink);rect(im,3,6,18,12,C.white);rect(im,3,6,18,3,mid);rect(im,17,10,3,3,mid)
  if k=='mail' then line(im,3,8,12,15,dark);line(im,20,8,12,15,dark) else rect(im,5,11,6,2,dark);rect(im,5,15,9,1,dark) end
 elseif k=='device' then
  rect(im,4,3,16,19,C.ink);rect(im,5,4,14,17,mid);rect(im,7,6,10,8,C.ink);rect(im,8,7,8,6,{.64,.85,.65,1});line(im,9,12,14,8,C.green);rect(im,7,17,3,2,C.white);rect(im,14,17,3,2,dark);rect(im,16,1,2,3,C.ink)
 elseif k=='spray' then
  rect(im,8,2,10,4,C.ink);rect(im,6,3,5,2,dark);rect(im,10,5,4,3,C.ink);rect(im,5,8,14,14,C.ink);rect(im,6,9,12,12,mid);rect(im,7,10,2,9,light);rect(im,10,12,6,6,C.white)
 elseif k=='spoon' then
  line(im,8,9,12,15,C.ink);line(im,12,15,17,15,C.ink);line(im,17,15,19,21,C.ink)
  line(im,9,9,13,14,C.white);line(im,13,14,18,14,C.white);line(im,18,14,20,21,C.white)
  oval(im,7,6,4,5,C.ink);oval(im,7,6,3,4,{.63,.74,.83,1});oval(im,6,5,2,3,C.white)
 elseif k=='stick' then
  line(im,5,21,16,3,C.ink);line(im,6,21,17,3,C.ink);line(im,6,20,16,4,C.brown)
  line(im,10,14,5,8,C.ink);line(im,11,14,6,8,C.brown);line(im,13,10,20,7,C.ink);line(im,13,9,19,7,C.brown)
  poly(im,{{16,4},{20,1},{21,4},{17,7}},C.green)
 elseif k=='rope' then
  for rx=8,4,-2 do oval(im,11,12,rx,7,C.ink);oval(im,11,12,rx-1,6,C.gold) end
  line(im,16,16,21,20,C.ink);line(im,16,17,20,20,C.gold);rect(im,19,19,3,3,C.brown)
 elseif k=='surfboard' then
  oval(im,12,12,5,11,C.ink);oval(im,12,12,4,10,C.blue);rect(im,11,3,2,18,C.white);line(im,8,17,16,9,C.red)
 elseif k=='helix' or k=='dome' then
  oval(im,12,12,10,9,C.ink);oval(im,12,12,9,8,{.68,.55,.36,1});oval(im,12,12,7,6,{.89,.77,.53,1})
  if k=='helix' then local prev;for a=0,math.pi*5,.15 do local rad=7-a*.4;local p={12+math.cos(a)*rad,12+math.sin(a)*rad};if prev then line(im,prev[1],prev[2],p[1],p[2],C.brown) end;prev=p end
  else line(im,5,15,18,15,C.brown);for i=0,4 do line(im,12,7,5+i*3,15,C.brown) end end
 elseif k=='amber' then
  poly(im,{{8,2},{18,5},{22,15},{15,22},{3,18},{2,7}},C.ink);poly(im,{{8,4},{17,6},{20,15},{15,20},{5,17},{4,8}},C.gold);oval(im,12,12,2,5,C.brown);line(im,7,8,17,15,C.brown);line(im,7,15,17,8,C.brown);rect(im,6,6,2,4,C.white)
 elseif k=='nugget' then
  poly(im,{{4,9},{15,4},{21,8},{21,17},{8,21},{2,17}},C.ink);poly(im,{{5,10},{15,6},{19,9},{19,16},{8,19},{4,16}},C.gold);line(im,6,10,15,7,C.white);line(im,7,12,18,9,C.brown)
 elseif k=='coin' or k=='amulet' then
  if k=='amulet' then oval(im,12,8,8,6,C.ink);oval(im,12,8,6,4,C.white) end
  oval(im,12,14,7,7,C.ink);oval(im,12,14,6,6,C.gold);oval(im,12,14,4,4,C.brown);oval(im,12,14,3,3,C.gold);line(im,12,12,12,16,C.white)
 elseif k=='coin_case' then
  rect(im,3,7,18,14,C.ink);rect(im,4,8,16,12,C.brown);rect(im,4,9,16,2,C.gold);rect(im,10,9,4,4,C.ink);rect(im,11,10,2,2,C.white);oval(im,13,5,5,4,C.ink);oval(im,13,5,4,3,C.gold)
 elseif k=='toy' then
  mid=s.hue and mid or { .83,.57,.34,1};dark=s.hue and dark or C.brown
  oval(im,7,5,3,3,C.ink);oval(im,17,5,3,3,C.ink);oval(im,7,5,2,2,mid);oval(im,17,5,2,2,mid);oval(im,12,15,7,7,C.ink);oval(im,12,15,6,6,mid);oval(im,12,9,7,6,C.ink);oval(im,12,9,6,5,mid);rect(im,8,8,2,2,C.ink);rect(im,14,8,2,2,C.ink);oval(im,12,12,3,2,C.white);pixel(im,12,11,C.ink);oval(im,6,20,3,2,dark);oval(im,18,20,3,2,dark)
 elseif k=='flute' then
  line(im,4,19,19,4,C.ink);line(im,5,20,20,5,C.ink);line(im,4,20,20,4,C.gold);line(im,5,20,20,5,C.gold);for i=7,17,3 do pixel(im,i,24-i,C.ink) end;rect(im,18,3,3,3,C.brown)
 elseif k=='tail' then
  poly(im,{{3,17},{6,20},{12,20},{20,10},{19,5},{15,6},{9,15}},C.ink);poly(im,{{5,17},{7,18},{11,18},{18,10},{17,7},{11,16}},C.red);rect(im,15,7,3,3,C.white)
 elseif k=='bow' then
  poly(im,{{3,5},{11,9},{21,5},{21,19},{12,15},{3,19}},C.ink);poly(im,{{4,7},{11,11},{20,7},{20,17},{12,13},{4,17}},mid);rect(im,10,10,4,5,dark);rect(im,11,10,2,2,light)
  if s.dots then for _,p in ipairs({{6,10},{6,15},{17,10},{17,15}}) do rect(im,p[1],p[2],2,2,C.white) end end
 elseif k=='star' then
  poly(im,{{12,1},{15,8},{23,9},{17,14},{19,22},{12,18},{5,22},{7,14},{1,9},{9,8}},C.ink);poly(im,{{12,4},{14,10},{20,10},{15,14},{17,19},{12,16},{7,19},{9,13},{4,10},{10,10}},C.red);line(im,12,5,10,11,C.white)
 elseif k=='stardust' then
  rect(im,8,2,8,3,C.ink);rect(im,9,3,6,2,C.brown);rect(im,5,6,14,16,C.ink);rect(im,6,7,12,14,{.48,.69,.76,1});poly(im,{{7,17},{9,12},{12,17},{15,11},{17,17},{17,20},{7,20}},C.gold);rect(im,7,8,2,6,C.white)
 else error('No drawing for '..k) end
 if s.emblem then symbol(im,s.emblem,9,8,C.white) end
 if s.badge and k~='machine' then badge(im,s.badge,dark) end
 return im
end
local function save(im,path) local f=assert(io.open(path,'wb'));f:write(im:encode('png'):getString());f:close() end
local function serial(v)
 if type(v)=='number' then return tostring(v) end
 local out={};for _,x in ipairs(v) do out[#out+1]=serial(x) end;return '{'..table.concat(out,',')..'}'
end
local function spans(im)
 local out={};for y=0,im:getHeight()-1 do local start
  for x=0,im:getWidth() do local a=0;if x<im:getWidth() then local _,_,_,alpha=im:getPixel(x,y);a=alpha end
   if a>0 and not start then start=x elseif a==0 and start then out[#out+1]={start,y,x-start};start=nil end
  end
 end;return out
end
function love.run()
 assert(not love.window and not love.audio and not love.graphics,'Builder must be silent and windowless')
 local atlas=love.image.newImageData(16*24,math.ceil(#specs/16)*24);local mini=love.image.newImageData(16*12,math.ceil(#specs/16)*12)
 local allSpans,miniSpans={},{}
 local unique={}
 local balls=love.image.newImageData(5*160,3*104);balls:mapPixel(function()return .91,.94,.97,1 end)
 local ballCount=0
 local sheet=love.image.newImageData(8*150,math.ceil(#specs/8)*76)
 sheet:mapPixel(function()return .91,.94,.97,1 end)
 for i,s in ipairs(specs) do
  local im=make(s)
  local digest=love.data.encode('string','hex',love.data.hash('sha256',im:getString()))
  assert(not unique[digest], 'Duplicate art: '..s.id..' and '..tostring(unique[digest]))
  unique[digest]=s.id
  assert(#spans(im)>0,'Empty frame '..s.id)
  local sx,sy=(i-1)%8*150,math.floor((i-1)/8)*76
  for y=0,23 do for x=0,23 do local r,g,b,a=im:getPixel(x,y);if a>0 then rect(sheet,sx+51+x*2,sy+4+y*2,2,2,{r,g,b,a})end end end
  text(sheet,s.id,sx+math.floor((150-#s.id*4)/2),sy+59,C.ink)
  if s.kind=='generated' and s.ball then
   local bx,by=ballCount%5*160,math.floor(ballCount/5)*104;ballCount=ballCount+1
   for y=0,23 do for x=0,23 do local r,g,b,a=im:getPixel(x,y);assert(a==0 or a==1,'partial alpha');if a>0 then
    assert(x>0 and x<23 and y>0 and y<23,'ball crop touches cell edge')
    rect(balls,bx+44+x*3,by+3+y*3,3,3,{r,g,b,a});pixel(balls,bx+9+x,by+21+y,{r,g,b,a})
   end end end
   for y=0,11 do for x=0,11 do local r,g,b,a=im:getPixel(x*2+1,y*2+1);if a>0 then pixel(balls,bx+15+x,by+54+y,{r,g,b,a})end end end
   text(balls,s.id,bx+math.floor((160-#s.id*8)/2),by+86,C.ink,2)
  end
  atlas:paste(im,(i-1)%16*24,math.floor((i-1)/16)*24,0,0,24,24);allSpans[i]=spans(im)
  local small=love.image.newImageData(12,12)
  for y=0,11 do for x=0,11 do small:setPixel(x,y,im:getPixel(x*2+1,y*2+1)) end end
  mini:paste(small,(i-1)%16*12,math.floor((i-1)/16)*12,0,0,12,12);miniSpans[i]=spans(small)
 end
 assert(ballCount==14,'13 catching balls plus GS Ball')
 save(balls,root..'/ball-preview.png')
 save(sheet,root..'/contact-sheet.png')
 save(atlas,root..'/payload/assets/item_icons/items-24.png');save(mini,root..'/payload/assets/item_icons/items-12.png')
 local f=assert(io.open(root..'/payload/item_icon_spans.lua','w'));f:write('-- Opaque row spans preserve palette-coloured backgrounds around each icon.\nreturn {[24]=',serial(allSpans),',[12]=',serial(miniSpans),'}\n');f:close()
 local cropsFile=assert(io.open(root..'/sources/ball-crops.lua','w'));cropsFile:write('return ',serial(ballCrops),'\n');cropsFile:close()
 print('[ICON BUILD] '..#specs..' nonempty, byte-distinct frames; audio/window/graphics disabled')
 return function() return 0 end
end
