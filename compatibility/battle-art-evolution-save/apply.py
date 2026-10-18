"""Repair Battle Art's Gen II evolution cache ownership; no engine/save edits."""
import argparse, difflib, hashlib, json
from pathlib import Path

HELPER='''-- Evolution creates a replacement party record and carries unknown fields over.
-- Register only a record that inherited one of this session's temporary values,
-- so finish() releases it together with the original battler before saving.
function OverworldBattle.trackGen2Evolution(mon)
  if not (session and isGen2BattleState(session.battle)
      and type(mon) == "table") then return end
  for source in pairs(session.gen2Mons or {}) do
    if (mon.sprite ~= nil and mon.sprite == source.sprite)
        or (mon.picAnim ~= nil and mon.picAnim == source.picAnim) then
      session.gen2Mons[mon] = true
      return
    end
  end
end

'''
HOOK='''-- Evolved party records can inherit a transient Gen II battle image.
mod.events:on("pokemon.evolved", function(ctx)
  OverworldBattle.trackGen2Evolution(ctx and ctx.mon)
end)

'''

def apply(target,receipt):
 manifest=json.loads((target/'manifest.json').read_text())
 assert manifest.get('id')=='BATTLE_ART_VOXEL_GEN2','Wrong mod target'
 assert manifest.get('version') in ('2.1.0','2.1.3'),'Only Battle Art 2.1.0 and 2.1.3 have been checked'
 assert not receipt.exists(),'Use a fresh receipt directory to preserve previous backups'
 result=[]
 planned=[]
 for name,anchor,insertion in [('lib/OverworldBattle.lua','function OverworldBattle.finish()',HELPER),('main.lua','mod.events:on("battle.ended", function()',HOOK)]:
  p=target/name;before=p.read_bytes()
  # Preserve this mod's mixed existing line endings and all unrelated edits.
  s=before.decode();nl='\r\n' if '\r\n' in s else '\n'
  if 'trackGen2Evolution' not in s:
   assert s.count(anchor)==1,(name,'missing/ambiguous anchor')
   s=s.replace(anchor,insertion.replace('\n',nl)+anchor,1)
  after=s.encode();assert p.read_bytes()==before,'Concurrent edit'
  planned.append((name,p,before,after,s))
 # Validate both files before writing either one.
 receipt.mkdir(parents=True)
 for name,p,before,after,s in planned:
  assert p.read_bytes()==before,'Concurrent edit'
  (receipt/(Path(name).name+'.before')).write_bytes(before)
  (receipt/(Path(name).name+'.patch')).write_text(''.join(difflib.unified_diff(before.decode().replace('\r\n','\n').splitlines(True),s.replace('\r\n','\n').splitlines(True),fromfile='a/'+name,tofile='b/'+name,n=0)))
  p.write_bytes(after)
  result.append({'path':str(p),'before':hashlib.sha256(before).hexdigest(),'after':hashlib.sha256(after).hexdigest()})
 (receipt/'installation.json').write_text(json.dumps(result,indent=2)+'\n')
 print('Patched evolution image ownership:',target)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('target',type=Path);p.add_argument('--receipt',type=Path,required=True);a=p.parse_args();apply(a.target.resolve(),a.receipt.resolve())
