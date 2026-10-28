#!/usr/bin/env python3
"""Audit completeness and provenance of JLPT content DB. Does not certify correctness."""
import argparse,csv,json,sqlite3
from collections import Counter
from pathlib import Path


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--db',type=Path,required=True)
    p.add_argument('--outdir',type=Path,default=Path('audit'))
    args=p.parse_args()
    args.outdir.mkdir(parents=True,exist_ok=True)
    db=sqlite3.connect(args.db)
    db.row_factory=sqlite3.Row
    metrics={
        'words': db.execute('SELECT COUNT(*) FROM vocab').fetchone()[0],
        'kanji': db.execute('SELECT COUNT(*) FROM kanji').fetchone()[0],
        'kanji_catalog': db.execute('SELECT COUNT(*) FROM kanji WHERE jlpt_level IS NOT NULL').fetchone()[0],
        'kanji_supplemental': db.execute('SELECT COUNT(*) FROM kanji WHERE jlpt_level IS NULL').fetchone()[0],
        'examples': db.execute('SELECT COUNT(*) FROM examples').fetchone()[0],
        'direct_jmdict_verified':db.execute("SELECT COUNT(*) FROM vocab WHERE reading_check='direct_jmdict_verified'").fetchone()[0],
        'upstream_jmdict_linked_only':db.execute("SELECT COUNT(*) FROM vocab WHERE reading_check='upstream_jmdict_linked'").fetchone()[0],
        'korean_word_meaning_reviewed':db.execute("SELECT COUNT(*) FROM vocab WHERE korean_meaning_status='human_reviewed'").fetchone()[0],
        'korean_hanja_reviewed':db.execute("SELECT COUNT(*) FROM kanji WHERE korean_hun_eum_status='human_reviewed'").fetchone()[0],
        'korean_examples_reviewed':db.execute("SELECT COUNT(*) FROM examples WHERE korean_translation_status='human_reviewed'").fetchone()[0],
        'korean_word_meaning_filled':db.execute("SELECT COUNT(*) FROM vocab WHERE COALESCE(meanings_ko_json,'[]')!='[]'").fetchone()[0],
        'korean_hanja_filled':db.execute("SELECT COUNT(*) FROM kanji WHERE COALESCE(korean_hun,'')!='' AND COALESCE(korean_eum,'')!=''").fetchone()[0],
        'korean_examples_filled':db.execute("SELECT COUNT(*) FROM examples WHERE COALESCE(text_ko,'')!=''").fetchone()[0],
        'word_components_missing_huneum':db.execute("SELECT COUNT(*) FROM word_kanji w LEFT JOIN kanji k ON k.character=w.character WHERE COALESCE(k.korean_hun,'')='' OR COALESCE(k.korean_eum,'')=''").fetchone()[0],
        'source_review_issues':db.execute('SELECT COUNT(*) FROM source_review').fetchone()[0],
        'sql_integrity':db.execute('PRAGMA integrity_check').fetchone()[0],
        'foreign_key_errors':len(db.execute('PRAGMA foreign_key_check').fetchall()),
    }
    metrics['vocab_by_level']={r[0]:r[1] for r in db.execute('SELECT jlpt_level,COUNT(*) FROM vocab GROUP BY jlpt_level ORDER BY jlpt_level')}
    metrics['kanji_by_level']={r[0]:r[1] for r in db.execute('SELECT jlpt_level,COUNT(*) FROM kanji WHERE jlpt_level IS NOT NULL GROUP BY jlpt_level ORDER BY jlpt_level')}
    metrics['korean_meanings_by_level']={r[0]:r[1] for r in db.execute("SELECT jlpt_level,COUNT(*) FROM vocab WHERE COALESCE(meanings_ko_json,'[]')!='[]' GROUP BY jlpt_level ORDER BY jlpt_level")}
    metrics['korean_examples_by_level']={r[0]:r[1] for r in db.execute("SELECT v.jlpt_level,COUNT(*) FROM examples e JOIN vocab v USING(word_id) WHERE COALESCE(e.text_ko,'')!='' GROUP BY v.jlpt_level ORDER BY v.jlpt_level")}
    if db.execute("SELECT 1 FROM sqlite_master WHERE name='localization_provenance'").fetchone():
        metrics['hanja_unihan_reading_comparison']=dict(Counter(json.loads(r[0]).get('reading_crosscheck','not_available') for r in db.execute("SELECT evidence_json FROM localization_provenance WHERE entity_type='kanji'")))
        metrics['localization_methods']={r[0]:r[1] for r in db.execute('SELECT method,COUNT(*) FROM localization_provenance GROUP BY method')}
    metrics['status']='incomplete_localization' if (
      metrics['korean_word_meaning_reviewed'] < metrics['words'] or
      metrics['korean_hanja_reviewed'] < metrics['kanji'] or
      metrics['korean_examples_reviewed'] < metrics['examples']) else 'ready_for_final_editorial_qa'
    if (metrics['status']=='incomplete_localization' and
        metrics['korean_word_meaning_filled']==metrics['words'] and
        metrics['korean_hanja_filled']==metrics['kanji'] and
        metrics['korean_examples_filled']==metrics['examples']):
        metrics['status']='translation_filled_review_pending'
    out=args.outdir/'quality_summary.json'
    out.write_text(json.dumps(metrics,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    with (args.outdir/'word_review.csv').open('w',encoding='utf-8-sig',newline='') as f:
        wr=csv.writer(f);wr.writerow(['level','word_id','surface','reading','reading_status','korean_meaning_status','english_glosses','jmdict_id','hanja_alignment_verified'])
        q='''SELECT v.jlpt_level,v.word_id,v.surface,v.reading_kana,v.reading_check,v.korean_meaning_status,v.gloss_en_json,v.jmdict_id,
              NOT EXISTS (SELECT 1 FROM word_kanji AS wk WHERE wk.word_id=v.word_id AND wk.reading_alignment_status!='verified') AS alignment_verified
              FROM vocab AS v ORDER BY CASE v.jlpt_level WHEN 'N5' THEN 1 WHEN 'N4' THEN 2 WHEN 'N3' THEN 3 WHEN 'N2' THEN 4 ELSE 5 END,v.source_index'''
        wr.writerows(db.execute(q))
    with (args.outdir/'issues.csv').open('w',encoding='utf-8-sig',newline='') as f:
        wr=csv.writer(f);wr.writerow(['entity_type','entity_id','field_name','severity','issue_code','message'])
        wr.writerows(db.execute('SELECT entity_type,entity_id,field_name,severity,issue_code,message FROM source_review ORDER BY severity DESC,entity_type'))
    print(json.dumps(metrics,ensure_ascii=False,indent=2))
    db.close()

if __name__=='__main__':main()
