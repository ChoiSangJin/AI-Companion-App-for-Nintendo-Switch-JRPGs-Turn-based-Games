"""Import reproducible factual compendium snapshots from aqiu384's fusion tool.
Usage: python3 tools/import_megaten.py --source /path/to/megaten-fusion-tool
The user's megaten-database repo supplies upstream extracts; fusion-tool supplies
consumable tables and is released under the Unlicense. No runtime API is used.
"""
import argparse, hashlib, json, re, subprocess
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--source',type=Path,required=True)
root=parser.parse_args().source; app=root/'src/app'; used={}
def load(path):
 p=app/path; used[str(path)]=hashlib.sha256(p.read_bytes()).hexdigest();return json.loads(p.read_text())
def merge(paths):
 result={}
 for path in paths:result.update(load(path))
 return result
names=load(Path('compendium/data/demon-names.json'));races=load(Path('compendium/data/race-names.json'));skills=load(Path('compendium/data/skill-names.json'));elems=load(Path('compendium/data/elem-names.json'))
def translated(name,lookup):
 suffix=re.match(r'^(.*) ([A-HJ-Z])$',name);base=suffix[1] if suffix else name
 value=lookup.get(base,[]);v=value[2] if len(value)>2 and value[2] else base
 return v+(' '+suffix[2] if suffix else '')
def chart(raw,persona,triple=False):
 rs=raw['races'];table=raw['table'];result={r:{} for r in rs};inverted=len(table[0])==1
 for r,row in enumerate(table):
  for c,value in enumerate(row):
   col=c if inverted or len(row)==len(rs) else len(rs)-len(row)+c
   if persona and not inverted and ((triple and col>r) or (not triple and col<=r)):continue
   if value!='-': result[rs[r]][rs[col]]=value;result[rs[col]][rs[r]]=value
 return result
