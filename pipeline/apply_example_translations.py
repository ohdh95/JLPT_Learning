"""Fill all example translations with provenance and editorial override priority.

The user requested all translations in the app. No field becomes human_reviewed.
Original Japanese/English and prior editorial corrections are retained. This
does not import the earlier, rejected M2M100 candidate corpus.
"""
import argparse,json,sqlite3
from pathlib import Path
from localization_common import read_jsonl,import_candidates,digest
from apply_localization import expand_examples
from translate_examples_madlad import flags
from review_all_examples import load_completed_review, store_metadata

def merge(db,folder):
    originals={r[0]:(r[1],r[2]) for r in db.execute('SELECT example_id,text_ja,text_en FROM examples')}
    auto=read_jsonl(folder/'example_service_drafts.jsonl')
    by_id={r['entity_id']:r for r in auto}
    if len(by_id)!=len(auto) or set(by_id)!=set(originals):raise ValueError('Full unique example ID coverage required')
    for row in auto:
        if row['method']!='google_en_ko_translation':raise ValueError('Unexpected translation method')
        if (row['source']['text_ja'],row['source']['text_en'])!=originals[row['entity_id']]:raise ValueError('Changed source sentence')
    editorial=expand_examples(db,read_jsonl(folder/'example_editorial_drafts.jsonl'))
    for row in editorial:by_id[row['entity_id']]=row
    corrections=read_jsonl(folder/'example_corrections.jsonl')
    for row in expand_examples(db,corrections):by_id[row['entity_id']]=row
    full_review=folder/'full_review'
    if (folder/'example_full_review.jsonl').exists() or (full_review/'manifest.json').exists():
        reviewed,_=load_completed_review(db,full_review)
        for row in reviewed:by_id[row['entity_id']]=row
    unresolved=[]
    for eid,row in by_id.items():
        issue=flags(row['value'],row['source']['text_ja'])
        if issue and not row.get('qa_editorial_exception'):unresolved.append({'id':eid,'flags':issue,'value':row['value']})
    if unresolved:raise ValueError('Unresolved translation checks: '+json.dumps(unresolved,ensure_ascii=False))
    return list(by_id.values())

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--db',required=True);p.add_argument('--folder',type=Path,default=Path('pipeline/localization'));a=p.parse_args()
    with sqlite3.connect(a.db) as db:
        rows=merge(db,a.folder);result=import_candidates(db,rows)
        with db:
            info={'date':'2026-10-28','translated':len(rows),'method':'English gloss to Korean with Google Translate plus Japanese editorial overrides',
                  'human_review_completed':False,'machine_candidate_sha256':digest(a.folder/'example_service_drafts.jsonl'),
                  'corrections_sha256':digest(a.folder/'example_corrections.jsonl')}
            db.execute('INSERT OR REPLACE INTO source_info VALUES(?,?)',['complete_example_translations',json.dumps(info,ensure_ascii=False)])
            if (a.folder/'full_review/manifest.json').exists():
                store_metadata(db,a.folder/'full_review')
                info['method']='Full Japanese/Korean semantic and fluency review by Codex AI; independent human review pending'
                info['review_manifest_sha256']=digest(a.folder/'full_review/manifest.json')
                db.execute('INSERT OR REPLACE INTO source_info VALUES(?,?)',['complete_example_translations',json.dumps(info,ensure_ascii=False)])
                db.execute("UPDATE source_review SET message='일본어 連帯保険와 영어 delay insurance가 불일치. 영어와 배송 지연 문맥에 따라 지연 보험으로 잠정 번역. 일본어 원문 확인은 미완료.' WHERE entity_id='dfe344f4e2_1' AND issue_code='SOURCE_SENTENCE_CONFLICT'")
        result['examples_filled']=db.execute("SELECT COUNT(*) FROM examples WHERE COALESCE(text_ko,'')!=''").fetchone()[0]
    Path('reports/examples-translation-import.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(result)
