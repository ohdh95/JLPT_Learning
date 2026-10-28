"""Import source-backed KanjiVG components; never infer etymology or readings.

Generate the portable snapshot from pinned SVGs, KANJIDIC2 and libhangul, or
reapply the checked-in snapshot offline with just --db. Derived data: CC BY-SA 4.0.
"""
from __future__ import annotations
import argparse
from collections import Counter
import gzip
import hashlib
import json
from pathlib import Path
import sqlite3
import xml.etree.ElementTree as ET

from localize_hanja import load_hanja

ROOT = Path(__file__).resolve().parents[1]
REVISION = '70a0b7ae0c18ceb5cb358274b029cce0234a43bc'
SOURCE = f'https://github.com/KanjiVG/kanjivg/tree/{REVISION}'
SCHEMA = '''CREATE TABLE IF NOT EXISTS kanji_components(
 character TEXT NOT NULL REFERENCES kanji(character),
 sequence INTEGER NOT NULL,
 glyph TEXT NOT NULL,
 target_character TEXT REFERENCES kanji(character),
 label_ko TEXT NOT NULL DEFAULT '',
 position TEXT NOT NULL DEFAULT '',
 is_partial INTEGER NOT NULL CHECK(is_partial IN (0,1)),
 source_group TEXT NOT NULL,
 PRIMARY KEY(character,sequence)
);'''
# Pedagogical stopping points, not a claim to classify all historical simple
# characters. In particular, do not split basic pictographs into incidental shapes.
BASIC = set('一二三人入八儿大天夫土士王玉金木本末未日月目田甲由申中口山川水火土石雨竹米禾牛羊馬鳥魚虫犬子女母父手足心耳自鼻舌牙身毛皮骨血肉舟車門戶弓刀力又爪衣食糸网立生白百千十丁七九了乃乙巾斤干工寸小少文方斗止見貝長高')
STROKES = set('丨丶丿乀乁乚乛亅')


def dump(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':'))


def attr(node, name):
    # Upstream files use both http and https KVG namespace spellings.
    return next((v for k, v in node.attrib.items()
                 if k.startswith('{') and k.rsplit('}', 1)[-1] == name), '')


def decompose(xml, character):
    if character in BASIC:
        return [], 'basic'
    root = ET.fromstring(xml)
    group = next((n for n in root.iter()
                  if n.get('id') == f'kvg:{ord(character):05x}'), None)
    if group is None:
        return [], 'missing_root'
    parts = []
    uncovered = False

    def walk(node):
        nonlocal uncovered
        for child in node:
            tag = child.tag.rsplit('}', 1)[-1]
            if tag == 'path':
                uncovered = True
            elif tag == 'g':
                glyph = attr(child, 'element')
                if glyph and glyph != character:
                    parts.append(dict(glyph=glyph,
                        original=attr(child, 'original') or glyph,
                        position=attr(child, 'position'),
                        partial=attr(child, 'partial') == 'true',
                        part=attr(child, 'part'), number=attr(child, 'number'),
                        group=child.get('id', '')))
                else:
                    walk(child)

    walk(group)
    # A lone radical or an uncovered stroke is not a complete decomposition.
    if uncovered or not parts:
        return [], 'no_complete_grouping'
    merged = []
    seen = set()
    for part in parts:
        if len(part['glyph']) != 1 or part['glyph'] in STROKES:
            return [], 'stroke_or_unencoded_shape'
        if part['part']:
            key = (part['glyph'], part['original'], part['number'])
            matching = [p for p in parts if p['part'] and
                        (p['glyph'], p['original'], p['number']) == key]
            numbers = [int(p['part']) for p in matching]
            if len(numbers) < 2 or sorted(numbers) != list(range(1, len(numbers) + 1)):
                return [], 'incomplete_split_group'
            if key in seen:
                continue
            seen.add(key)
            part = {**part, 'partial': any(p['partial'] for p in matching),
                    'group': ','.join(p['group'] for p in matching)}
        merged.append(part)
    if len(merged) < 2:
        return [], 'single_group'
    return merged, 'components'


def kanjidic(path):
    with gzip.open(path, 'rb') as f:
        root = ET.parse(f).getroot()
    result = {}
    for node in root.findall('character'):
        character = node.findtext('literal')
        readings = node.findall('./reading_meaning/rmgroup/reading')
        result[character] = dict(character=character,
            onyomi=[r.text for r in readings if r.get('r_type') == 'ja_on'],
            kunyomi=[r.text for r in readings if r.get('r_type') == 'ja_kun'],
            meanings=[r.text for r in node.findall('./reading_meaning/rmgroup/meaning')
                      if not r.get('m_lang')],
            strokes=int(node.findtext('./misc/stroke_count') or 0))
    return result


def generate(db, svg_dir, dictionary, hanja):
    existing = {r[0] for r in db.execute(
        'SELECT character FROM kanji WHERE jlpt_level IS NOT NULL '
        'OR character IN (SELECT character FROM word_kanji)')}
    pending = sorted(existing)
    processed = set()
    entries, supplements, statuses, source_hashes = {}, {}, {}, {}
    while pending:
        character = pending.pop(0)
        if character in processed:
            continue
        processed.add(character)
        path = svg_dir / f'{ord(character):05x}.svg'
        if not path.exists():
            statuses[character] = 'source_missing'
            continue
        raw = path.read_bytes()
        source_hashes[path.name] = hashlib.sha256(raw).hexdigest()
        parts, status = decompose(raw, character)
        statuses[character] = status
        if not parts:
            continue
        rows = []
        for part in parts:
            target = part['original']
            if part['partial'] or target == character:
                target = None
            elif target not in existing:
                info, hun = dictionary.get(target), hanja.get(target)
                # Require dictionary evidence and Korean provenance for new
                # standalone entries. Non-standalone shapes remain plain labels.
                if info and hun and (info['onyomi'] or info['kunyomi']):
                    supplements[target] = {**info, 'hun': hun[0][0], 'eum': hun[0][1]}
                    pending.append(target)
                else:
                    target = None
            label = ''
            if target is None and hanja.get(part['original']):
                label = ' '.join(hanja[part['original']][0])
            rows.append(dict(glyph=part['glyph'], target=target, label=label,
                             position=part['position'], partial=part['partial'],
                             group=part['group']))
        entries[character] = rows
    return dict(schema=1, source=SOURCE, revision=REVISION,
                license='CC-BY-SA-4.0', human_reviewed=False,
                entries=entries, supplements=supplements, statuses=statuses,
                svg_sha256=source_hashes)


