import json,sqlite3,sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from build_example_links import utf16

DB=Path(__file__).resolve().parents[2]/'assets/content.sqlite'
class ExampleLinkTest(unittest.TestCase):
    def test_shipped_links_preserve_utf16_boundaries_without_dangling_ids(self):
        with sqlite3.connect(DB) as db:
            self.assertEqual(db.execute('PRAGMA foreign_key_check').fetchall(),[])
            rows=db.execute('SELECT e.text_ja,l.example_id,l.start_offset,l.end_offset,l.word_id FROM example_word_links l JOIN examples e USING(example_id) ORDER BY l.example_id,l.start_offset,l.end_offset').fetchall()
            self.assertGreater(len(rows),60000)
            previous=None
            for text,eid,start,end,wid in rows:
                encoded=text.encode('utf-16-le');self.assertGreater(end,start);self.assertLessEqual(end,utf16(text))
                self.assertTrue(encoded[start*2:end*2].decode('utf-16-le'))
                if previous and previous[0]==eid and previous[1]!=start:self.assertGreaterEqual(start,previous[2])
                previous=(eid,start,end)
    def test_real_conjugated_forms_and_compounds_have_expected_targets(self):
        with sqlite3.connect(DB) as db:
            rows=db.execute("SELECT e.text_ja,l.start_offset,l.end_offset,v.surface FROM example_word_links l JOIN examples e USING(example_id) JOIN vocab v ON v.word_id=l.word_id WHERE e.text_ja='ジョージは朝にたくさんのチーズを食べた。'").fetchall()
            forms={text.encode('utf-16-le')[start*2:end*2].decode('utf-16-le'):surface for text,start,end,surface in rows}
            self.assertEqual(forms['食べ'],'食べる');self.assertEqual(forms['チーズ'],'チーズ')
            rows=db.execute("SELECT l.match_form FROM example_word_links l JOIN examples e USING(example_id) WHERE e.text_ja='明日はピクニックに行くつもりだ。' AND l.start_offset<2").fetchall()
            self.assertTrue(rows);self.assertTrue(all(r[0]=='明日' for r in rows))
            self.assertEqual(utf16('😀明日'),4)

if __name__=='__main__':unittest.main()
