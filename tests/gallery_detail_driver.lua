return function(game)
 local U=dofile(assert(os.getenv('PC_REPO'))..'/tests/drivers/util.lua')
 local Mon=require('src.battle.gen2.Mon')
 local Screens=require('src.ui.Screens')
 local Boxes=require('src.core.gen2.Boxes')
 while game.stack:top() do game.stack:pop() end
 game.save.party={}
 for _,id in ipairs({'QUILAVA','WOOPER','PIKACHU','TOGEPI','SPEAROW'}) do
  game.save.party[#game.save.party+1]=Mon.new(game.data,id,32)
  game.save.pokedex.seen[id]=true;game.save.pokedex.caught[id]=true
 end
 local box=Boxes.box(game.save,1)
 for i,id in ipairs({'WARTORTLE','BULBASAUR','EEVEE','ELEKID','MEOWTH'}) do
  box[i]=Mon.new(game.data,id,28)
  game.save.pokedex.seen[id]=true;game.save.pokedex.caught[id]=true
 end
 love.window.setMode(1280,720,{resizable=true})
 Screens.push(game,'Gen2BoxMenu',{save=game.save});U.wait(3)
 assert(U.shot(game,os.getenv('SHOT_DIR')..'/pc.png'))
 while game.stack:top() do game.stack:pop() end
 game.save.pokedex.seen.PIDGEY=true;game.save.pokedex.caught.PIDGEY=true
 local dex=Screens.push(game,'Gen2PokedexMenu',{save=game.save})
 for i,row in ipairs(dex.rows) do if row.species=='PIDGEY' then dex.index=i;break end end
 dex:ensureVisible();assert(dex:current().seen,'gallery uses a seen entry');U.wait(3)
 assert(U.shot(game,os.getenv('SHOT_DIR')..'/pokedex.png'))
 dex.view='entry';U.wait(3)
 assert(U.shot(game,os.getenv('SHOT_DIR')..'/pokedex-entry.png'))
 assert(not love.window.hasFocus() and love.audio.getVolume()==0)
 print('[DISCORD QA] PASS populated gallery captures');love.event.quit(0)
end
