-- Run with artifacts/ui-aspect-ratio/run_native.py: silent, isolated profiles.
return function(game)
  local U=dofile(assert(os.getenv("PC_REPO")).."/tests/drivers/util.lua")
  local S=require("src.ui.Screens")
  local R=require("src.mods.Runtime")
  local gen2=require("src.core.GameVersion").generation()==2
  local Mon=require(gen2 and "src.battle.gen2.Mon" or "src.pokemon.Pokemon")
  local Boxes=require(gen2 and "src.core.gen2.Boxes" or "src.pokemon.Boxes")
  local opts=game.mods.modOptions.modern_ui_suite
  local count=gen2 and Boxes.NUM_BOXES or Boxes.COUNT
  local checks=0
  local function check(ok,label)assert(ok,label);checks=checks+1 end
  local function press(screen,key)
    local input=game.input
    game.input=setmetatable({wasPressed=function(_,k)return k==key end,isDown=function()return false end},{__index=input})
    local ok,err=pcall(screen.update,screen,0);game.input=input;assert(ok,err)
  end
  while game.stack:top()do game.stack:pop()end
  game.writeSave=function()return true end -- private navigation fixture has no overworld
  game.save.party={}
  local species={"RATTATA","PIDGEY","SQUIRTLE","CHARMANDER","BULBASAUR","PIKACHU"}
  for i,id in ipairs(species)do game.save.party[i]=Mon.new(game.data,id,12+i)end
  game.save.currentBox=1;game.save.boxes={}
  if gen2 then for i=1,count do Boxes.box(game.save,i)end
  else for i=1,count do game.save.boxes[i]={} end;Boxes.ensure(game.save)end
  for b=1,2 do
    local box=gen2 and Boxes.box(game.save,b) or game.save.boxes[b]
    for i=1,20 do box[i]=Mon.new(game.data,species[(i-1)%6+1],5+i)end
  end
  local pc=S.push(game,gen2 and "Gen2BoxMenu" or "BoxMenu",gen2 and {save=game.save,mode="move"} or nil)
  check(pc.modernPCUI,"suite storage opens")
  if pc.modernPCPicRenderer then
    pc.modernPCPicRenderer.picFor=function()error("storage must not draw a large portrait")end
  end
  local originalParty=game.save.party
  for _,case in ipairs({
    {"native",640,576,"fill"},{"narrow",720,576,"fill"},
    {"below-breakpoint",764,576,"fill"},{"four-three",768,576,"4:3"},
    {"wide",1280,720,"16:9"},{"ultrawide",1728,720,"fill"},
    {"portrait",480,900,"fill"},
  })do
    opts["pc.aspect_ratio"]=case[4];opts["pc.box_exclusive"]=false
    love.window.setMode(case[2],case[3],{resizable=true,vsync=0})
    U.wait(4)
    local l=pc:modernPCLayoutInfo()
    check(l.party.cols==6 and l.party.rows==1,case[1].." party stays in one row")
    check(l.box.cols==5 and l.box.rows==4,case[1].." box keeps twenty slots")
    check(l.party.y>=l.box.y+l.box.h,case[1].." party stays below box")
    check(l.party.y+l.party.h<=l.footerY,case[1].." party clears footer")
    check((l.party.w-4)/6>=20,case[1].." party icons fit")
    check(not l.compact,case[1].." never uses old side-panel navigation")
    pc.region,pc.boxIndex,pc.boxSwitching,pc.boxPicker="box",1,false,false
    game.save.currentBox=1
    press(pc,"left");check(game.save.currentBox==count,case[1].." left edge wraps to last box")
    pc.boxIndex=5;press(pc,"right");check(game.save.currentBox==1,case[1].." right edge wraps to first box")
    pc.boxIndex=20;press(pc,"down");check(pc.region=="party",case[1].." down enters party")
    press(pc,"up");check(pc.region=="box" and pc.boxIndex>15,case[1].." up returns to bottom box row")
    pc.boxIndex=1;press(pc,"up");check(pc.boxSwitching,case[1].." up enters box header")
    press(pc,"right");check(game.save.currentBox==2,case[1].." header right changes box")
    press(pc,"left");check(game.save.currentBox==1,case[1].." header left changes box")
    press(pc,"b");check(not pc.boxSwitching,case[1].." B returns to grid")
    -- Holding a Pokémon across a resize and box switch must preserve its source.
    pc.boxIndex=1;press(pc,"a");local held=pc.held
    check(held and held.mon,case[1].." can pick up a Pokemon")
    press(pc,"select");press(pc,"right")
    check(pc.held==held and held.sourceList[held.sourceIndex]==held.mon,
      case[1].." box switching preserves held Pokemon")
    press(pc,"b");press(pc,"b");check(pc.held==nil,case[1].." carry cancels without moving Pokemon")
    check(#game.save.party==6 and game.save.party==originalParty,case[1].." navigation preserves party")
    opts["pc.box_exclusive"]=true;pc.region,pc.boxIndex="box",1
    local box=game.save.currentBox;press(pc,"left")
    check(pc.boxIndex==5 and game.save.currentBox==box,case[1].." exclusive option still wraps within box")
    press(pc,"select");press(pc,"right")
    check(game.save.currentBox~=box,case[1].." exclusive mode still permits header switching")
    press(pc,"b");opts["pc.box_exclusive"]=false
    pc.region,pc.boxIndex="box",1;game.save.currentBox=1;pc.status=nil
    check(U.shot(game,os.getenv("SHOT_DIR").."/pc-"..case[1]..".png"),"capture "..case[1])
    check(not love.window.hasFocus() and love.audio.getVolume()==0,"muted and unfocused")
    print("[PC ASPECT] "..case[1].." "..l.width.."x"..l.height.." passed")
  end
  opts["fullctl.enabled"]=true
  R.emit("mod.options_changed",{mod="modern_ui_suite",key="fullctl.enabled"})
  pc.region,pc.boxIndex,pc.boxSwitching,pc.boxPicker="box",1,true,false
  local box=game.save.currentBox
  game:keypressed("right");U.wait(1);game:keyreleased("right");U.wait(1)
  check(game.save.currentBox==box%count+1,"physical arrow route changes box with Full Control")
  box=game.save.currentBox
  game:gamepadpressed(nil,"dpleft");U.wait(1);game:gamepadreleased(nil,"dpleft");U.wait(1)
  check(game.save.currentBox==(box-2)%count+1,"controller D-pad route changes box with Full Control")
  print("[DISCORD QA] PASS "..checks.." PC aspect/navigation checks");love.event.quit(0)
end
