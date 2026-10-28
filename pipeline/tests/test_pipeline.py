import contextlib,csv,io,json,sqlite3,subprocess,sys,tempfile,unittest,zipfile
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from build_database import build_content,extract_zip,make_progress_db
from verify_jmdict import scan
from korean_localization import import_review,EVIDENCE
from release_gate import assess
ROOT=Path(__file__).resolve().parents[1]

class PipelineTest(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.path=Path(self.tmp.name);self.dbfile=self.path/'content.sqlite'
        with contextlib.redirect_stdout(io.StringIO()):build_content(ROOT/'fixtures/tiny_openjlpt/data/json',self.dbfile,self.path/'report.json',True)
        self.db=sqlite3.connect(self.dbfile)
    def tearDown(self):self.db.close();self.tmp.cleanup()
    def csv(self,kind,values):
        key={'word':'word_id','kanji':'character','example':'example_id'}[kind]
        value={'word':'meaning_ko','kanji':'korean_hun','example':'translation_ko'}[kind]
        p=self.path/(kind+'.csv')
        with p.open('w',encoding='utf-8',newline='') as f:
            w=csv.DictWriter(f,fieldnames=[key,value,'korean_eum']+EVIDENCE);w.writeheader();w.writerow(values)
        return p
    def test_integrity_and_unverified_defaults(self):
        self.assertEqual(self.db.execute('pragma integrity_check').fetchone()[0],'ok');self.assertEqual(self.db.execute('pragma foreign_key_check').fetchall(),[])
        self.assertEqual(self.db.execute('select count(*) from vocab').fetchone()[0],8)
        self.assertEqual(self.db.execute("select count(*) from vocab where korean_meaning_status='not_provided'").fetchone()[0],8)
        self.assertEqual(self.db.execute("select count(*) from sqlite_master where sql like '%fts5%'").fetchone()[0],0)
        self.assertFalse(assess(self.db)['release_ready'])
    def test_partial_rejected_and_previous_output_preserved(self):
        original=self.dbfile.read_bytes()
        with contextlib.redirect_stdout(io.StringIO()),self.assertRaises(ValueError):build_content(ROOT/'fixtures/tiny_openjlpt/data/json',self.dbfile,self.path/'report.json')
        self.assertEqual(self.dbfile.read_bytes(),original)
    def test_missing_files_do_not_replace_content(self):
        with self.assertRaises(FileNotFoundError):build_content(self.path,self.dbfile,self.path/'report.json')
        self.assertEqual(self.db.execute('select count(*) from vocab').fetchone()[0],8)
    def test_zip_traversal_rejected(self):
        p=self.path/'bad.zip'
        with zipfile.ZipFile(p,'w') as z:z.writestr('../escape','bad')
        with self.assertRaises(ValueError):extract_zip(p,self.path/'out')
        self.assertFalse((self.path.parent/'escape').exists())
        with zipfile.ZipFile(p,'w') as z:z.writestr('..\\escape','bad')
        with self.assertRaises(ValueError):extract_zip(p,self.path/'out')
    def test_progress_never_overwritten(self):
        p=self.path/'user.sqlite'
        with contextlib.redirect_stdout(io.StringIO()):make_progress_db(p)
        c=sqlite3.connect(p);c.execute("insert into selection values ('saved')");c.commit();c.close()
        before=p.read_bytes()
        with contextlib.redirect_stdout(io.StringIO()):make_progress_db(p)
        self.assertEqual(p.read_bytes(),before)
    def test_review_requires_independent_sources_reviewer_date_and_note(self):
        wid=self.db.execute('select word_id from vocab limit 1').fetchone()[0]
        r={'word_id':wid,'meaning_ko':'의미1; 의미2','reviewed':'1','reference_url':'https://example.org/one'}
        with contextlib.redirect_stdout(io.StringIO()):counts=import_review(self.db,self.csv('word',r),'word')
        self.assertEqual(counts['updated_verified'],0)
        r.update(cross_reference_url='https://independent.example/two',reviewer='fixture human',reviewed_at='2026-10-28',evidence_note='Synthetic test assertion only')
        with contextlib.redirect_stdout(io.StringIO()):counts=import_review(self.db,self.csv('word',r),'word')
        self.assertEqual(counts['updated_verified'],1)
        self.assertEqual(json.loads(self.db.execute('select meanings_ko_json from vocab where word_id=?',(wid,)).fetchone()[0]),['의미1','의미2'])
        self.assertEqual(self.db.execute('select count(*) from localization_history').fetchone()[0],2)
        self.assertFalse(assess(self.db)['release_ready'])
        r['cross_reference_url']='https://example.org/two'
        with contextlib.redirect_stdout(io.StringIO()):counts=import_review(self.db,self.csv('word',r),'word')
        self.assertEqual(counts['updated_draft'],1)
    def test_hanja_and_example_drafts_not_verified(self):
        ch=self.db.execute('select character from kanji limit 1').fetchone()[0];eid=self.db.execute('select example_id from examples limit 1').fetchone()[0]
        for kind,row in [('kanji',{'character':ch,'korean_hun':'테스트','korean_eum':'가','reviewed':'1'}),('example',{'example_id':eid,'translation_ko':'테스트 번역','reviewed':'1'})]:
            with contextlib.redirect_stdout(io.StringIO()):counts=import_review(self.db,self.csv(kind,row),kind)
            self.assertEqual(counts['updated_verified'],0)
    def test_jmdict_reading_restrictions(self):
        xml=self.path/'dict.xml';xml.write_text('<JMdict><entry><ent_seq>1</ent_seq><k_ele><keb>甲</keb></k_ele><k_ele><keb>乙</keb></k_ele><r_ele><reb>こう</reb><re_restr>甲</re_restr></r_ele></entry></JMdict>',encoding='utf-8')
        found,n=scan(xml,{('甲','こう'),('乙','こう')});self.assertEqual(n,1);self.assertEqual(found[('甲','こう')],{1});self.assertNotIn(('乙','こう'),found)
    def test_fixture_verification_cannot_certify_production(self):
        rows=self.db.execute('select surface,reading_kana,jmdict_id from vocab').fetchall();from xml.sax.saxutils import escape
        xml=self.path/'dict.xml';xml.write_text('<JMdict>'+''.join(f'<entry><ent_seq>{j}</ent_seq><k_ele><keb>{escape(s)}</keb></k_ele><r_ele><reb>{escape(r)}</reb></r_ele></entry>' for s,r,j in rows)+'</JMdict>',encoding='utf-8')
        cmd=[sys.executable,str(ROOT/'verify_jmdict.py'),'--db',str(self.dbfile),'--jmdict',str(xml),'--report',str(self.path/'comparison.json')]
        self.assertNotEqual(subprocess.run(cmd,capture_output=True).returncode,0)
        subprocess.run(cmd+['--allow-tiny-test-fixture'],check=True,capture_output=True)
        self.assertEqual(self.db.execute("select count(*) from vocab where reading_check='direct_jmdict_verified'").fetchone()[0],0)
        self.assertTrue(json.loads((self.path/'comparison.json').read_text())['fixture_only'])
    def test_full_shipped_data_matches_metadata_and_no_forged_localization(self):
        with sqlite3.connect(ROOT.parent/'assets/content.sqlite') as db:
            metadata=json.loads(db.execute("select value from source_info where key='openjlpt_meta'").fetchone()[0])
            for table,category in [('vocab','vocab'),('kanji','kanji')]:
                counts=dict(db.execute(f'select jlpt_level,count(*) from {table} where jlpt_level is not null group by jlpt_level'))
                self.assertEqual(counts,{k:v for k,v in metadata['counts'][category].items() if k!='total'})
            self.assertEqual(db.execute("select count(*) from vocab where korean_meaning_status='human_reviewed'").fetchone()[0],0)
            self.assertEqual(db.execute('pragma foreign_key_check').fetchall(),[])
            self.assertFalse(assess(db)['release_ready'])

if __name__=='__main__':unittest.main()
