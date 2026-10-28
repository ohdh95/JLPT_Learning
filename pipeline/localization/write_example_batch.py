"""Capture assistant-reviewed translations, retaining attribution for adapted sources."""
import json, sys
from pathlib import Path

base=Path(__file__).parent
index=json.loads((base/'example_review_index.json').read_text())
tatoeba={x['entity_id']:x for x in map(json.loads,(base/'example_tatoeba_drafts.jsonl').read_text().splitlines())}
out=base/'example_editorial_drafts.jsonl'
known={x['entity_id']:x for x in map(json.loads,out.read_text().splitlines())} if out.exists() else {}
seen=set()
for line in sys.stdin:
    if not line.strip():continue
    number,text=line.strip().split(' ',1);i=int(number)
    if i in seen:raise ValueError('Duplicate index')
    seen.add(i);r=index[i];prior=tatoeba.get(r['example_id'])
    known[r['example_id']]=dict(entity_type='example',entity_id=r['example_id'],value=text,
        method='assistant_ja_ko_review',sources=[f"https://tatoeba.org/en/sentences/show/{r['tatoeba_id']}", 'https://github.com/evanclan/OpenJLPT'],
        source=dict(text_ja=r['text_ja'],text_en=r['text_en']),
        previous_candidate=r['candidate'],previous_method=r['candidate_method'],
        adapted_translation=prior,assistant_review='ja_ko_pass_1',human_review_required=True,
        notes=['일본어 원문과 AI가 직접 대조·수정한 번역. 독립 사람 검수 완료 아님.'])
out.write_text(''.join(json.dumps(r,ensure_ascii=False)+'\n' for r in known.values()))
print('saved',len(seen),'total',len(known))
