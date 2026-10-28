import contextlib
import io
import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import review_all_examples as review


class FullExampleReviewTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.folder = Path(self.temp.name)/'full_review'
        self.folder.mkdir()
        self.db = sqlite3.connect(':memory:')
        self.db.execute('CREATE TABLE examples(example_id TEXT PRIMARY KEY,text_ja TEXT,text_en TEXT)')
        self.db.executemany('INSERT INTO examples VALUES(?,?,?)', [
            ('a','猫です。','It is a cat.'), ('b','猫です。','A cat.'), ('c','犬です。','It is a dog.')])
        self.inputs = [dict(index=1,ja='猫です。',before='고양이다.',examples=[
            dict(id='a',en='It is a cat.',level='N5',tatoeba_id=1),
            dict(id='b',en='A cat.',level='N1',tatoeba_id=2)]),
            dict(index=2,ja='犬です。',before='개이다.',examples=[
            dict(id='c',en='It is a dog.',level='N4',tatoeba_id=3)])]
        self.decisions = [dict(index=r['index'],ja=r['ja'],before=r['before'],after=r['before'],
            decision='retained',reviewer='Codex AI',human_reviewed=False,
            review_type='Japanese source and Korean translation semantic/fluency review') for r in self.inputs]
        self.write()

    def tearDown(self):
        self.db.close()
        self.temp.cleanup()

    def write(self):
        review.save(self.folder/'input.jsonl',self.inputs)
        review.save(self.folder/'decisions.jsonl',self.decisions)

    def test_full_coverage_preserves_each_english_and_ai_evidence(self):
        self.decisions[0].update(after='고양이입니다.',decision='corrected')
        self.write()
        manifest=review.export_review(self.db,self.folder)
        rows,loaded=review.load_completed_review(self.db,self.folder)
        self.assertEqual(manifest,loaded)
        self.assertEqual((manifest['reviewed_pairs'],manifest['reviewed_examples'],manifest['changed_examples']),(2,3,2))
        self.assertEqual([r['source']['text_en'] for r in rows],['It is a cat.','A cat.','It is a dog.'])
        self.assertTrue(all(r['human_review_required'] for r in rows))
        self.assertFalse(manifest['human_review_completed'])
        self.assertEqual(review.build_candidates(self.db,self.folder),rows)

    def test_partial_or_duplicate_decisions_never_export(self):
        for decisions in [self.decisions[:-1],self.decisions+[self.decisions[0]]]:
            review.save(self.folder/'decisions.jsonl',decisions)
            with self.assertRaisesRegex(ValueError,'coverage'):
                review.export_review(self.db,self.folder)
            self.assertFalse((self.folder/'manifest.json').exists())
            self.assertFalse((self.folder.parent/'example_full_review.jsonl').exists())

    def test_changed_japanese_or_english_requires_new_review(self):
        for col in ['text_ja','text_en']:
            with self.db:
                self.db.execute(f'UPDATE examples SET {col}=? WHERE example_id=?',['changed','a'])
                with self.assertRaisesRegex(ValueError,'Changed source'):
                    review.build_candidates(self.db,self.folder)
                self.db.execute('UPDATE examples SET text_ja=?,text_en=? WHERE example_id=?',['猫です。','It is a cat.','a'])

    def test_missing_and_duplicate_source_ids_are_rejected(self):
        original=list(self.inputs[0]['examples'])
        for examples in [original[:1],original+[original[0]]]:
            self.inputs[0]['examples']=examples
            self.write()
            with self.assertRaises(ValueError):
                review.build_candidates(self.db,self.folder)

    def test_false_human_review_or_inconsistent_decision_is_rejected(self):
        original=dict(self.decisions[0])
        for change in [dict(human_reviewed=True),dict(reviewer='Human'),dict(after='수정문',decision='retained'),dict(before='다른 원문')]:
            self.decisions[0]={**original,**change}
            self.write()
            with self.assertRaises(ValueError):
                review.build_candidates(self.db,self.folder)

    def test_manifest_prevents_silent_output_and_count_changes(self):
        review.export_review(self.db,self.folder)
        out=self.folder.parent/'example_full_review.jsonl'
        rows=review.read(out)
        rows[0]['value']='몰래 수정'
        review.save(out,rows)
        with self.assertRaisesRegex(ValueError,'hash mismatch'):
            review.load_completed_review(self.db,self.folder)
        review.export_review(self.db,self.folder)
        manifest=json.loads((self.folder/'manifest.json').read_text())
        manifest['changed_pairs']=999
        (self.folder/'manifest.json').write_text(json.dumps(manifest))
        with self.assertRaisesRegex(ValueError,'count mismatch'):
            review.load_completed_review(self.db,self.folder)

    def test_amendments_preserve_previous_decisions(self):
        with patch.object(review,'FOLDER',self.folder),patch('sys.stdin',io.StringIO('1|고양이입니다.\n')),contextlib.redirect_stdout(io.StringIO()):
            review.amend(self.inputs)
        item=review.read(self.folder/'decisions.jsonl')[0]
        self.assertEqual(item['amendments'][0]['previous_after'],'고양이다.')
        self.assertFalse(item['amendments'][0]['human_reviewed'])
        self.assertEqual(item['after'],'고양이입니다.')

    def test_source_issues_follow_all_exact_ids_and_block_changed_snapshot(self):
        issue=dict(index=1,ja='猫です。',examples=self.inputs[0]['examples'],issue='문맥 확인 필요',
            human_reviewed=False,status='needs_source_review')
        review.save(self.folder/'source_issues.jsonl',[issue])
        rows=review.build_candidates(self.db,self.folder)
        self.assertEqual([r['entity_id'] for r in rows if r.get('source_issue')],['a','b'])
        issue['ja']='changed'
        review.save(self.folder/'source_issues.jsonl',[issue])
        with self.assertRaisesRegex(ValueError,'snapshot changed'):
            review.build_candidates(self.db,self.folder)


if __name__=='__main__':
    unittest.main()
