"""Capture corrections by immutable example ID: <example_id> <Korean text>."""
import json,sqlite3,sys
from pathlib import Path
base=Path(__file__).parent;path=base/'example_corrections.jsonl'
known={r['entity_id']:r for r in map(json.loads,path.read_text().splitlines())} if path.exists() else {}
db=sqlite3.connect(base.parents[1]/'assets/content.sqlite')
for line in sys.stdin:
    if not line.strip():continue
    eid,text=line.strip().split(' ',1)
    row=db.execute('SELECT text_ja,text_en,tatoeba_id FROM examples WHERE example_id=?',[eid]).fetchone()
    if not row:raise ValueError(eid)
    known[eid]=dict(entity_type='example',entity_id=eid,value=text,method='assistant_ja_ko_review',
        sources=[f'https://tatoeba.org/en/sentences/show/{row[2]}','https://github.com/evanclan/OpenJLPT'],
        source=dict(text_ja=row[0],text_en=row[1]),assistant_review='correction_pass',human_review_required=True,
        notes=['일본어 원문·영어 풀이와 대조하여 AI가 번역을 교정함. 독립 사람 검수 완료 아님.'])
path.write_text(''.join(json.dumps(r,ensure_ascii=False)+'\n' for r in known.values()));print('corrections',len(known))
