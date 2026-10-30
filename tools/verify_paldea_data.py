"""Verify bundled Korean names, forms, types and level evolutions against PokéAPI CSV.
Run with the same local CSV directory used by build_paldea_catalog.py. No runtime API.
"""
import argparse
import csv
import json
import re
from pathlib import Path
parser = argparse.ArgumentParser()
parser.add_argument('--source-dir', required=True, type=Path)
root = parser.parse_args().source_dir
def rows(name):
    return list(csv.DictReader((root / name).open()))
names = {int(r['pokemon_species_id']): r['name'] for r in rows('pokemon_species_names.csv') if r['local_language_id'] == '3'}
type_labels = {1:'노말',2:'격투',3:'비행',4:'독',5:'땅',6:'바위',7:'벌레',8:'고스트',9:'강철',10:'불꽃',11:'물',12:'풀',13:'전기',14:'에스퍼',15:'얼음',16:'드래곤',17:'악',18:'페어리'}
pt = {}
for r in rows('pokemon_types.csv'):
    pt.setdefault(int(r['pokemon_id']), []).append(type_labels.get(int(r['type_id'])))
evolutions = rows('pokemon_evolution.csv')
data = json.loads(Path('assets/data/paldea.json').read_text())
for line in data['lines']:
    for form in line['forms']:
        assert form['name'] == names[form['id']], form
        assert form['types'] == pt[form['id']], form
    for form, condition in zip(line['forms'][1:], line['conditions']):
        level = re.match(r'Lv\.(\d+)', condition)
        if level:
            assert any(int(r['evolved_species_id']) == form['id'] and r['minimum_level'] == level[1] for r in evolutions), (form, condition)
assert len(data['route']) == 18
assert [len([r for r in data['route'] if r['kind'] == k]) for k in ['체육관','주인','스타단']] == [8,5,5]
assert sorted(r['level'] for r in data['route']) == [r['level'] for r in data['route']]
print('Verified', len(data['lines']), 'evolution lines, Korean names, form types, level evolutions and 18 route entries.')
