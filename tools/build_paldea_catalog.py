import csv,json
from pathlib import Path
import argparse
parser = argparse.ArgumentParser(description='Rebuild the bundled, offline Paldea starter catalog from local PokéAPI CSV files.')
parser.add_argument('--source-dir', type=Path, required=True)
root = parser.parse_args().source_dir
def rows(name): return list(csv.DictReader((root/name).open()))
names={int(r['pokemon_species_id']):r['name'] for r in rows('pokemon_species_names.csv') if r['local_language_id']=='3'}
english={int(r['pokemon_species_id']):r['name'] for r in rows('pokemon_species_names.csv') if r['local_language_id']=='9'}
pt={}
for r in rows('pokemon_types.csv'): pt.setdefault(int(r['pokemon_id']),[]).append(int(r['type_id']))
types={1:'노말',2:'격투',3:'비행',4:'독',5:'땅',6:'바위',7:'벌레',8:'고스트',9:'강철',10:'불꽃',11:'물',12:'풀',13:'전기',14:'에스퍼',15:'얼음',16:'드래곤',17:'악',18:'페어리'}
lines=[]
def add(key,ids,conditions,location,reason,stage='초반',versions=None,starter=False):
 lines.append(dict(id=key,forms=[dict(id=i,name=names[i],english=english[i],types=[types[t] for t in pt[i]]) for i in ids],conditions=conditions,location=location,reason=reason,stage=stage,versions=versions or ['scarlet','violet'],starter=starter,source=f'https://www.serebii.net/pokedex-sv/{english[ids[0]].lower()}/'))
