import contextlib, io, json, sqlite3, sys, tempfile, unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from build_database import build_content
from localization_common import import_candidates, read_jsonl, validate_candidate
from localize_hanja import add_word_components
from apply_localization import expand_examples
from compare_jmdict_senses import compare
from apply_example_translations import merge
from review_all_examples import export_review, save as save_review

ROOT=Path(__file__).resolve().parents[1]

class LocalizationTest(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.path=Path(self.temp.name)
        with contextlib.redirect_stdout(io.StringIO()):
            build_content(ROOT/'fixtures/tiny_openjlpt/data/json', self.path/'db', self.path/'report', True)
        self.db=sqlite3.connect(self.path/'db')
        self.wid=self.db.execute('SELECT word_id FROM vocab LIMIT 1').fetchone()[0]
        self.row=dict(entity_type='word',entity_id=self.wid,value=['테스트 뜻'],method='assistant_editorial_translation',sources=['https://example.org/source'])
    def tearDown(self):
        self.db.close();self.temp.cleanup()
    def test_drafts_are_idempotent_and_human_review_is_protected(self):
        self.assertEqual(import_candidates(self.db,[self.row])['updated_draft'],1)
        self.assertEqual(import_candidates(self.db,[self.row])['unchanged'],1)
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM localization_history').fetchone()[0],1)
        self.db.execute("UPDATE vocab SET korean_meaning_status='human_reviewed' WHERE word_id=?",[self.wid]);self.db.commit()
        self.row['value']=['변경 시도']
        self.assertEqual(import_candidates(self.db,[self.row])['protected_human_review'],1)
        self.assertEqual(json.loads(self.db.execute('SELECT meanings_ko_json FROM vocab WHERE word_id=?',[self.wid]).fetchone()[0]),['테스트 뜻'])
    def test_false_certification_and_invalid_text_are_rejected(self):
        for override in [dict(reviewed=True),dict(status='human_reviewed'),dict(reviewer_type='human'),dict(value=['']),dict(value=['English only']),dict(value=['오류\ufffd'])]:
            with self.subTest(override=override),self.assertRaises(ValueError):validate_candidate({**self.row,**override})
        import_candidates(self.db,[self.row])
        evidence=json.loads(self.db.execute('SELECT evidence_json FROM localization_provenance').fetchone()[0])
        self.assertFalse(evidence['reviewed']);self.assertTrue(evidence['human_review_required'])
    def test_unknown_id_rolls_back_entire_batch(self):
        before=self.db.execute('SELECT meanings_ko_json,korean_meaning_status FROM vocab WHERE word_id=?',[self.wid]).fetchone()
        with self.assertRaises(ValueError):import_candidates(self.db,[self.row,{**self.row,'entity_id':'unknown'}])
        self.assertEqual(self.db.execute('SELECT meanings_ko_json,korean_meaning_status FROM vocab WHERE word_id=?',[self.wid]).fetchone(),before)
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM localization_history').fetchone()[0],0)
    def test_components_do_not_invent_level_or_readings(self):
        original=self.db.execute('SELECT * FROM vocab').fetchall()
        missing=self.db.execute('SELECT DISTINCT character FROM word_kanji WHERE character NOT IN (SELECT character FROM kanji)').fetchall()
        self.assertEqual(len(add_word_components(self.db)),len(missing))
        self.assertEqual(add_word_components(self.db),[])
        self.assertEqual(self.db.execute('SELECT * FROM vocab').fetchall(),original)
        for ch, in missing:
            self.assertEqual(self.db.execute('SELECT jlpt_level,onyomi_json,kunyomi_json FROM kanji WHERE character=?',[ch]).fetchone(),(None,'[]','[]'))
    def test_example_source_and_translation_conflicts_block_import(self):
        eid,ja,en=self.db.execute('SELECT example_id,text_ja,text_en FROM examples LIMIT 1').fetchone()
        row=dict(entity_type='example',entity_id=eid,value='번역 초안',method='assistant_ja_ko_review',sources=['https://example.org'],source=dict(text_ja=ja,text_en=en))
        self.assertTrue(expand_examples(self.db,[row]))
        for override in [dict(method='local_machine_translation_en_to_ko'),dict(source=dict(text_ja=ja+'변경',text_en=en))]:
            with self.assertRaises(ValueError):expand_examples(self.db,[{**row,**override}])
        with self.assertRaises(ValueError):expand_examples(self.db,[row,{**row,'value':'상충하는 번역'}])
    def test_shipped_coverage_and_provenance(self):
        with sqlite3.connect(ROOT.parent/'assets/content.sqlite') as db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM vocab WHERE COALESCE(meanings_ko_json,'[]')='[]'").fetchone()[0],0)
            self.assertEqual(db.execute("SELECT COUNT(*) FROM kanji WHERE COALESCE(korean_hun,'')='' OR COALESCE(korean_eum,'')=''").fetchone()[0],0)
            self.assertEqual(db.execute('SELECT COUNT(*) FROM kanji WHERE jlpt_level IS NULL').fetchone()[0],373)
            self.assertEqual(db.execute('SELECT COUNT(*) FROM word_kanji WHERE character NOT IN (SELECT character FROM kanji)').fetchone()[0],0)
            self.assertEqual(db.execute("SELECT COUNT(*) FROM localization_provenance WHERE method='local_machine_translation_en_to_ko'").fetchone()[0],0)
            for table,col in [('vocab','korean_meaning_status'),('kanji','korean_hun_eum_status'),('examples','korean_translation_status')]:
                self.assertEqual(db.execute(f"SELECT COUNT(*) FROM {table} WHERE {col}='human_reviewed'").fetchone()[0],0)
            self.assertEqual(db.execute("SELECT COUNT(*) FROM examples WHERE COALESCE(text_ko,'')!=''").fetchone()[0],13718)
            self.assertEqual(db.execute("SELECT COUNT(*) FROM localization_provenance WHERE entity_type='example' AND method='assistant_ja_ko_review'").fetchone()[0],13718)
            self.assertEqual(db.execute("SELECT text_ko FROM examples WHERE example_id='dfe344f4e2_1'").fetchone()[0],'화물 배송이 늦어질 경우에 대비한 특별 지연 보험이 있다.')
            manifest=json.loads(db.execute("SELECT value FROM source_info WHERE key='full_example_semantic_review'").fetchone()[0])
            self.assertEqual(manifest['reviewed_pairs'],12615)
            self.assertEqual(manifest['reviewed_examples'],13718)
            self.assertFalse(manifest['human_review_completed'])
            self.assertEqual(db.execute("SELECT COUNT(*) FROM source_review WHERE entity_id='dfe344f4e2_1' AND issue_code='SOURCE_SENTENCE_CONFLICT'").fetchone()[0],1)
            for filename in ['word_meanings_ko.jsonl','hanja_candidates.jsonl','example_editorial_drafts.jsonl']:
                for row in read_jsonl(ROOT/'localization'/filename):validate_candidate(row)
            for evidence, in db.execute('SELECT evidence_json FROM localization_provenance'):
                self.assertFalse(json.loads(evidence)['reviewed'])
    def test_sense_export_honors_reading_and_spelling_restrictions(self):
        self.db.execute("UPDATE vocab SET surface='甲',reading_kana='こう',jmdict_id=1 WHERE word_id=?",[self.wid])
        xml=self.path/'dict.xml'
        xml.write_text('<JMdict><entry><ent_seq>1</ent_seq>'
            '<sense><gloss>unrestricted</gloss></sense>'
            '<sense><stagk>甲</stagk><stagr>こう</stagr><gloss>matching</gloss></sense>'
            '<sense><stagk>乙</stagk><gloss>wrong spelling</gloss></sense>'
            '<sense><stagr>おつ</stagr><gloss>wrong reading</gloss></sense>'
            '</entry></JMdict>')
        result=compare(self.db,xml)
        row=next(r for r in result['rows'] if r['word_id']==self.wid)
        self.assertEqual([s['gloss'] for s in row['senses']],[['unrestricted'],['matching']])
        self.assertFalse(result['certifies_korean'])
    def test_complete_translation_import_requires_coverage_and_preserves_editorial_priority(self):
        folder=self.path/'candidates';folder.mkdir()
        rows=[dict(entity_type='example',entity_id=eid,value='자동 번역',method='google_en_ko_translation',sources=['https://example.org'],source=dict(text_ja=ja,text_en=en)) for eid,ja,en in self.db.execute('SELECT example_id,text_ja,text_en FROM examples')]
        def save(name,values):
            (folder/name).write_text(''.join(json.dumps(r,ensure_ascii=False)+'\n' for r in values))
        save('example_service_drafts.jsonl',rows[:-1])
        with self.assertRaisesRegex(ValueError,'coverage'):merge(self.db,folder)
        save('example_service_drafts.jsonl',rows)
        edited={**rows[0],'value':'직접 고친 번역','method':'assistant_ja_ko_review'}
        save('example_editorial_drafts.jsonl',[edited])
        result=merge(self.db,folder)
        self.assertEqual(next(r for r in result if r['entity_id']==rows[0]['entity_id'])['value'],'직접 고친 번역')
        rows[0]['source']['text_ja']+='changed';save('example_service_drafts.jsonl',rows)
        with self.assertRaisesRegex(ValueError,'Changed source'):merge(self.db,folder)

    def test_completed_review_overrides_old_drafts_and_import_is_idempotent(self):
        folder=self.path/'candidates';review_folder=folder/'full_review'
        review_folder.mkdir(parents=True)
        rows=[dict(entity_type='example',entity_id=eid,value='자동 번역',method='google_en_ko_translation',sources=['https://example.org'],source=dict(text_ja=ja,text_en=en)) for eid,ja,en in self.db.execute('SELECT example_id,text_ja,text_en FROM examples')]
        save_review(folder/'example_service_drafts.jsonl',rows)
        save_review(folder/'example_editorial_drafts.jsonl',[{**rows[0],'value':'이전 교정','method':'assistant_ja_ko_review'}])
        inputs=[dict(index=i+1,ja=r['source']['text_ja'],before=r['value'],examples=[dict(id=r['entity_id'],en=r['source']['text_en'],level='N5')]) for i,r in enumerate(rows)]
        decisions=[dict(index=r['index'],ja=r['ja'],before=r['before'],after='전체 검토 번역',decision='corrected',reviewer='Codex AI',human_reviewed=False,review_type='semantic and fluency review') for r in inputs]
        save_review(review_folder/'input.jsonl',inputs)
        save_review(review_folder/'decisions.jsonl',decisions)
        export_review(self.db,review_folder)
        merged=merge(self.db,folder)
        self.assertTrue(all(r['value']=='전체 검토 번역' for r in merged))
        self.assertEqual(import_candidates(self.db,merged)['updated_draft'],len(rows))
        history_count=self.db.execute('SELECT COUNT(*) FROM localization_history').fetchone()[0]
        self.assertEqual(import_candidates(self.db,merge(self.db,folder))['unchanged'],len(rows))
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM localization_history').fetchone()[0],history_count)
        eid=rows[0]['entity_id']
        self.db.execute("UPDATE examples SET text_ko='사람 검수 번역',korean_translation_status='human_reviewed' WHERE example_id=?",[eid]);self.db.commit()
        self.assertEqual(import_candidates(self.db,merged)['protected_human_review'],1)
        self.assertEqual(self.db.execute('SELECT text_ko FROM examples WHERE example_id=?',[eid]).fetchone()[0],'사람 검수 번역')

if __name__=='__main__':unittest.main()
