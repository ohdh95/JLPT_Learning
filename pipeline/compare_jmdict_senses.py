"""Export current linked-entry senses for editorial review, not certification.

Respects sense-level spelling/reading restrictions. A linked entry is not proof
that the upstream spelling or sense is correct: see verify_jmdict.py separately.
Exact English gloss differences are review candidates, not error counts.
"""
import argparse, gzip, json, sqlite3
from collections import defaultdict
from pathlib import Path
from xml.etree.ElementTree import iterparse
from localization_common import digest


def compare(db, xml):
    targets=defaultdict(list)
    db.row_factory=sqlite3.Row
    for row in db.execute('SELECT word_id,surface,reading_kana,jmdict_id,gloss_en_json,meanings_ko_json,reading_check FROM vocab'):
        if row['jmdict_id'] is not None: targets[int(row['jmdict_id'])].append(dict(row))
    rows=[];entries=0
    opener=gzip.open if xml.suffix=='.gz' else open
    with opener(xml,'rb') as f:
        for _,node in iterparse(f,events=('end',)):
            if node.tag!='entry':continue
            entries+=1
            for source in targets.get(int(node.findtext('ent_seq')),[]):
                senses=[]
                for sense in node.findall('sense'):
                    spellings=[el.text for el in sense.findall('stagk')]
                    readings=[el.text for el in sense.findall('stagr')]
                    if spellings and source['surface'] not in spellings:continue
                    if readings and source['reading_kana'] not in readings:continue
                    senses.append({'gloss':[el.text for el in sense.findall('gloss') if el.attrib.get('{http://www.w3.org/XML/1998/namespace}lang','eng')=='eng'],
                                   'notes':[el.text for el in sense.findall('s_inf')],
                                   'spelling_restrictions':spellings,'reading_restrictions':readings})
                upstream=json.loads(source['gloss_en_json']);current={g for s in senses for g in s['gloss']}
                rows.append({**source,'senses':senses,'no_exact_gloss_overlap':not bool(set(upstream)&current)})
            node.clear()
    return {'entries_scanned':entries,'linked_entries_compared':len(rows),
            'jmdict_sha256':digest(xml),'certifies_korean':False,'rows':rows}


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--db',type=Path,required=True);p.add_argument('--jmdict',type=Path,required=True)
    p.add_argument('--out',type=Path,default=Path('reports/localization-current-senses.json'));a=p.parse_args()
    with sqlite3.connect(a.db) as db:r=compare(db,a.jmdict)
    a.out.write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:v for k,v in r.items() if k!='rows'}))
