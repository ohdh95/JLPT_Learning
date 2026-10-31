import copy
import json
from pathlib import Path
import sqlite3
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from build_learning_order import EVIDENCE_PATH, POLICY_PATH, LEVELS, install, make_order, words

ROOT = Path(__file__).resolve().parents[2]


class LearningOrderTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.evidence = json.loads(EVIDENCE_PATH.read_text())
        cls.policy = json.loads(POLICY_PATH.read_text())

    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        with sqlite3.connect(ROOT/'assets/content.sqlite') as source:
            source.backup(self.db)
        self.db.execute('PRAGMA foreign_keys=ON')
        self.rows = words(self.db)

    def tearDown(self):
        self.db.close()

    def test_every_word_once_and_stages_in_requested_order(self):
        order = make_order(self.rows, self.evidence, self.policy)
        self.assertEqual(len(order), 7811)
        self.assertEqual({r['word_id'] for r in order}, {r['word_id'] for r in self.rows})
        for lv in LEVELS:
            group = [r for r in order if r['jlpt_level'] == lv]
            self.assertEqual([r['rank'] for r in group], list(range(1, len(group)+1)))
            self.assertEqual([r['stage'] for r in group], sorted(r['stage'] for r in group))
            self.assertEqual({r['stage'] for r in group}, {0, 1, 2})
            for stage in (0, 1, 2):
                values = [r['frequency_zipf'] for r in group if r['stage'] == stage]
                self.assertEqual(values, sorted(values, reverse=True))

    def test_n4_foundations_are_real_n5_ids(self):
        order = make_order(self.rows, self.evidence, self.policy)
        by_id = {r['word_id']: r for r in self.rows}
        for row in order:
            parents = json.loads(row['related_n5_json'])
            if row['jlpt_level'] == 'N4' and row['stage'] == 0:
                self.assertTrue(parents)
                self.assertTrue(all(by_id[p]['jlpt_level'] == 'N5' for p in parents))
        target = next(r for r in self.rows if r['surface'] == '乗り換える')
        row = next(r for r in order if r['word_id'] == target['word_id'])
        self.assertEqual(row['stage'], 0)
        self.assertIn('乗る', {by_id[p]['surface'] for p in json.loads(row['related_n5_json'])})

    def test_polysemy_and_ambiguous_surface_frequency_are_not_conflated(self):
        order = {r['word_id']: r for r in make_order(self.rows, self.evidence, self.policy)}
        for surface in ['奴', '機', '件', '代', '的']:
            target = next(r for r in self.rows if r['surface'] == surface and r['jlpt_level'] == 'N1')
            self.assertNotEqual(order[target['word_id']]['stage'], 0)
        for row in self.rows:
            evidence = self.evidence['entries'][row['word_id']]
            if evidence['all_senses_rare']:
                self.assertEqual(order[row['word_id']]['stage'], 2)
        self.assertFalse(self.evidence['human_reviewed'])

    def test_install_preserves_content_and_is_idempotent(self):
        tables = ['vocab', 'kanji', 'examples', 'validations', 'localization_provenance', 'kanji_components']
        before = {name: self.db.execute(f'SELECT * FROM {name} ORDER BY rowid').fetchall() for name in tables}
        install(self.db, self.evidence, self.policy)
        first = self.db.execute('SELECT * FROM word_learning_order ORDER BY word_id').fetchall()
        install(self.db, self.evidence, self.policy)
        self.assertEqual(first, self.db.execute('SELECT * FROM word_learning_order ORDER BY word_id').fetchall())
        for name in tables:
            self.assertEqual(before[name], self.db.execute(f'SELECT * FROM {name} ORDER BY rowid').fetchall(), name)
        self.assertEqual(self.db.execute('PRAGMA foreign_key_check').fetchall(), [])

    def test_invalid_snapshot_does_not_replace_ranks(self):
        before = self.db.execute('SELECT * FROM word_learning_order ORDER BY word_id').fetchall()
        bad = copy.deepcopy(self.evidence)
        bad['entries'][self.rows[0]['word_id']]['reading'] = 'invalid'
        with self.assertRaisesRegex(ValueError, 'Stale evidence'):
            install(self.db, bad, self.policy)
        self.assertEqual(before, self.db.execute('SELECT * FROM word_learning_order ORDER BY word_id').fetchall())

    def test_missing_evidence_falls_back_without_removing_words(self):
        order = make_order(self.rows, {'entries': {}}, self.policy)
        self.assertEqual(len(order), len(self.rows))
        self.assertTrue(all(r['stage'] == 2 and r['reason'] == 'evidence_missing' for r in order))
        self.assertEqual([r['word_id'] for r in order], [r['word_id'] for r in self.rows])


if __name__ == '__main__':
    unittest.main()