add('sprigatito',[906,907,908],['Lv.16에 진화','Lv.36에 진화'],'모험 시작 때 세 마리 중 한 마리로 선택합니다. 다른 첫 파트너는 교환이 필요합니다.','빠른 풀 타입으로 시작하고 최종 진화에서 악 타입이 더해집니다.',starter=True)
add('fuecoco',[909,910,911],['Lv.16에 진화','Lv.36에 진화'],'모험 시작 때 세 마리 중 한 마리로 선택합니다. 다른 첫 파트너는 교환이 필요합니다.','불꽃 특수 공격을 담당하고 최종 진화에서 고스트 타입이 더해집니다.',starter=True)
add('quaxly',[912,913,914],['Lv.16에 진화','Lv.36에 진화'],'모험 시작 때 세 마리 중 한 마리로 선택합니다. 다른 첫 파트너는 교환이 필요합니다.','물 타입으로 시작하고 최종 진화에서 격투 타입이 더해집니다.',starter=True)
add('pawmi',[921,922,923],['Lv.18에 진화','빠모트 상태로 레츠고를 이용해 1,000보 함께 걷고 일반 전투·사탕으로 레벨업'],'남부 지역의 들판에서 찾을 수 있습니다.','초반 전기 역할. 최종 진화에는 걷기 조건이 있어 일반 레벨업만으로는 부족합니다.')
add('fletchling',[661,662,663],['Lv.17에 진화','Lv.35에 진화'],'남부 지역의 초반 들판에서 찾을 수 있습니다.','초반 비행 역할. 불화살빈으로 진화하면 불꽃 타입도 담당합니다.')
add('azurill',[298,183,184],['친밀도가 높은 상태에서 레벨업','Lv.18 이상에서 레벨업'],'남부 지역의 물가에서 찾을 수 있습니다.','최종적으로 물·페어리 역할. 물리 공격용이라면 특성 천하장사 여부를 확인하세요.')
add('ralts',[280,281,282],['Lv.20에 진화','Lv.30에 가디안으로 진화'],'남부 지역에서 드물게 나타납니다. 게임 도감 서식지를 확인하세요.','에스퍼·페어리 역할. 이 카드는 가디안 경로이며 엘레이드 분기는 다루지 않습니다.')
add('mareep',[179,180,181],['Lv.15에 진화','Lv.30에 진화'],'남부 지역의 들판에서 찾을 수 있습니다.','복잡한 추가 조건 없이 레벨업으로 완성하는 전기 특수 공격 후보입니다.')
add('magikarp',[129,130],['Lv.20에 진화'],'강·연못 등 물가에서 찾을 수 있습니다.','갸라도스로 진화한 뒤 물·비행 역할. 잉어킹 상태에서는 다른 멤버의 육성 도움이 필요합니다.')
add('fidough',[926,927],['Lv.26에 진화'],'남부 지역의 마을 주변에서 찾을 수 있습니다.','페어리 역할. 바우첼의 노릇노릇바디 특성은 불꽃 기술에 대응할 때 유용합니다.')
add('nacli',[932,933,934],['Lv.24에 진화','Lv.38에 진화'],'남부·동부의 바위가 많은 곳에서 찾을 수 있습니다.','바위 역할의 튼튼한 후보. 물·풀·격투·땅·강철 약점을 파티와 함께 보완하세요.')
add('smoliv',[928,929,930],['Lv.25에 진화','Lv.35에 진화'],'남부의 올리브 밭 주변에서 찾을 수 있습니다.','풀 특수 공격 후보. 노말 타입이 함께 있으므로 격투 공격에 주의하세요.')
add('wattrel',[940,941],['Lv.25에 진화'],'팔데아 해안가에서 찾을 수 있습니다.','전기·비행을 한 자리에서 담당합니다. 다른 전기 멤버와 역할이 겹치는지 확인하세요.')
add('tinkatink',[957,958,959],['Lv.24에 진화','Lv.38에 진화'],'팔데아 각지의 유적 주변에서 찾을 수 있습니다.','페어리·강철 조합으로 파티의 타입 구성을 보완합니다.')
add('mankey',[56,57,979],['Lv.28에 진화','성원숭이로 분노의주먹을 20회 사용한 뒤 레벨업 (기술은 Lv.35에 습득)'],'서부·남부의 들판에서 찾을 수 있습니다.','격투 역할. 저승갓숭 진화는 기술 사용 횟수를 따로 채워야 합니다.')
add('charcadet-scarlet',[935,936],['피케마을에서 동미러의조각 10개로 교환한 축복받은갑옷을 사용'],'팔데아 여러 지역에서 드물게 나타납니다. 갑옷 교환은 스칼렛 기준입니다.','불꽃·에스퍼의 카디나르마 경로. 바이올렛의 진화 아이템과 다릅니다.',versions=['scarlet'])
add('charcadet-violet',[935,937],['피케마을에서 데인차의조각 10개로 교환한 저주받은갑옷을 사용'],'팔데아 여러 지역에서 드물게 나타납니다. 갑옷 교환은 바이올렛 기준입니다.','불꽃·고스트의 파라블레이즈 경로. 스칼렛의 진화 아이템과 다릅니다.',versions=['violet'])
add('gible',[443,444,445],['Lv.24에 진화','Lv.48에 진화'],'팔데아 서쪽의 동굴 주변을 찾아보세요.','땅·드래곤 후보. 최종 진화까지 시간이 필요하고 얼음 약점은 크게 주의해야 합니다.',stage='중반')
add('riolu',[447,448],['친밀도가 높은 상태에서 낮에 레벨업'],'남서부 지역에서 드물게 나타납니다.','최종 진화에서 격투·강철 역할. 친밀도와 시간대를 모두 확인하세요.',stage='중반')
add('rookidee',[821,822,823],['Lv.18에 진화','Lv.38에 진화'],'남부·동부의 들판에서 찾을 수 있습니다.','최종 진화에서 비행·강철 역할. 진화 전에는 강철 타입이 아닙니다.')
add('larvitar',[246,247,248],['Lv.30에 진화','Lv.55에 진화'],'스칼렛 본편의 동굴·산지에서 찾을 수 있습니다.','스칼렛 전용 장기 육성 후보. 최종 진화 때 땅 타입이 악 타입으로 바뀝니다.',stage='중반',versions=['scarlet'])
add('deino',[633,634,635],['Lv.50에 진화','Lv.64에 진화'],'스칼렛 본편의 동굴에서 찾을 수 있습니다.','스칼렛 전용 악·드래곤 후보. 진화 레벨이 높아 초반 주력으로는 부담이 큽니다.',stage='후반',versions=['scarlet'])
add('bagon',[371,372,373],['Lv.30에 진화','Lv.50에 진화'],'바이올렛 본편의 동굴에서 찾을 수 있습니다.','바이올렛 전용 장기 육성 후보. 보만다로 진화하면 비행 타입이 더해집니다.',stage='중반',versions=['violet'])
add('dreepy',[885,886,887],['Lv.50에 진화','Lv.60에 진화'],'바이올렛 본편의 물가·습지에서 찾을 수 있습니다.','바이올렛 전용 드래곤·고스트 후보. 진화 레벨이 높아 후반 육성에 적합합니다.',stage='후반',versions=['violet'])
route=[
('cortondo','세르클마을 체육관','체육관','벌레',15,'벌레 타입에 대비해 불꽃·비행·바위 기술을 준비하세요.',''),
('klawf','암벽의 주인','주인','바위',16,'물·풀·격투·땅·강철 기술을 가진 멤버를 준비하세요.','대시'),
('artazon','보울마을 체육관','체육관','풀',17,'불꽃·비행·벌레·독·얼음 기술을 검토하세요.',''),
('bombirdier','대공의 주인','주인','비행·악',19,'전기·얼음·바위·페어리 기술을 검토하세요.','헤엄치기'),
('dark','스타단 악 아지트','스타단','악',21,'격투·벌레·페어리 멤버와 레츠고용 3마리를 준비하세요.',''),
('levincia','누룩스시티 체육관','체육관','전기',24,'땅 기술만 믿지 말고 특성·테라스탈로 약점이 달라지는 상황에 대비하세요.',''),
('fire','스타단 불꽃 아지트','스타단','불꽃',27,'물·땅·바위 멤버와 레츠고용 3마리를 준비하세요.',''),
('orthworm','잠강의 주인','주인','강철',28,'땅 공격을 흡수하는 특성이 있으므로 불꽃·격투 기술을 준비하세요.','높이뛰기'),
('cascarrafa','카라프시티 체육관','체육관','물',30,'풀·전기 기술을 준비하세요.',''),
('poison','스타단 독 아지트','스타단','독',33,'땅·에스퍼 기술을 검토하고 상태이상 회복 도구를 챙기세요.',''),
('medali','참푸르마을 체육관','체육관','노말',36,'격투 기술과 충분한 회복 도구를 준비하세요.',''),
('montenevera','프리지마을 체육관','체육관','고스트',42,'더블배틀에 쓸 두 멤버와 악·고스트 기술을 준비하세요.',''),
('earth','토진의 주인','주인','버전별 다름',44,'스칼렛은 땅·격투, 바이올렛은 땅·강철 상대입니다. 물·풀 기술을 검토하세요.','활공'),
('alfornada','베이크마을 체육관','체육관','에스퍼',45,'악·고스트·벌레 기술을 검토하세요.',''),
('glaseado','나페산 체육관','체육관','얼음',48,'불꽃·격투·바위·강철 기술을 검토하세요.',''),
('fairy','스타단 페어리 아지트','스타단','페어리',51,'독·강철 멤버와 레츠고용 3마리를 준비하세요.',''),
('dragon','위룡의 주인','주인','물 → 드래곤·물',55,'첫 상대의 물 타입과 뒤이은 드래곤·물 타입에 각각 대비하세요.','벽타기'),
('fighting','스타단 격투 아지트','스타단','격투',56,'비행·에스퍼·페어리 멤버와 레츠고용 3마리를 준비하세요.',''),
]
data=dict(schema=1,revision='2026-10-30',scope='스칼렛·바이올렛 본편 / DLC·HOME·교환 제외',lines=lines,route=[dict(id=x[0],title=x[1],kind=x[2],type=x[3],level=x[4],tip=x[5],reward=x[6]) for x in route])
data['typeChart'] = {v: {} for v in types.values()}
for r in rows('type_efficacy.csv'):
 a,d = int(r['damage_type_id']), int(r['target_type_id'])
 if a in types and d in types: data['typeChart'][types[a]][types[d]] = int(r['damage_factor']) / 100
Path('assets/data/paldea.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
Path('assets/data/POKEAPI-LICENSE.txt').write_text((root/'LICENSE.md').read_text())
print('lines',len(lines),'route',len(route))
