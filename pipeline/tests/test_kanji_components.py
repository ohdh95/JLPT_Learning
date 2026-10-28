import json
from pathlib import Path
import sqlite3
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from build_kanji_components import decompose, install, validate

ROOT = Path(__file__).resolve().parents[2]


def svg(body, character='休'):
    return f'''<svg xmlns:kvg="http://kanjivg.tagaini.net"><g
        id="kvg:{ord(character):05x}" kvg:element="{character}">{body}</g></svg>'''


class KanjiComponentsTest(unittest.TestCase):
    def test_variant_and_basic(self):
        xml = svg('<g kvg:element="亻" kvg:original="人"><path/></g>'
                  '<g kvg:element="木"><path/></g>')
        parts, status = decompose(xml, '休')
        self.assertEqual(status, 'components')
        self.assertEqual([p['original'] for p in parts], ['人', '木'])
        self.assertEqual(decompose(svg('<g kvg:element="十"/>', '木'), '木'), ([], 'basic'))

    def test_complete_coverage_required(self):
        parts, status = decompose(svg('<g kvg:element="木"><path/></g><path/>'), '休')
        self.assertEqual(parts, [])
        self.assertEqual(status, 'no_complete_grouping')

    def test_split_groups_merge_but_repeated_components_do_not(self):
        parts, _ = decompose(svg('<g kvg:element="行" kvg:part="1"/>'
                                 '<g kvg:element="圭"/>'
                                 '<g kvg:element="行" kvg:part="2"/>', '街'), '街')
        self.assertEqual([p['glyph'] for p in parts], ['行', '圭'])
        parts, _ = decompose(svg('<g kvg:element="木"/><g kvg:element="木"/>', '林'), '林')
        self.assertEqual([p['glyph'] for p in parts], ['木', '木'])
        parts, status = decompose(svg('<g kvg:element="行" kvg:part="1"/>'
                                     '<g kvg:element="圭"/>', '街'), '街')
        self.assertEqual(parts, [])
        self.assertEqual(status, 'incomplete_split_group')

    def test_unknown_and_cyclic_links_rejected(self):
        def part(glyph, target):
            return dict(glyph=glyph,target=target,partial=False)
        with self.assertRaisesRegex(ValueError, 'Dangling'):
            validate(dict(supplements={},entries={'休':[part('人','人'),part('木','木')]}), {'休','人'})
        with self.assertRaisesRegex(ValueError, 'cycle'):
            validate(dict(supplements={},entries={
                '休':[part('人','人'),part('木','木')],
                '人':[part('休','休'),part('木','木')]}), {'休','人','木'})

    def test_shipped_snapshot_references_statuses_and_foreign_keys(self):
        data = json.loads((ROOT/'pipeline/data/kanji_components.json').read_text())
        with sqlite3.connect(ROOT/'assets/content.sqlite') as db:
            validate(data,{r[0] for r in db.execute('SELECT character FROM kanji')})
            self.assertFalse(data['human_reviewed'])
            self.assertEqual(db.execute('PRAGMA foreign_key_check').fetchall(), [])
            for ch in '人木日月口金中':
                self.assertEqual(db.execute('SELECT COUNT(*) FROM kanji_components WHERE character=?',[ch]).fetchone()[0],0)
            self.assertEqual(db.execute("SELECT target_character FROM kanji_components WHERE character='海' ORDER BY sequence LIMIT 1").fetchone()[0], '水')
            for ch in data['supplements']:
                row = db.execute('SELECT jlpt_level,korean_hun_eum_status FROM kanji WHERE character=?',[ch]).fetchone()
                self.assertEqual(row, (None, 'draft'))

    def test_reapply_preserves_other_content_and_is_idempotent(self):
        data = json.loads((ROOT/'pipeline/data/kanji_components.json').read_text())
        with sqlite3.connect(ROOT/'assets/content.sqlite') as source, sqlite3.connect(':memory:') as db:
            source.backup(db)
            db.execute('PRAGMA foreign_keys=ON')
            old_kanji = db.execute('SELECT * FROM kanji ORDER BY character').fetchall()
            old_words = db.execute('SELECT * FROM vocab ORDER BY word_id').fetchall()
            before = db.execute('SELECT * FROM kanji_components ORDER BY character,sequence').fetchall()
            install(db,data)
            install(db,data)
            self.assertEqual(db.execute('SELECT * FROM kanji ORDER BY character').fetchall(), old_kanji)
            self.assertEqual(db.execute('SELECT * FROM vocab ORDER BY word_id').fetchall(), old_words)
            self.assertEqual(db.execute('SELECT * FROM kanji_components ORDER BY character,sequence').fetchall(), before)


if __name__ == '__main__':
    unittest.main()
