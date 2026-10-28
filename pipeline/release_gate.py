#!/usr/bin/env python3
"""Report editorial readiness; --strict exits nonzero for any unfinished word."""
import argparse,json,sqlite3
from pathlib import Path

def assess(db):
    total=db.execute('SELECT COUNT(*) FROM vocab').fetchone()[0]
    ready=db.execute('''SELECT COUNT(*) FROM vocab v WHERE
      v.reading_check='direct_jmdict_verified' AND v.korean_meaning_status='human_reviewed'
      AND EXISTS(SELECT 1 FROM validations x WHERE x.word_id=v.word_id AND x.field_name='pos_sense' AND x.status='human_reviewed')
      AND EXISTS(SELECT 1 FROM validations x WHERE x.word_id=v.word_id AND x.field_name='level_assignment' AND x.status='human_reviewed')
      AND NOT EXISTS(SELECT 1 FROM word_kanji wk LEFT JOIN kanji k ON k.character=wk.character
        WHERE wk.word_id=v.word_id AND (k.character IS NULL OR k.korean_hun_eum_status!='human_reviewed'
          OR wk.reading_alignment_status NOT IN ('verified','whole_word_only_reviewed')))
      AND EXISTS(SELECT 1 FROM examples e WHERE e.word_id=v.word_id)
      AND NOT EXISTS(SELECT 1 FROM examples e WHERE e.word_id=v.word_id AND e.korean_translation_status!='human_reviewed')
      AND EXISTS(SELECT 1 FROM validations x WHERE x.word_id=v.word_id AND x.field_name='example_naturalness' AND x.status='human_reviewed')
    ''').fetchone()[0]
    return {'words':total,'release_ready_words':ready,'pending_words':total-ready,
      'release_ready':total>0 and ready==total,'mode':'working_preview',
      'limitations':'Dictionary pair matches do not certify Korean, sense/POS, JLPT assignment or examples. Reviewed metadata records human assertions with evidence, not automatic factual certification.'}

def main():
    p=argparse.ArgumentParser();p.add_argument('--db',type=Path,required=True);p.add_argument('--report',type=Path,default=Path('reports/release_gate.json'));p.add_argument('--strict',action='store_true');a=p.parse_args()
    with sqlite3.connect(a.db) as db:r=assess(db)
    a.report.parent.mkdir(parents=True,exist_ok=True);a.report.write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps(r,ensure_ascii=False,indent=2))
    if a.strict and not r['release_ready']:raise SystemExit(2)
if __name__=='__main__':main()
