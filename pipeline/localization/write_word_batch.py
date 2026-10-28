"""Save numbered, assistant-edited Korean glosses against a fixed source index.

Input lines: index<space>meaning; other meaning. The number is resolved to the
immutable OpenJLPT ID; it is never used as a runtime word identity.
"""
import json, sys
from pathlib import Path
base=Path(__file__).parent
index=json.loads((base/'word_index.json').read_text())
out=base/'word_meanings_ko.jsonl'
existing={r['entity_id']:r for r in (json.loads(l) for l in out.read_text().splitlines())} if out.exists() else {}
seen=set()
for line in sys.stdin:
    if not line.strip():continue
    number,value=line.strip().split(' ',1);i=int(number)
    if i in seen:raise ValueError(f'Duplicate index {i}')
    seen.add(i);source=index[i]
    meanings=[s.strip() for s in value.split(';') if s.strip()]
    existing[source['word_id']]={
        'entity_type':'word','entity_id':source['word_id'],'value':meanings,
        'method':'assistant_editorial_translation',
        'sources':['https://github.com/evanclan/OpenJLPT','https://www.edrdg.org/jmdict/j_jmdict.html'],
        'source':source,'notes':['일본어 표기·읽기와 원문 풀이를 참고해 AI가 작성·검토한 한국어 학습 뜻. 독립된 한국어 사전 또는 사람 검수 완료를 의미하지 않음.'],
        'assistant_review':'pass_1','human_review_required':True}
out.write_text(''.join(json.dumps(r,ensure_ascii=False,separators=(',',':'))+'\n' for r in existing.values()))
print(f'Saved {len(seen)}; total {len(existing)}/{len(index)}')
