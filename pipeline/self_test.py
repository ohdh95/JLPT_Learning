#!/usr/bin/env python3
"""Unit tests on an 8-word OpenJLPT fixture. Not full-data validation."""
from pathlib import Path
import json,sqlite3,subprocess,sys,tempfile
from xml.sax.saxutils import escape

ROOT=Path(__file__).resolve().parent

def run(*args):
    cmd=[sys.executable,*map(str,args)]
    p=subprocess.run(cmd,capture_output=True,text=True,check=True)
    return p.stdout

def main():
    with tempfile.TemporaryDirectory(prefix='jlpt-selftest-') as tmp:
        out=Path(tmp)
        dbfile=out/'content.sqlite'
        run(ROOT/'build_database.py','--source-dir',ROOT/'fixtures/tiny_openjlpt',
            '--allow-partial','--out',dbfile,'--progress-out',out/'progress.sqlite','--report',out/'import.json')
        db=sqlite3.connect(dbfile)
        assert db.execute('select count(*) from vocab').fetchone()[0]==8
        assert db.execute('select count(*) from kanji').fetchone()[0]==2
        assert db.execute('select count(*) from examples').fetchone()[0]==8
        assert db.execute('pragma integrity_check').fetchone()[0]=='ok'
        assert db.execute('pragma foreign_key_check').fetchall()==[]
        row=db.execute("select reading_kana from vocab where surface='会う'").fetchone()
        assert row[0]=='あう'
        worddata=db.execute('select surface,reading_kana,jmdict_id from vocab').fetchall()
        db.close()
        # A synthetic XML tests parser mechanics only, not source correctness.
        xml=['<?xml version="1.0" encoding="UTF-8"?><JMdict>']
        for surface,reading,entid in worddata:
            xml.append(f'<entry><ent_seq>{entid}</ent_seq><k_ele><keb>{escape(surface)}</keb></k_ele>'
                       f'<r_ele><reb>{escape(reading)}</reb></r_ele></entry>')
        xml.append('</JMdict>')
        fixture=out/'synthetic_test_only.xml'; fixture.write_text('\n'.join(xml),encoding='utf-8')
        run(ROOT/'verify_jmdict.py','--db',dbfile,'--jmdict',fixture,
            '--allow-tiny-test-fixture','--report',out/'jmdict_parser.json')
        assert json.loads((out/'jmdict_parser.json').read_text())['status']['direct_verified']==8
        run(ROOT/'audit_report.py','--db',dbfile,'--outdir',out/'audit')
        run(ROOT/'korean_localization.py','--db',dbfile,'--export',out/'localization')
        assert (out/'localization/word_meanings_review.csv').exists()
        assert (out/'audit/quality_summary.json').exists()
    print('PASS: 8-word import; integrity; selection prefs; synthetic JMdict parser; audit; Korean template export')
    print('NOTE: Only test fixtures validated. Real full JMdict XML and 7,811-word import not tested here.')

if __name__=='__main__': main()
