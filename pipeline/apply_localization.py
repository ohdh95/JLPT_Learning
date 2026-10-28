"""Apply curated drafts, never raw MT; exact-source duplicate propagation only.

Run from the project root after rebuilding OpenJLPT content. All imports remain
draft and previously human-reviewed fields are protected by the common importer.
"""
import argparse, json, sqlite3
from pathlib import Path
from localization_common import dump, read_jsonl, import_candidates, digest
from localize_hanja import add_word_components


def expand_examples(db, candidates):
    by_pair = {}
    for row in candidates:
        if row['method'] != 'assistant_ja_ko_review':
            raise ValueError('Raw machine translations are not approved for app import')
        source = row['source']
        pair = (source['text_ja'], source['text_en'])
        actual = db.execute('SELECT text_ja,text_en FROM examples WHERE example_id=?', [row['entity_id']]).fetchone()
        if actual is None or tuple(actual) != pair:
            raise ValueError(f"Example source changed: {row['entity_id']}")
        if pair in by_pair and by_pair[pair]['value'] != row['value']:
            raise ValueError('Conflicting translations for identical source pair')
        by_pair[pair] = row
    exact = {r['entity_id']:r for r in candidates}
    for eid, ja, en in db.execute('SELECT example_id,text_ja,text_en FROM examples'):
        if eid in exact or (ja,en) not in by_pair:
            continue
        row = by_pair[(ja,en)]
        exact[eid] = {**row, 'entity_id':eid,
            'propagated_from':row['entity_id'],
            'propagation_rule':'exact Japanese AND English text; no fuzzy matching'}
    return list(exact.values())


def apply(db, folder):
    words = read_jsonl(folder/'word_meanings_ko.jsonl')
    hanja = read_jsonl(folder/'hanja_candidates.jsonl')
    expected = {r[0] for r in db.execute('SELECT word_id FROM vocab')}
    if {r['entity_id'] for r in words} != expected or len(words) != len(expected):
        raise ValueError('Word candidate IDs must exactly cover this database')
    for row in words:
        source = row['source']
        actual = db.execute('SELECT surface,reading_kana,jlpt_level FROM vocab WHERE word_id=?', [row['entity_id']]).fetchone()
        if tuple(actual) != tuple(source[k] for k in ('surface','reading_kana','jlpt_level')):
            raise ValueError('Word source changed; re-review required')
    examples = expand_examples(db, read_jsonl(folder/'example_editorial_drafts.jsonl'))
    all_kanji = {r[0] for r in db.execute('SELECT character FROM kanji UNION SELECT character FROM word_kanji')}
    if {r['entity_id'] for r in hanja} != all_kanji or len(hanja) != len(all_kanji):
        raise ValueError('Hanja candidates must cover catalog AND word components')
    added = add_word_components(db)
    result = import_candidates(db, words + hanja + examples)
    result.update(words=len(words), hanja=len(hanja), examples=len(examples), supplemental_added=len(added))
    with db:
        # Preserve the original level uncertainty after supplying component hun/eum.
        db.execute("UPDATE source_review SET issue_code='SUPPLEMENTAL_KANJI_LEVEL_UNKNOWN', message=message||' — 훈음 보충 완료; OpenJLPT 한자 급수는 미지정' WHERE issue_code='CHAR_NOT_IN_OPENJLPT_KANJI_LIST'")
        for issue in json.loads((folder/'editorial_issues.json').read_text()):
            db.execute('INSERT OR REPLACE INTO source_review(entity_type,entity_id,field_name,severity,issue_code,message) VALUES(?,?,?,?,?,?)',
                [issue[k] for k in ('entity_type','entity_id','field_name','severity','issue_code','message')])
        info = {'date':'2026-10-28', 'word_drafts':len(words), 'hanja_drafts':len(hanja),
                'example_drafts':len(examples), 'human_review_completed':False,
                'raw_machine_examples_shipped':False,
                'method':'AI editorial translation and source comparison; independent human review pending',
                'candidate_sha256':{name:digest(folder/name) for name in
                    ['word_meanings_ko.jsonl','hanja_candidates.jsonl','example_editorial_drafts.jsonl','editorial_issues.json']}}
        db.execute('INSERT OR REPLACE INTO source_info VALUES(?,?)',['korean_localization_20261028', dump(info)])
    return result


if __name__ == '__main__':
    p=argparse.ArgumentParser();p.add_argument('--db',type=Path,required=True)
    p.add_argument('--candidates',type=Path,default=Path(__file__).parent/'localization')
    p.add_argument('--report',type=Path,default=Path('reports/localization-import.json'));a=p.parse_args()
    with sqlite3.connect(a.db) as db: result=apply(db,a.candidates)
    a.report.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(dump(result))
