#!/usr/bin/env python3
"""Import evidence for POS/sense, unofficial level, Japanese example editorial checks.

Reading segmentation must be reviewed separately; this tool never invents it.
"""
import argparse,csv,json,sqlite3
from pathlib import Path
from korean_localization import evidence_valid,EVIDENCE
FIELDS=('pos_sense','level_assignment','example_naturalness')
def main():
    p=argparse.ArgumentParser();p.add_argument('--db',type=Path,required=True)
    g=p.add_mutually_exclusive_group(required=True);g.add_argument('--export',type=Path);g.add_argument('--import-csv',type=Path);a=p.parse_args()
    with sqlite3.connect(a.db) as db:
        if a.export:
            with a.export.open('w',encoding='utf-8-sig',newline='') as f:
                w=csv.writer(f);w.writerow(['word_id','surface','reading','field_name']+EVIDENCE)
                for wid,s,r in db.execute('SELECT word_id,surface,reading_kana FROM vocab ORDER BY jlpt_level DESC,source_index'):
                    for field in FIELDS:w.writerow([wid,s,r,field,'','','','','','0'])
        else:
            with a.import_csv.open(encoding='utf-8-sig',newline='') as f:
                for row in csv.DictReader(f):
                    if row.get('field_name') not in FIELDS:raise ValueError('Unknown review field')
                    if not db.execute('SELECT 1 FROM vocab WHERE word_id=?',(row['word_id'],)).fetchone():raise ValueError('Unknown word ID')
                    if row.get('reviewed')!='1' or not evidence_valid(row):continue
                    # Keep each dated review as an additional provenance entry.
                    db.execute('INSERT OR REPLACE INTO validations VALUES(?,?,?,?,?,?)',(row['word_id'],row['field_name'],'human_reviewed','Editorial / '+row['reviewer']+' / '+row['reviewed_at'],row['reviewed_at'],json.dumps({k:row.get(k,'') for k in EVIDENCE},ensure_ascii=False)))
if __name__=='__main__':main()
