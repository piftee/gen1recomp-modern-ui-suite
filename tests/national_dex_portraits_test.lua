package.path = './?.lua;./?/init.lua;' .. package.path
local T = require('tests.modkit')
package.loaded['src.core.GameVersion'] = {generation=function() return 1 end}
local source, enabled, result, calls, received = 'battle_art', true, nil, 0, nil
local provider = {exports={}}
local game = {mods={modOptions={['g9-battle-sprites']={}}}, data={pokemon={}}}
local options = game.mods.modOptions['g9-battle-sprites']
local hook = function(name, vanilla, image, ctx)
  calls, received = calls + 1, ctx
  T.eq(name, 'battle.mon_pic', 'uses generated-image hook')
  T.eq(vanilla(image), nil, 'missing provider retains native fallback')
  return result
end
package.loaded['src.mods.Runtime'] = {call=function(...) return hook(...) end}
local resolver = dofile('mods/modern_ui_suite/core/battle_portraits.lua')({
  options={get=function() return source end},
  find=function(id) return enabled and id == 'g9-battle-sprites' and provider or nil end,
})
local first = {typeOf=function(_,kind) return kind == 'Image' end}
local second = {typeOf=first.typeOf}
local mon = {species='VIGOROTH', shiny=true, gender='female'}
result = first
T.eq(resolver(game,mon,true,'dex'), first, 'installed G9 front portrait is returned')
T.same(received, {species='VIGOROTH',mon={species='VIGOROTH'},side='front',kind='dex'},
  'entry requests default species art with no battle-only sizing')
T.check(received.mon ~= mon and mon.shiny, 'live mon is neither passed nor modified')
result = second
T.eq(resolver(game,'VIGOROTH',true,'dex'), second, 'new animation frames are not cached away')
result = false
local image,pending = resolver(game,'VIGOROTH',true,'dex')
T.eq(image,nil,'pending is not mistaken for an image'); T.eq(pending,true,'pending suppresses fallback')
result = first
T.eq(resolver(game,'VIGOROTH',true,'dex'),first,'pending request is retried')
result = nil
image,pending = resolver(game,'MISSING',true,'dex')
T.eq(image,nil,'uninstalled artwork falls back');T.eq(pending,false,'missing file is not pending')
result = 'not an image'
T.eq(resolver(game,'BAD',true,'dex'),nil,'malformed hook results are safe')
result = {typeOf=function() return false end}
T.eq(resolver(game,'BAD',true,'dex'),nil,'non-image objects are rejected')
result = first
local count = calls
enabled = false
T.eq(resolver(game,mon,true,'dex'),nil,'disabled mod is not used')
enabled = true; options.dex_sprites = false
T.eq(resolver(game,mon,true,'dex'),nil,'DEX SPRITES off is respected')
options.dex_sprites = nil;options.enable_battle_sprites = false
T.eq(resolver(game,mon,true,'dex'),nil,'provider master switch is respected')
options.enable_battle_sprites = nil
T.eq(resolver(game,mon),nil,'other menus keep their existing provider contract')
T.eq(resolver(game,{species='VIGOROTH',isEgg=true},true,'dex'),nil,'eggs remain hidden')
T.eq(resolver(game,{},true,'dex'),nil,'empty species is safe')
T.eq(resolver(game,'UNOWN',true,'dex'),nil,'Unown retains its native letter renderer')
source = 'crystal'
T.eq(resolver(game,mon,true,'dex'),nil,'explicit Crystal selection keeps priority')
source = 'hgss'
T.eq(resolver(game,mon,true,'dex'),nil,'retired HGSS selection keeps fallback')
T.eq(calls,count,'excluded cases never query the provider')
source = 'default'
T.eq(resolver(game,mon,true,'dex'),first,'Default honours the native Dex provider')
source = 'battle_art'
options.dex_sprites = false
T.eq(resolver(game,mon,true,'summary'),first,'summary works with Dex sprites off')
T.eq(received.kind,'summary','summary context is explicit')
T.eq(received.mon.shiny,true,'summary preserves shiny variant')
T.eq(received.mon.gender,'female','summary preserves female variant')
T.check(received.mon ~= mon,'provider receives a presentation copy')
received.mon.__providerDebug = true
T.eq(mon.__providerDebug,nil,'provider diagnostic writes cannot mutate saved mon')
options.summary_sprites = false
T.eq(resolver(game,mon,true,'summary'),nil,'summary sprites off keeps native art')
options.summary_sprites = nil
provider.exports.drawSummaryFrame = function() end
T.eq(resolver(game,mon,true,'summary'),nil,'new G9 uses its shadow-free summary painter')
provider.exports.drawSummaryFrame = nil
result = false
image,pending = resolver(game,mon,true,'summary')
T.eq(image,nil,'pending summary has no image');T.eq(pending,true,'pending summary suppresses placeholder')
options.dex_sprites = nil
hook = function() error('provider unavailable') end
T.eq(resolver(game,mon,true,'dex'),nil,'provider failure cannot crash the Dex')
T.finish('suite_national_dex_portraits')