# Standard Korean SMT race terminology supplements gaps in upstream's locale map.
SMT_RACES_KO={'Herald':'대천사','Megami':'여신','Avian':'영조','Divine':'천사','Yoma':'요마','Vile':'사신','Raptor':'흉조','Deity':'마신','Wargod':'군신','Avatar':'신수','Holy':'성수','Genma':'환마','Element':'정령','Fairy':'요정','Beast':'마수','Jirae':'지령','Fiend':'마인','Jaki':'사귀','Wilder':'요수','Fury':'파괴신','Lady':'지모신','Dragon':'용신','Kishin':'귀신','Kunitsu':'국진신','Femme':'귀녀','Brute':'요귀','Fallen':'타천사','Night':'야마','Snake':'용왕','Tyrant':'마왕','Drake':'사룡','Haunt':'유귀','Foul':'외도','Enigma':'비신','UMA':'진수','Qadistu':'여마','Devil':'악마','Primal':'원마'}
NAME_FALLBACK_KO={'Preta':'아귀'}
configs=[
 ('p3r','Persona 3 Reload','페르소나 3 리로드','p3r',['demon-data'],'special-recipes','demon-unlocks','fusion-chart',None,None),
 ('p4g','Persona 4 Golden','페르소나 4 골든','p4',['demon-data','golden-demon-data'],'special-recipes','golden-demon-unlocks','golden-fusion-chart',None,None),
 ('p5r','Persona 5 Royal','페르소나 5 더 로열','p5',['roy-demon-data'],'roy-special-recipes','roy-demon-unlocks','roy-fusion-chart','roy-element-chart','roy-fusion-prereqs'),
 ('smt5v','Shin Megami Tensei V Vengeance','진·여신전생 V Vengeance','smt5',['demon-data','ven-demon-data'],'ven-special-recipes','ven-demon-unlocks','ven-fusion-chart','element-chart','ven-fusion-prereqs'),
]
for key,title,ko,folder,dfiles,special,unlock,normal,element,prereq in configs:
 cfg=load(Path(folder)/'data/comp-config.json');raw=merge([Path(folder)/f'data/{f}.json' for f in dfiles]);sp=load(Path(folder)/f'data/{special}.json');groups=load(Path(folder)/f'data/{unlock}.json');nc=load(Path(folder)/f'data/{normal}.json');ec=load(Path(folder)/f'data/{element}.json') if element else {'elems':[],'races':[],'table':[]};req=load(Path(folder)/f'data/{prereq}.json') if prereq else {}
 allowed=set(nc['races'])|set(ec.get('races',[]))|{'Element'}
 # The source includes guest humans, proto-fiend essences and alternate guests.
 # These are not summonable compendium demons and have no race in this chart.
 raw={n:v for n,v in raw.items() if (v['race'] in allowed or bool(sp.get(n))) and v.get('fusion')!='party'}
 dlc=[];requirements={};demon_group={};dlc_by_label={}
 for g in groups:
  for packed,condition in g['conditions'].items():
   members=[n for n in packed.split(',') if n in raw]
   if not members:continue
   if key=='p3r' and condition.startswith('Persona 4 Set'): condition='Persona 4 Set'
   if g['category'] in ['Downloadable Content','Vengeance DLC']:
    ident=condition
    if ident not in dlc_by_label:
     group={'id':ident,'label':condition,'members':[],'default':g['unlocked']};dlc.append(group);dlc_by_label[ident]=group
    dlc_by_label[ident]['members'].extend(members)
    for n in members:demon_group[n]=ident
   else:
    for n in members:requirements.setdefault(n,[]).append({'category':g['category'],'text':condition})
 for n,condition in req.items():
  if n in raw:
   requirements.setdefault(n,[]).append({'category':'Acquisition','text':condition})
   if condition=='Fusion Accident':sp[n]=[]
 for n in list(sp):
  if n not in raw:del sp[n]
 elementmap={n:{} for n in ec['elems']}
 for i,race in enumerate(ec['races']):
  for j,mod in enumerate(ec['table'][i]):
   if mod:elementmap[ec['elems'][j]][race]=mod
 demons=[]
 for n,v in raw.items():
  res={};divisor=1000 if key=='smt5v' else 10000
  for elem,code in zip(cfg['resistElems'],v.get('resists','')):
   res[translated(elem,elems)]={1:'흡수',2:'반사',3:'무효',4:'내성',5:'보통',6:'약점'}.get(cfg['resistCodes'].get(code,5*divisor)//divisor,'미확인')
  demons.append({'id':n,'name':NAME_FALLBACK_KO.get(n,translated(n,names)),'race':v['race'],'raceName':SMT_RACES_KO.get(v['race'],translated(v['race'],races)) if key=='smt5v' else translated(v['race'],races),'level':v['lvl'],'stats':dict(zip([translated(s,elems) for s in cfg['baseStats']],v['stats'])),'resists':res,'skills':[{'id':s,'name':translated(s,skills),'level':lvl} for s,lvl in v.get('skills',{}).items()],'dlc':demon_group.get(n),'requirements':requirements.get(n,[]),'acquisition':'special' if sp.get(n) else 'accident' if n in sp and n not in ec['elems'] else 'element' if n in ec['elems'] else 'normal'})
 data={'schema':1,'id':key,'title':title,'name':ko,'demons':demons,'dlc':dlc,'races':nc['races'],'normalChart':chart(nc,key!='smt5v'),'tripleChart':chart(nc,True,True) if key=='p4g' else {},'elementChart':elementmap,'elements':ec['elems'],'special':sp,'sourceCommit':subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD']).decode().strip()}
 out=Path('assets/megaten')/f'{key}.json';out.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 print(key,len(demons),'demons',len(sp),'special/other recipes',len(dlc),'DLC switches')
Path('assets/megaten/UNLICENSE.txt').write_text((root/'LICENSE.md').read_text())
Path('assets/megaten/provenance.json').write_text(json.dumps({'source':'https://github.com/aqiu384/megaten-fusion-tool','rawSource':'https://github.com/aqiu384/megaten-database','commit':data['sourceCommit'],'imported':'2026-11-09','files':used,'notes':['Guest humans and essence-only proto-fiends excluded by chart races.','Explicit Fusion Accident acquisitions excluded from deterministic result pools.','English IDs remain canonical; missing Korean names fall back to English except explicit Korean glossary supplements (SMT race names and Preta).','P3R Persona 4 Set and Persona 4 Set 1 label variants grouped into the same installable pack.','Normal charts are adapted using upstream PersonaFusionChart/SmtFusionChart conventions.']},ensure_ascii=False,indent=2)+'\n')