def validate(data, catalog):
    supplements = data['supplements']
    known = catalog | set(supplements)
    graph = {}
    for ch, parts in data['entries'].items():
        if len(ch) != 1 or len(parts) < 2:
            raise ValueError('Invalid decomposition')
        graph[ch] = []
        for part in parts:
            target = part['target']
            if len(part['glyph']) != 1 or target == ch or (part['partial'] and target):
                raise ValueError('Invalid component link')
            if target is not None:
                if target not in known:
                    raise ValueError(f'Dangling component: {ch} -> {target}')
                graph[ch].append(target)
    done, active = set(), set()
    def visit(ch):
        if ch in active:
            raise ValueError(f'Component cycle at {ch}')
        if ch in done:
            return
        active.add(ch)
        for target in graph.get(ch, []):
            visit(target)
        active.remove(ch)
        done.add(ch)
    for ch in graph:
        visit(ch)


def install(db, data):
    known = {r[0] for r in db.execute('SELECT character FROM kanji')}
    validate(data, known)
    db.execute(SCHEMA)
    # Only the composition table is replaced; existing meanings and review
    # statuses, source order and user DB are never overwritten.
    with db:
        for ch, row in sorted(data['supplements'].items()):
            db.execute('''INSERT OR IGNORE INTO kanji(character,onyomi_json,kunyomi_json,
                meanings_en_json,korean_hun,korean_eum,korean_hun_eum_status,strokes)
                VALUES(?,?,?,?,?,?,'draft',?)''',
                [ch,dump(row['onyomi']),dump(row['kunyomi']),dump(row['meanings']),
                 row['hun'],row['eum'],row['strokes']])
        db.execute('DELETE FROM kanji_components')
        for ch, parts in sorted(data['entries'].items()):
            if ch not in known and ch not in data['supplements']:
                continue
            for index, part in enumerate(parts):
                db.execute('INSERT INTO kanji_components VALUES(?,?,?,?,?,?,?,?)',
                    [ch,index,part['glyph'],part['target'],part['label'],
                     part['position'],int(part['partial']),part['group']])
        db.execute('INSERT OR REPLACE INTO source_info VALUES(?,?)',
                   ['kanji_components',dump({k:v for k,v in data.items()
                     if k not in {'entries','svg_sha256'}})])
        failures = db.execute('PRAGMA foreign_key_check').fetchall()
        if failures:
            raise ValueError(f'Foreign key failures: {failures}')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--db', type=Path, required=True)
    p.add_argument('--kanjivg', type=Path)
    p.add_argument('--kanjidic', type=Path)
    p.add_argument('--hanja', type=Path)
    p.add_argument('--snapshot', type=Path, default=ROOT/'pipeline/data/kanji_components.json')
    p.add_argument('--report', type=Path, default=ROOT/'reports/kanji-components-data.json')
    a = p.parse_args()
    with sqlite3.connect(a.db) as db:
        db.execute('PRAGMA foreign_keys=ON')
        if a.kanjivg:
            if not a.kanjidic or not a.hanja:
                p.error('--kanjidic and --hanja are required when generating')
            data = generate(db, a.kanjivg, kanjidic(a.kanjidic), load_hanja(a.hanja))
            data['dictionary_sources'] = {
                'kanjidic2': {'url':'https://www.edrdg.org/kanjidic/kanjidic2.xml.gz',
                             'sha256':hashlib.sha256(a.kanjidic.read_bytes()).hexdigest()},
                'hun_eum': {'url':'https://github.com/libhangul/libhangul/blob/main/data/hanja/hanja.txt',
                            'sha256':hashlib.sha256(a.hanja.read_bytes()).hexdigest(),
                            'status':'draft', 'human_reviewed':False}}
            validate(data, {r[0] for r in db.execute('SELECT character FROM kanji')})
            a.snapshot.parent.mkdir(parents=True, exist_ok=True)
            a.snapshot.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n')
        else:
            data = json.loads(a.snapshot.read_text())
        install(db, data)
        report = dict(revision=REVISION, characters_with_components=len(data['entries']),
            component_rows=sum(map(len,data['entries'].values())),
            supplemental_characters=len(data['supplements']),
            statuses=dict(Counter(data['statuses'].values())),
            unlinked_shapes=sorted({p['glyph'] for rows in data['entries'].values()
                                    for p in rows if p['target'] is None}),
            graded_coverage=dict(db.execute('''SELECT jlpt_level,COUNT(DISTINCT k.character)
                FROM kanji k JOIN kanji_components c ON c.character=k.character
                WHERE jlpt_level IS NOT NULL GROUP BY jlpt_level''')),
            foreign_key_errors=0, human_reviewed=False)
    a.report.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(dump(report))


if __name__ == '__main__':
    main()
