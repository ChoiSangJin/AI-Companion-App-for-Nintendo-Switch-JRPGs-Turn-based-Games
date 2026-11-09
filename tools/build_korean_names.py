"""Build audited, per-edition display labels without changing canonical fusion IDs.
SMTV names are checked against a public multilingual game-name table; P3R against
its multilingual PersonaName table. P4G gaps use matching Japanese aliases,
shared SMT locale names where available, and explicitly marked editorial labels.
Only short factual names are retained; no character descriptions/art are copied.
"""
import argparse,collections,csv,hashlib,json,re,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--fusion-source',type=Path,required=True);p.add_argument('--database-source',type=Path,required=True);p.add_argument('--smt-locale-source',type=Path,required=True);a=p.parse_args()
names_path=a.fusion_source/'src/app/compendium/data/demon-names.json';names=json.loads(names_path.read_text())
p3_path=a.database_source/'src/p3r/Content/Xrd777/Blueprints/common/Names/DatPersonaNameDataAsset.tsv'
smt_path=a.smt_locale_source/'locales/character_name.json'
def idx(rows):
 result=collections.defaultdict(set)
 for row in rows:
  if row.get('en') and re.search('[가-힣]',row.get('ko','')):result[row['en']].add(row['ko'])
 return result
# Character IDs below 500 are compendium names; later rows include NPC labels (e.g. Angel/천사).
p3=idx(csv.DictReader(p3_path.open(),delimiter='\t'));smt=idx(row for row in json.loads(smt_path.read_text()) if row['id'] < 500)
jp=collections.defaultdict(list)
for en,v in names.items():
 if len(v)>2 and re.search('[가-힣]',v[2]):jp[v[0]].append((en,v[2]))
supplements=json.loads(Path('tools/localization/p4g_supplements.json').read_text())
all_games={};counts=collections.Counter()
for file in sorted(Path('assets/megaten').glob('*.json')):
 data=json.loads(file.read_text())
 if 'demons' not in data:continue
 game=data['id'];result={};ids={d['id'] for d in data['demons']}
 for d in data['demons']:
  ident=d['id'];base=re.sub(r' [A-HJ-Z]$','',ident);japanese=names.get(base,[''])[0]
  source_name=names.get(base,[])
  value=(source_name[2] if len(source_name)>2 and source_name[2] else base)+ident[len(base):]
  if ident=='Preta':value='아귀'
  origin='upstream_korean';aliases={ident,value};aliases.update(x[0] for x in jp.get(japanese,[]))
  if japanese:aliases.add(japanese)
  table=p3 if game=='p3r' else smt if game=='smt5v' else {}
  if base in table:
   if len(table[base])!=1:raise ValueError(('Ambiguous Korean table',game,base,table[base]))
   value=next(iter(table[base]));origin='p3r_locale' if game=='p3r' else 'smt5v_locale'
  elif game=='smt5v' and base in ['Dis','Marici']:
   value={'Dis':'디스','Marici':'마리시텐'}[base];origin='editorial_ko';aliases.add({'Dis':'Dís','Marici':'Marishiten'}[base])
  elif not re.search('[가-힣]',value):
   if base in smt and len(smt[base])==1:value=next(iter(smt[base]));origin='shared_smt_locale'
   elif jp.get(japanese):
    if len({ko for en,ko in jp[japanese]})!=1:raise ValueError(('Ambiguous Japanese alias',ident))
    value=jp[japanese][0][1];origin='same_japanese_alias'
   elif base in supplements:
    entry=supplements[base]
    if entry['japanese']!=japanese:raise ValueError(('Japanese identity mismatch',ident))
    value=entry['name'];aliases.update(entry['aliases']);origin='editorial_ko'
   else:raise ValueError(('Unreviewed Korean name',game,ident))
  # Correct obvious common mistranscriptions while keeping old labels searchable.
  if game in ['p4g','p5r'] and base in ['Mishaguji','Beelzebub']:
   value={'Mishaguji':'미샤구지사마','Beelzebub':'베엘제붑'}[base];origin='shared_p3r_smt_locale'
  aliases.add(value)
  if base!=ident and base in ids:
   value=f"{value} ({d['raceName']})" # Distinct forms share a native game name.
  result[ident]={'name':value,'aliases':sorted(aliases-{value}),'basis':origin,'japanese':japanese}
  if not re.search('[가-힣]',value):raise ValueError(('Non-Korean primary label',game,ident))
  counts[origin]+=1
 all_games[game]=result
sources={}
for label,repo,root,file in [('p3r_locale','https://github.com/aqiu384/megaten-database',a.database_source,p3_path),('smt5v_locale','https://github.com/sisyphusw/smt5v',a.smt_locale_source,smt_path),('upstream_names','https://github.com/aqiu384/megaten-fusion-tool',a.fusion_source,names_path)]:
 sources[label]={'repository':repo,'commit':subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD']).decode().strip(),'path':str(file.relative_to(root)),'sha256':hashlib.sha256(file.read_bytes()).hexdigest()}
Path('tools/localization/korean_demon_names.json').write_text(json.dumps({'schema':1,'sources':sources,'games':all_games,'basis_counts':dict(counts)},ensure_ascii=False,indent=2)+'\n')
print('Korean labels:',sum(map(len,all_games.values())),dict(counts))
