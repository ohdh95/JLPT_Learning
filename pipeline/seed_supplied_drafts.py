#!/usr/bin/env python3
"""Transfer only provided Korean drafts by exact spelling/reading; never certify them."""
import argparse,csv,json,sqlite3,tempfile
from pathlib import Path
from korean_localization import import_review,EVIDENCE

def main():
    p=argparse.ArgumentParser();p.add_argument('--db',type=Path,required=True);p.add_argument('--sample-db',type=Path,required=True);a=p.parse_args()
    source=sqlite3.connect(a.sample_db);db=sqlite3.connect(a.db)
    with tempfile.TemporaryDirectory() as tmp:
        tmp=Path(tmp)
        with (tmp/'words.csv').open('w',encoding='utf-8',newline='') as f:
            w=csv.writer(f);w.writerow(['word_id','meaning_ko']+EVIDENCE)
            for surface,reading,meaning in source.execute('SELECT surface,reading_kana,meaning_ko FROM words'):
                for wid, in db.execute('SELECT word_id FROM vocab WHERE surface=? AND reading_kana=?',(surface,reading)):
                    w.writerow([wid,meaning,'','','','','User-supplied v1.4 sample; independent Korean verification pending','0'])
        with (tmp/'kanji.csv').open('w',encoding='utf-8',newline='') as f:
            w=csv.writer(f);w.writerow(['character','korean_hun','korean_eum']+EVIDENCE)
            for row in source.execute('SELECT character,korean_hun,korean_eum FROM kanji'):
                w.writerow([*row,'','','','','User-supplied v1.4 sample; independent hanja verification pending','0'])
        result={k:import_review(db,tmp/file,k) for k,file in [('word','words.csv'),('kanji','kanji.csv')]}
        print(json.dumps(result,ensure_ascii=False,indent=2))
    source.close();db.close()
if __name__=='__main__':main()
