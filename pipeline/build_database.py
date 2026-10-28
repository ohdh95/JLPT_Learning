#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""OpenJLPT N5-N1 -> Korean JLPT app SQLite working content DB.

From a downloaded OpenJLPT repository (or automatically download its zip).
Requires Python 3.9+ standard library only.
"""
from __future__ import annotations
import argparse
from collections import Counter
from datetime import date
import csv
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import os
import sqlite3
import tempfile
from urllib.request import Request, urlopen
import zipfile

LEVELS = ('n5', 'n4', 'n3', 'n2', 'n1')
ROOT_URL = 'https://github.com/evanclan/OpenJLPT'
LICENSE_URL = 'https://creativecommons.org/licenses/by-sa/4.0/'
DEFAULT_REF = 'main'
EXPECTED = {'N5': 674, 'N4': 630, 'N3': 1659, 'N2': 1778, 'N1': 3070}
K_EXPECTED = {'N5': 84, 'N4': 169, 'N3': 387, 'N2': 398, 'N1': 1345}
DDL = '''
PRAGMA foreign_keys=ON;
CREATE TABLE source_info(key TEXT PRIMARY KEY,value TEXT NOT NULL);
CREATE TABLE vocab(
 word_id TEXT PRIMARY KEY, surface TEXT NOT NULL, reading_kana TEXT NOT NULL,
 romaji TEXT, jlpt_level TEXT NOT NULL CHECK(jlpt_level IN ('N5','N4','N3','N2','N1')),
 source_index INTEGER NOT NULL, gloss_en_json TEXT NOT NULL, meanings_ko_json TEXT,
 korean_meaning_status TEXT NOT NULL DEFAULT 'not_provided',
 pos_codes_json TEXT NOT NULL, jmdict_id INTEGER, reading_check TEXT NOT NULL,
 other_forms_json TEXT NOT NULL DEFAULT '[]', other_readings_json TEXT NOT NULL DEFAULT '[]',
 UNIQUE(surface,reading_kana,jlpt_level)
);
CREATE INDEX vocab_level_idx ON vocab(jlpt_level,source_index);
CREATE INDEX vocab_surface_idx ON vocab(surface,reading_kana);
CREATE TABLE kanji(
 character TEXT PRIMARY KEY, jlpt_level TEXT,
 onyomi_json TEXT NOT NULL, kunyomi_json TEXT NOT NULL, meanings_en_json TEXT NOT NULL,
 korean_hun TEXT, korean_eum TEXT, korean_hun_eum_status TEXT NOT NULL DEFAULT 'not_provided',
 strokes INTEGER, radical TEXT
);
CREATE TABLE kanji_components(
 character TEXT NOT NULL REFERENCES kanji(character), sequence INTEGER NOT NULL,
 glyph TEXT NOT NULL, target_character TEXT REFERENCES kanji(character),
 label_ko TEXT NOT NULL DEFAULT '', position TEXT NOT NULL DEFAULT '',
 is_partial INTEGER NOT NULL CHECK(is_partial IN (0,1)), source_group TEXT NOT NULL,
 PRIMARY KEY(character,sequence)
);
CREATE TABLE word_kanji(
 word_id TEXT NOT NULL REFERENCES vocab(word_id), character TEXT NOT NULL,
 surface_pos INTEGER NOT NULL, reading_in_word TEXT,
 reading_alignment_status TEXT NOT NULL DEFAULT 'not_verified',
 PRIMARY KEY(word_id,surface_pos)
);
CREATE INDEX word_kanji_char_idx ON word_kanji(character);
CREATE TABLE examples(
 example_id TEXT PRIMARY KEY, word_id TEXT NOT NULL REFERENCES vocab(word_id),
 sequence INTEGER NOT NULL, text_ja TEXT NOT NULL, furigana_markup TEXT,
 text_en TEXT, text_ko TEXT, korean_translation_status TEXT NOT NULL DEFAULT 'not_provided',
 tatoeba_id INTEGER, UNIQUE(word_id,sequence)
);
CREATE INDEX examples_word_idx ON examples(word_id,sequence);
CREATE TABLE example_word_links(
 example_id TEXT NOT NULL REFERENCES examples(example_id) ON DELETE CASCADE,
 start_offset INTEGER NOT NULL, end_offset INTEGER NOT NULL,
 word_id TEXT NOT NULL REFERENCES vocab(word_id) ON DELETE CASCADE,
 match_form TEXT NOT NULL,
 PRIMARY KEY(example_id,start_offset,end_offset,word_id)
);
CREATE INDEX example_links_word ON example_word_links(word_id);
CREATE TABLE validations(
 word_id TEXT NOT NULL REFERENCES vocab(word_id), field_name TEXT NOT NULL,
 status TEXT NOT NULL, reference_name TEXT NOT NULL, checked_at TEXT,
 note TEXT, PRIMARY KEY(word_id,field_name,reference_name)
);
CREATE TABLE source_review(
 issue_id INTEGER PRIMARY KEY AUTOINCREMENT, entity_type TEXT NOT NULL,
 entity_id TEXT NOT NULL, field_name TEXT NOT NULL,
 severity TEXT NOT NULL, issue_code TEXT NOT NULL, message TEXT NOT NULL,
 UNIQUE(entity_type,entity_id,field_name,issue_code)
);
CREATE TABLE IF NOT EXISTS content_revision(revision TEXT NOT NULL, built_at TEXT NOT NULL);
'''
PROGRESS_DDL = '''
PRAGMA foreign_keys=ON;
CREATE TABLE user_word_state(
 word_id TEXT PRIMARY KEY, is_starred INTEGER NOT NULL DEFAULT 0,
 last_rating TEXT CHECK(last_rating IN ('unknown','uncertain','known')),
 last_tested_at TEXT, tested_count INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE selection(word_id TEXT PRIMARY KEY);
CREATE TABLE preferences(pref_key TEXT PRIMARY KEY, json_value TEXT NOT NULL);
CREATE TABLE test_sessions(
 session_id TEXT PRIMARY KEY, started_at TEXT NOT NULL, completed_at TEXT,
 shuffled_word_ids_json TEXT NOT NULL, current_index INTEGER NOT NULL DEFAULT 0,
 status TEXT NOT NULL DEFAULT 'in_progress'
);
CREATE TABLE test_responses(
 session_id TEXT NOT NULL REFERENCES test_sessions(session_id), word_id TEXT NOT NULL,
 rating TEXT NOT NULL CHECK(rating IN ('unknown','uncertain','known')),
 answered_at TEXT NOT NULL, PRIMARY KEY(session_id,word_id)
);
'''
VIS = ('reading','meaning','part_of_speech','korean_hun','korean_eum','kanji_reading','jlpt_level','example','translation')


def is_kanji(ch: str) -> bool:
    n = ord(ch)
    return (0x3400 <= n <= 0x9fff) or (0x20000 <= n <= 0x3134f) or (0xf900 <= n <= 0xfaff)


def j(v):
    return json.dumps(v, ensure_ascii=False, separators=(',', ':'))


def download_repo(ref: str, output: Path):
    """Download official repository archive: no website scraping."""
    url = f'https://codeload.github.com/evanclan/OpenJLPT/zip/{ref}'
    req = Request(url, headers={'User-Agent':'JLPT-local-db-import/1.0'})
    print('Downloading original OpenJLPT repository archive:', url, flush=True)
    with urlopen(req, timeout=150) as resp, output.open('wb') as dst:
        shutil.copyfileobj(resp, dst)
    print('Downloaded', output.stat().st_size, 'bytes')


def extract_zip(src: Path, directory: Path):
    with zipfile.ZipFile(src) as z:
        infos = z.infolist()
        if sum(v.file_size for v in infos) > 350_000_000:
            raise ValueError('Archive expands beyond 350 MB; refuse potentially malicious zip')
        for item in infos:
            name = PurePosixPath(item.filename.replace('\\','/'))
            if name.is_absolute() or '..' in name.parts or (name.parts and ':' in name.parts[0]):
                raise ValueError('Unsafe zip member')
            if item.file_size > 70_000_000:
                raise ValueError('Single zip member too large')
        z.extractall(directory)
    # Github source ZIPs have a root directory; data-only ZIPs may not.
    # locate_json() discovers either layout below the extract root.
    return directory


def locate_json(source: Path) -> Path:
    for candidate in (source / 'data/json', source / 'json', source):
        if (candidate/'vocab/n5.json').is_file() and (candidate/'kanji/n5.json').is_file():
            return candidate
    candidates = [x.parent.parent for x in source.rglob('vocab/n5.json')]
    candidates = [x for x in candidates if (x/'kanji/n5.json').is_file()]
    if len(candidates) == 1:
        return candidates[0]
    raise FileNotFoundError(f'Expected one OpenJLPT JSON data root under {source}; found {len(candidates)}')


def fetch_json_data(root: Path):
    voc, kan = [], []
    for lvl in LEVELS:
        for name, output in [('vocab',voc), ('kanji',kan)]:
            f=root/name/f'{lvl}.json'
            if not f.exists(): raise FileNotFoundError(f'Missing {f}')
            data=json.loads(f.read_text('utf-8'))
            if not isinstance(data,list): raise ValueError(f'Not a list: {f}')
            for item in data:
                if item.get('level','').upper()!=lvl.upper():
                    raise ValueError(f'Incorrect JLPT level in {f}: {item}')
            output.extend(data)
    return voc, kan


def validate_source(voc,kan,allow_partial=False):
    wordids=[v['id'] for v in voc]
    chars=[v['character'] for v in kan]
    if len(set(wordids))!=len(wordids): raise ValueError('Duplicate stable IDs in OpenJLPT vocab')
    if len(set(chars))!=len(chars): raise ValueError('Duplicate kanji characters in source')
    if any(not x['word'] or not x['reading'] for x in voc): raise ValueError('Missing word or kana reading')
    counts=Counter(x['level'] for x in voc)
    kcounts=Counter(x['level'] for x in kan)
    print('Source counts: vocab',dict(counts),'kanji',dict(kcounts), flush=True)
    for lv,qty in EXPECTED.items():
        if counts[lv] != qty:
            print(f'  NOTE: {lv} vocab count changed vs original README ({qty} -> {counts[lv]}).')
    for lv,qty in K_EXPECTED.items():
        if kcounts[lv] != qty:
            print(f'  NOTE: {lv} kanji count changed vs original README ({qty} -> {kcounts[lv]}).')
    if not allow_partial:
        too_small=[lv for lv in EXPECTED if counts[lv]<EXPECTED[lv]*0.9 or kcounts[lv]<K_EXPECTED[lv]*0.9]
        if too_small:
            raise ValueError(f'Incomplete source: less than 90% of expected words/kanji for {too_small}. Use --allow-partial only for local tests.')
    return counts, kcounts


def sha_data(root:Path)->str:
    h=hashlib.sha256()
    for lvl in LEVELS:
        for category in ('vocab','kanji'):
            f=root/category/f'{lvl}.json'
            h.update(str(f.relative_to(root)).encode('utf-8'))
            h.update(f.read_bytes())
    return h.hexdigest()


def build_content(root:Path,out:Path,report:Path,allow_partial=False):
    voc,kan=fetch_json_data(root)
    counts,kcounts=validate_source(voc,kan,allow_partial=allow_partial)
    meta=json.loads((root/'meta.json').read_text('utf-8')) if (root/'meta.json').exists() else {}
    if meta and not allow_partial:
        for category, actual in [('vocab',counts),('kanji',kcounts)]:
            expected=meta.get('counts',{}).get(category,{})
            if any(actual[lv] != expected.get(lv) for lv in EXPECTED) or sum(actual.values()) != expected.get('total'):
                raise ValueError(f'{category} counts differ from downloaded meta.json')
    sha=sha_data(root)
    out.parent.mkdir(parents=True,exist_ok=True)
    report.parent.mkdir(parents=True,exist_ok=True)
    temp_out=out.with_suffix('.building.sqlite')
    if temp_out.exists(): temp_out.unlink()
    db=sqlite3.connect(temp_out)
    db.executescript(DDL)
    sources={
      'source_name':'OpenJLPT', 'source_url':ROOT_URL,
      'license':'CC BY-SA 4.0', 'license_url':LICENSE_URL,
      'upstream_notice':ROOT_URL+'/blob/main/NOTICE.md',
      'word_levels':'Unofficial community approximations, not official JLPT vocabulary list',
      'content_sha256':sha, 'revision_ref':meta.get('version','fixture'), 'imported_at':date.today().isoformat(),
      'korean_status':'Korean meanings, hanja hun/eum and example translations NOT provided by OpenJLPT',
    }
    if (root/'meta.json').exists():
        sources['openjlpt_meta']= (root/'meta.json').read_text('utf-8')
    db.executemany('INSERT INTO source_info VALUES (?,?)',sources.items())
    for v in kan:
        db.execute('''INSERT INTO kanji(character,jlpt_level,onyomi_json,kunyomi_json,meanings_en_json,strokes,radical)
        VALUES(?,?,?,?,?,?,?)''',(
          v['character'],v['level'],j(v.get('onyomi',[])),j(v.get('kunyomi',[])),
          j(v.get('meanings',[])),v.get('strokes'),v.get('radical')
        ))
    kanji_catalog={v['character'] for v in kan}
    running_idx=Counter()
    for v in voc:
        running_idx[v['level']]+=1
        wid=v['id']
        # Source indices are per level and preserve the ordering in OpenJLPT.
        db.execute('''INSERT INTO vocab(word_id,surface,reading_kana,romaji,jlpt_level,source_index,
        gloss_en_json,pos_codes_json,jmdict_id,reading_check,other_forms_json,other_readings_json)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?)''',(
          wid,v['word'],v['reading'],v.get('romaji'),v['level'],
          running_idx[v['level']],
          j(v.get('meanings',[])),j(v.get('pos',[])),v.get('jmdict_id'),
          'upstream_jmdict_linked' if v.get('jmdict_id') else 'not_linked',
          j(v.get('other_forms',[])),j(v.get('other_readings',[]))
        ))
        if v.get('jmdict_id'):
            db.execute('INSERT INTO validations VALUES (?, ?, ?, ?, ?, ?)',
                       (wid,'surface_reading','linked_by_upstream','OpenJLPT / JMdict',None,
                        'OpenJLPT contains a JMdict ID; independent JMdict XML check not yet run'))
        else:
            db.execute('INSERT INTO validations VALUES (?, ?, ?, ?, ?, ?)',
                       (wid,'surface_reading','needs_manual_review','OpenJLPT / JMdict',None,
                        'No JMdict linked ID'))
            db.execute('INSERT INTO source_review(entity_type,entity_id,field_name,severity,issue_code,message) VALUES(?,?,?,?,?,?)',
                       ('vocab',wid,'surface_reading','high','NO_JMDICT_LINK','Original source has no JMdict link'))
        for p,ch in enumerate(v['word']):
            if is_kanji(ch):
                db.execute('INSERT INTO word_kanji(word_id,character,surface_pos) VALUES (?,?,?)',(wid,ch,p))
                if ch not in kanji_catalog:
                    db.execute('INSERT OR IGNORE INTO source_review(entity_type,entity_id,field_name,severity,issue_code,message) VALUES(?,?,?,?,?,?)',
                               ('vocab',wid,'kanji_catalog','low','CHAR_NOT_IN_OPENJLPT_KANJI_LIST',ch))
        for ix,ex in enumerate(v.get('examples',[]),start=1):
            if not ex.get('ja'): continue
            db.execute('''INSERT INTO examples(example_id,word_id,sequence,text_ja,furigana_markup,text_en,tatoeba_id)
              VALUES(?,?,?,?,?,?,?)''',(
              f'{wid}_{ix}',wid,ix,ex['ja'],ex.get('furigana'),ex.get('en'),ex.get('tatoeba_id')
            ))
    db.execute('INSERT INTO content_revision(revision,built_at) VALUES(?,?)', (sha[:16],date.today().isoformat()))
    db.execute('CREATE INDEX vocab_jmdict_idx ON vocab(jmdict_id)')
    db.execute('CREATE INDEX vocab_source_idx ON vocab(jlpt_level,source_index,word_id)')
    # Portable SQLite: Android's bundled SQLite need not support FTS5.
    fkerr=db.execute('PRAGMA foreign_key_check').fetchall()
    check=db.execute('PRAGMA integrity_check').fetchone()[0]
    if check!='ok' or fkerr: raise RuntimeError('SQLite integrity check failed '+str(check)+' FK '+str(fkerr[:3]))
    s={
      'metadata_version':meta.get('version'),
      'metadata_counts_match':bool(meta) and all(dict(c)=={k:v for k,v in meta['counts'][name].items() if k!='total'} for c,name in [(counts,'vocab'),(kcounts,'kanji')]),
      'vocab_total':db.execute('SELECT COUNT(*) FROM vocab').fetchone()[0],
      'kanji_total':db.execute('SELECT COUNT(*) FROM kanji').fetchone()[0],
      'word_kanji_links':db.execute('SELECT COUNT(*) FROM word_kanji').fetchone()[0],
      'example_total':db.execute('SELECT COUNT(*) FROM examples').fetchone()[0],
      'jmdict_linked':db.execute('SELECT COUNT(*) FROM vocab WHERE jmdict_id IS NOT NULL').fetchone()[0],
      'direct_jmdict_verified':0,
      'korean_word_meanings_reviewed':0,
      'korean_hanja_huneum_reviewed':0,
      'korean_example_translations_reviewed':0,
      'vocab_by_level':dict(counts), 'kanji_by_level':dict(kcounts),
      'source_sha256':sha, 'sqlite_integrity':check,
      'status_note':'Japanese source imported. Korean translations and Korean hanja meanings NOT completed.'
    }
    report.write_text(json.dumps(s,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    db.commit();db.close()
    os.replace(temp_out,out)
    print(json.dumps(s,ensure_ascii=False,indent=2))
    return s


def make_progress_db(out:Path):
    if out.exists():
        print('Keeping existing progress DB unchanged:',out)
        return
    db=sqlite3.connect(out)
    db.executescript(PROGRESS_DDL)
    prefs={
      'default_page_size':20, 'max_page_size':200,
      'level':'N5','study_mode':'normal',
      'study_visibility':{k:True for k in VIS},
      'test_question_visibility':{k:False for k in VIS},
      'test_answer_visibility':{k:True for k in VIS},
    }
    db.executemany('INSERT INTO preferences(pref_key,json_value) VALUES(?,?)',
                   ((key,j(value)) for key,value in prefs.items()))
    db.commit();db.close()
    print('Initialized progress DB:',out)


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    g=ap.add_mutually_exclusive_group(required=True)
    g.add_argument('--source-dir',type=Path,help='OpenJLPT repository folder or data/json folder')
    g.add_argument('--archive',type=Path,help='Local OpenJLPT ZIP archive')
    g.add_argument('--download',action='store_true',help='Download public OpenJLPT zip from GitHub')
    ap.add_argument('--ref',default=DEFAULT_REF)
    ap.add_argument('--allow-partial',action='store_true',help='Only for intentionally incomplete test data')
    ap.add_argument('--out',type=Path,default=Path('jlpt_content.sqlite'))
    ap.add_argument('--progress-out',type=Path,default=Path('jlpt_user_progress.sqlite'))
    ap.add_argument('--report',type=Path,default=Path('import_report.json'))
    args=ap.parse_args()
    if args.out.resolve()==args.progress_out.resolve():
        raise ValueError('Content DB and progress DB paths must be different')
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.progress_out.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        tmp=Path(tmp)
        if args.download:
            archive=tmp/'OpenJLPT.zip';download_repo(args.ref,archive)
            source=extract_zip(archive,tmp/'repo')
        elif args.archive:
            source=extract_zip(args.archive,tmp/'repo')
        else:
            source=args.source_dir
        root=locate_json(source)
        build_content(root,args.out,args.report,allow_partial=args.allow_partial)
        make_progress_db(args.progress_out)
    print('Generated:',args.out.resolve())

if __name__=='__main__': main()
