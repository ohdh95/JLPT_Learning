#!/usr/bin/env python3
"""Evidence-carrying human review import; never certifies automatic translations."""
from __future__ import annotations
import argparse, csv, json, sqlite3
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

SCHEMA = '''
CREATE TABLE IF NOT EXISTS localization_checks(
 entity_type TEXT NOT NULL,entity_id TEXT NOT NULL,field_name TEXT NOT NULL,
 status TEXT NOT NULL,reference_url TEXT,updated_at TEXT NOT NULL,
 PRIMARY KEY(entity_type,entity_id,field_name));
CREATE TABLE IF NOT EXISTS localization_history(
 id INTEGER PRIMARY KEY,entity_type TEXT NOT NULL,entity_id TEXT NOT NULL,
 before_json TEXT NOT NULL,after_json TEXT NOT NULL,evidence_json TEXT NOT NULL,
 updated_at TEXT NOT NULL);
'''
EVIDENCE=['reference_url','cross_reference_url','reviewer','reviewed_at','evidence_note','reviewed']
CONFIG={
 'word':('vocab','word_id','meanings_ko_json','korean_meaning_status','meaning_ko'),
 'kanji':('kanji','character','korean_hun','korean_hun_eum_status','korean_hun'),
 'example':('examples','example_id','text_ko','korean_translation_status','translation_ko'),
}

def export_templates(db,folder,limit=None):
    folder.mkdir(parents=True,exist_ok=True)
    queries={
      'word_meanings_review.csv':("SELECT word_id,surface,reading_kana,jlpt_level,gloss_en_json,meanings_ko_json FROM vocab ORDER BY jlpt_level DESC,source_index",['word_id','surface','reading_kana','jlpt_level','gloss_en_json','meaning_ko']),
      'kanji_huneum_review.csv':('SELECT character,jlpt_level,meanings_en_json,korean_hun,korean_eum FROM kanji ORDER BY jlpt_level DESC,character',['character','jlpt_level','meanings_en_json','korean_hun','korean_eum']),
      'example_translation_review.csv':('SELECT example_id,word_id,text_ja,text_en,text_ko FROM examples ORDER BY word_id,sequence',['example_id','word_id','text_ja','text_en','translation_ko']),
    }
    for name,(q,header) in queries.items():
        with (folder/name).open('w',encoding='utf-8-sig',newline='') as f:
            writer=csv.writer(f);writer.writerow(header+EVIDENCE)
            for row in db.execute(q+(' LIMIT ?' if limit else ''),[limit] if limit else []):
                row=list(row)
                if name.startswith('word_') and row[-1]:row[-1]='; '.join(json.loads(row[-1]))
                writer.writerow([v or '' for v in row]+['','','','','','0'])
    print('Exported editable review templates:',folder)

def evidence_valid(row):
    urls=[urlparse(row.get(k,'').strip()) for k in EVIDENCE[:2]]
    try:datetime.fromisoformat(row.get('reviewed_at',''))
    except ValueError:return False
    return (all(u.scheme in ('http','https') and u.hostname for u in urls)
        and urls[0].hostname!=urls[1].hostname
        and bool(row.get('reviewer','').strip()) and bool(row.get('evidence_note','').strip()))

def import_review(db,file,kind):
    db.executescript(SCHEMA)
    table,key,value_col,status_col,csv_value=CONFIG[kind]
    counts={'updated_draft':0,'updated_verified':0,'skipped_empty':0,'invalid':0}
    with db, file.open(encoding='utf-8-sig',newline='') as f:
        for row in csv.DictReader(f):
            ident=row.get(key,'').strip(); val=row.get(csv_value,'').strip()
            if not val or (kind=='kanji' and not row.get('korean_eum','').strip()):counts['skipped_empty']+=1;continue
            old=db.execute(f'SELECT * FROM {table} WHERE {key}=?',(ident,)).fetchone()
            if not old:counts['invalid']+=1;continue
            reviewed=row.get('reviewed','').strip().lower() in ('true','yes','1','y')
            status='human_reviewed' if reviewed and evidence_valid(row) else 'draft'
            value=json.dumps([s.strip() for s in val.split(';') if s.strip()],ensure_ascii=False) if kind=='word' else val
            db.execute(f'UPDATE {table} SET {value_col}=?,{status_col}=? WHERE {key}=?',(value,status,ident))
            if kind=='kanji':db.execute('UPDATE kanji SET korean_eum=? WHERE character=?',(row['korean_eum'].strip(),ident))
            now=datetime.now(timezone.utc).isoformat()
            db.execute('INSERT OR REPLACE INTO localization_checks VALUES(?,?,?,?,?,?)',(kind,ident,value_col,status,row.get('reference_url',''),now))
            db.execute('INSERT INTO localization_history(entity_type,entity_id,before_json,after_json,evidence_json,updated_at) VALUES(?,?,?,?,?,?)',
                (kind,ident,json.dumps(list(old),ensure_ascii=False),json.dumps({'value':value,'status':status,'eum':row.get('korean_eum')},ensure_ascii=False),json.dumps({k:row.get(k,'') for k in EVIDENCE},ensure_ascii=False),now))
            counts['updated_verified' if status=='human_reviewed' else 'updated_draft']+=1
    print(kind,counts)
    return counts

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--db',type=Path,required=True)
    g=ap.add_mutually_exclusive_group(required=True)
    g.add_argument('--export',type=Path)
    for kind in CONFIG:g.add_argument('--import-'+kind,type=Path)
    ap.add_argument('--limit',type=int);a=ap.parse_args()
    with sqlite3.connect(a.db) as db:
        if a.export:export_templates(db,a.export,a.limit)
        else:
            for kind in CONFIG:
                if getattr(a,'import_'+kind):import_review(db,getattr(a,'import_'+kind),kind)
if __name__=='__main__':main()
