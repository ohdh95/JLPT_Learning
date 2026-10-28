#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Independently compare imported OpenJLPT word+reading+JMdict IDs to official local JMdict XML.

Does not independently verify Korean word meanings, hanja hun/eum or examples.
"""
from __future__ import annotations
import argparse, gzip, hashlib, json
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path
import sqlite3
from xml.etree.ElementTree import iterparse

URL='https://www.edrdg.org/wiki/JMdict-EDICT_Dictionary_Project.html'


def scan(xml_file:Path, targets:set[tuple[str,str]]) -> tuple[dict, int]:
    found=defaultdict(set)
    n_entries=0
    opener=gzip.open if xml_file.suffix.lower()=='.gz' else open
    with opener(xml_file,'rb') as f:
        for _,node in iterparse(f,events=('end',)):
            if node.tag!='entry': continue
            n_entries+=1
            id_text=node.findtext('ent_seq')
            if not id_text:node.clear();continue
            ent_id=int(id_text)
            writings=[t.findtext('keb') for t in node.findall('k_ele') if t.findtext('keb')]
            for rr in node.findall('r_ele'):
                reading=rr.findtext('reb')
                if not reading:continue
                restrictions={el.text for el in rr.findall('re_restr') if el.text}
                no_kanji=rr.find('re_nokanji') is not None
                if not writings or no_kanji:
                    forms=[reading]
                else:
                    forms=[w for w in writings if (not restrictions or w in restrictions)]
                    # For a kana-only display spelling, JMdict also accepts the reading itself.
                    forms.append(reading)
                for surface in forms:
                    t=(surface,reading)
                    if t in targets:
                        found[t].add(ent_id)
            node.clear()
    return found,n_entries


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--db',type=Path,required=True)
    p.add_argument('--jmdict',type=Path,required=True,help='Full JMdict or JMdict_e XML or .gz')
    p.add_argument('--allow-tiny-test-fixture',action='store_true')
    p.add_argument('--report',type=Path,default=Path('jmdict_comparison.json'))
    args=p.parse_args()
    db=sqlite3.connect(args.db)
    rows=db.execute('SELECT word_id,surface,reading_kana,jmdict_id FROM vocab').fetchall()
    if not rows: raise ValueError('Empty database')
    lookup={(s,r) for _,s,r,_ in rows}
    found,n_entries=scan(args.jmdict,lookup)
    if n_entries<50_000 and not args.allow_tiny_test_fixture:
        raise ValueError(f'Only {n_entries} JMdict entries found. Use a full official JMdict XML file.')
    counts=Counter(); now=date.today().isoformat()
    for wid,s,r,linked_id in rows:
        ids=sorted(found.get((s,r),()))
        if not ids:
            status='not_found';counts[status]+=1
            db.execute("UPDATE vocab SET reading_check='jmdict_not_found' WHERE word_id=?",(wid,))
        elif linked_id is not None and linked_id not in ids:
            status='id_conflict';counts[status]+=1
            db.execute("UPDATE vocab SET reading_check='jmdict_id_conflict' WHERE word_id=?",(wid,))
        elif linked_id is None:
            status='pair_only';counts[status]+=1
            db.execute("UPDATE vocab SET reading_check='jmdict_pair_only' WHERE word_id=?",(wid,))
        else:
            status='direct_verified';counts[status]+=1
            db.execute("UPDATE vocab SET reading_check='direct_jmdict_verified' WHERE word_id=?",(wid,))
        if args.allow_tiny_test_fixture:
            db.execute("UPDATE vocab SET reading_check='test_fixture_only' WHERE word_id=?",(wid,))
        db.execute("DELETE FROM source_review WHERE entity_type='vocab' AND entity_id=? AND issue_code IN ('NOT_FOUND','ID_CONFLICT','PAIR_ONLY')", (wid,))
        db.execute('''INSERT INTO validations(word_id,field_name,status,reference_name,checked_at,note)
        VALUES(?,?,?,?,?,?) ON CONFLICT(word_id,field_name,reference_name)
        DO UPDATE SET status=excluded.status, checked_at=excluded.checked_at,note=excluded.note''',
        (wid,'surface_reading','test_fixture_only' if args.allow_tiny_test_fixture else status,'EDRDG JMdict direct',now,
         f'expected_entry={linked_id}; actual_entries={ids}; file={args.jmdict.name}'))
        if status!='direct_verified':
            db.execute('''INSERT OR IGNORE INTO source_review(entity_type,entity_id,field_name,severity,issue_code,message)
             VALUES(?,?,?,?,?,?)''',('vocab',wid,'surface_reading','high',status.upper(),
              f'Original JMdict {status}; expected {linked_id}; found {ids}'))
    sha=hashlib.sha256()
    with open(args.jmdict,'rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''):sha.update(chunk)
    db.execute('INSERT OR REPLACE INTO source_info(key,value) VALUES(?,?)',('jmdict_direct_source_sha256',sha.hexdigest()))
    db.execute('INSERT OR REPLACE INTO source_info(key,value) VALUES(?,?)',('jmdict_direct_check_date',now))
    db.commit()
    check=db.execute('PRAGMA integrity_check').fetchone()[0]
    if check!='ok':raise RuntimeError(check)
    result={'jmdict_entries_scanned':n_entries,'words_compared':len(rows),'status':dict(counts),'jmdict_sha256':sha.hexdigest(), 'integrity':check,
      'fixture_only':args.allow_tiny_test_fixture,
      'limitations':'Verified surface/kana/JMdict ID only. Korean translations, hun/eum, sense and example quality still pending.'}
    args.report.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False,indent=2))
    db.close()

if __name__=='__main__':main()
