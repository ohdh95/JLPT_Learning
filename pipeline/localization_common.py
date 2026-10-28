"""Auditable draft imports. Automated work can never set human_reviewed."""
from __future__ import annotations
import hashlib, json, re, sqlite3
from datetime import datetime, timezone
from pathlib import Path
from korean_localization import SCHEMA, CONFIG

def dump(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':'))

def digest(path):
    sha = hashlib.sha256()
    with Path(path).open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            sha.update(chunk)
    return sha.hexdigest()

def read_jsonl(path):
    if not Path(path).exists(): return []
    return [json.loads(line) for line in Path(path).read_text().splitlines() if line.strip()]

def append_jsonl(path, row):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with Path(path).open('a', encoding='utf-8') as f:
        f.write(dump(row)+'\n'); f.flush()

def validate_candidate(row):
    kind = row['entity_type']; value = row['value']
    if kind not in CONFIG or not row.get('entity_id') or not row.get('sources') or not row.get('method'):
        raise ValueError('Missing entity/source evidence')
    if row.get('reviewed') or row.get('status') == 'human_reviewed' or row.get('reviewer_type') == 'human':
        raise ValueError('Automated candidates cannot claim human review')
    texts = value if kind == 'word' else ([value['hun'], value['eum']] if kind == 'kanji' else [value])
    if not isinstance(texts, list) or not texts:
        raise ValueError('Empty translation')
    for t in texts:
        if not isinstance(t, str) or not t.strip() or not re.search('[가-힣]', t):
            raise ValueError('Expected nonempty Korean text')
        if '\ufffd' in t or any(ord(c)<32 for c in t):
            raise ValueError('Invalid control/replacement character')
    if kind == 'kanji' and not re.fullmatch('[가-힣]', value['eum']):
        raise ValueError('Hanja eum must be one Korean syllable')

def import_candidates(db, rows):
    db.executescript(SCHEMA + '''
CREATE TABLE IF NOT EXISTS localization_provenance(
 entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, method TEXT NOT NULL,
 evidence_json TEXT NOT NULL, updated_at TEXT NOT NULL,
 PRIMARY KEY(entity_type,entity_id));
''')
    counts = {'updated_draft':0,'unchanged':0,'protected_human_review':0}
    with db:
        for row in rows:
            validate_candidate(row)
            kind = row['entity_type']; ident = row['entity_id']
            table,key,col,status_col,_ = CONFIG[kind]
            old = db.execute(f'SELECT {col},{status_col}'+(',korean_eum' if kind=='kanji' else '')+f' FROM {table} WHERE {key}=?', [ident]).fetchone()
            if old is None: raise ValueError(f'Unknown {kind}: {ident}')
            if old[1]=='human_reviewed':
                counts['protected_human_review']+=1; continue
            val = row['value']
            value = dump(val) if kind=='word' else (val['hun'] if kind=='kanji' else val)
            same = old[0]==value and old[1]=='draft' and (kind!='kanji' or old[2]==val['eum'])
            evidence = dump({**row,'reviewed':False,'reviewer_type':'automated','human_review_required':True})
            previous = db.execute('SELECT evidence_json FROM localization_provenance WHERE entity_type=? AND entity_id=?',[kind,ident]).fetchone()
            if same and previous and previous[0]==evidence:
                counts['unchanged']+=1; continue
            now = datetime.now(timezone.utc).isoformat()
            db.execute(f'UPDATE {table} SET {col}=?,{status_col}=? WHERE {key}=?',[value,'draft',ident])
            if kind=='kanji': db.execute('UPDATE kanji SET korean_eum=? WHERE character=?',[val['eum'],ident])
            db.execute('INSERT OR REPLACE INTO localization_checks VALUES(?,?,?,?,?,?)',[kind,ident,col,'draft',row['sources'][0],now])
            db.execute('INSERT OR REPLACE INTO localization_provenance VALUES(?,?,?,?,?)',[kind,ident,row['method'],evidence,now])
            db.execute('INSERT INTO localization_history(entity_type,entity_id,before_json,after_json,evidence_json,updated_at) VALUES(?,?,?,?,?,?)',
                       [kind,ident,dump(list(old)),dump({'value':val,'status':'draft'}),evidence,now])
            counts['updated_draft']+=1
    return counts

if __name__=='__main__':
    import argparse
    ap=argparse.ArgumentParser();ap.add_argument('--db',required=True);ap.add_argument('files',nargs='+');a=ap.parse_args()
    rows=[r for path in a.files for r in read_jsonl(path)]
    # Validate the entire batch before opening a transaction.
    for row in rows: validate_candidate(row)
    with sqlite3.connect(a.db) as db: print(import_candidates(db,rows))
