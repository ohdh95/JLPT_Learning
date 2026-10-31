"""Build the requested N5->N1 curriculum without changing words or user data.

Normal rebuilds use the checked-in evidence, with Python's standard library only.
Refreshing evidence needs wordfreq==3.1.1 and the original JMdict_e XML.
Surface frequency is a circa-2021 estimate, NOT JLPT exam frequency. Editorial
and dictionary signals define broad stages; they are not verified semantic tags.
"""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import gzip
import hashlib
from importlib.metadata import version
import json
import math
from pathlib import Path
import re
import sqlite3
import unicodedata
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
POLICY_PATH = ROOT / 'pipeline/data/learning_order_policy.json'
EVIDENCE_PATH = ROOT / 'pipeline/data/learning_order_evidence.json'
LEVELS = ('N5', 'N4', 'N3', 'N2', 'N1')
ABSTRACT_GLOSSES = set('''abstraction concept conception notion ideology philosophy
 principle theory hypothesis inference deduction interpretation implication
 intention intent motive motivation purpose significance essence relevance
 consciousness awareness perception cognition recognition judgment judgement
 belief conviction faith confidence trust dignity prestige authority sovereignty
 morality ethics justice equity obligation responsibility accountability
 autonomy independence dependence interdependence consistency contradiction
 paradox ambiguity vagueness prejudice bias assumption premise causality
 possibility probability inevitability universality relativity rationality
 validity legitimacy justification feasibility necessity potential tendency
 disposition sentiment emotion affection empathy sympathy resentment envy
 jealousy anxiety concern apprehension aspiration ambition determination
 perseverance patience tolerance generosity compassion sincerity integrity
 modesty humility vanity arrogance pride contempt despair optimism pessimism
 reconciliation compromise consensus solidarity harmony equilibrium balance
 moderation restraint inhibition suppression discrimination alienation
 perspective standpoint viewpoint outlook insight intuition speculation
 conception ideal realism idealism optimism pessimism skepticism scepticism
 merit demerit advantage disadvantage essence logic methodology criterion
 analogy deliberation contemplation reflection introspection conscience
 evaluation assessment appraisal esteem expectation anticipation conception
 foundation basis context circumstance contingency subjectivity objectivity
 abstract conceptual theoretical ideological philosophical ethical moral
 subjective objective implicit explicit intrinsic inherent fundamental
 arbitrary ambiguous vague rational irrational hypothetical inevitable
 universal relative absolute legitimate contradictory coherent consistent'''.split())
SCHEMA = '''CREATE TABLE IF NOT EXISTS word_learning_order(
 word_id TEXT PRIMARY KEY REFERENCES vocab(word_id),
 jlpt_level TEXT NOT NULL CHECK(jlpt_level IN ('N5','N4','N3','N2','N1')),
 stage INTEGER NOT NULL CHECK(stage BETWEEN 0 AND 2),
 rank INTEGER NOT NULL CHECK(rank > 0),
 frequency_zipf REAL NOT NULL,
 reason TEXT NOT NULL,
 related_n5_json TEXT NOT NULL DEFAULT '[]',
 UNIQUE(jlpt_level,rank)
)'''


def dump(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':'))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def words(db):
    cursor = db.execute('SELECT * FROM vocab ORDER BY jlpt_level DESC,source_index,word_id')
    names = [d[0] for d in cursor.description]
    return [dict(zip(names, row)) for row in cursor]


def dictionary_evidence(path, rows):
    targets = defaultdict(list)
    for r in rows:
        if r['reading_check'] == 'direct_jmdict_verified':
            targets[r['jmdict_id']].append(r)
    result = {}
    with gzip.open(path, 'rb') if str(path).endswith('.gz') else open(path, 'rb') as f:
        for _, node in ET.iterparse(f, events=('end',)):
            if node.tag != 'entry':
                continue
            for r in targets.get(int(node.findtext('ent_seq')), []):
                senses = [s for s in node.findall('sense')
                          if (not s.findall('stagk') or r['surface'] in [v.text for v in s.findall('stagk')])
                          and (not s.findall('stagr') or r['reading_kana'] in [v.text for v in s.findall('stagr')])]
                rare = lambda s: any(v.text in {'archaic', 'obsolete term', 'rare term', 'historical term'}
                                     for v in s.findall('misc'))
                result[r['word_id']] = {
                    'sense_count': len(senses),
                    'all_senses_rare': bool(senses) and all(rare(s) for s in senses),
                    'idiomatic': any('idiomatic' in (v.text or '') or 'proverb' in (v.text or '')
                                     for s in senses for v in s.findall('misc')),
                }
            node.clear()
    return result


def generate_evidence(rows, jmdict):
    import wordfreq
    if version('wordfreq') != '3.1.1':
        raise ValueError('Use pinned wordfreq==3.1.1 for reproducible evidence')
    frequencies = wordfreq.get_frequency_dict('ja', wordlist='large')
    dictionary = dictionary_evidence(jmdict, rows)
    entries = {}
    for r in rows:
        # Exact written-form lookup only: do not synthesize phrase frequencies,
        # or substitute a kana homophone / sum unrelated readings.
        frequency = frequencies.get(unicodedata.normalize('NFKC', r['surface']), 0)
        entries[r['word_id']] = {
            'surface': r['surface'], 'reading': r['reading_kana'], 'level': r['jlpt_level'],
            'zipf': round(math.log10(frequency) + 9, 2) if frequency else 0.0,
            **dictionary.get(r['word_id'], {'sense_count': 0, 'all_senses_rare': False, 'idiomatic': False}),
        }
    data_file = Path(wordfreq.__file__).parent / 'data/large_ja.msgpack.gz'
    return {'version': 1, 'frequency_source': 'wordfreq 3.1.1, Robyn Speer',
            'frequency_url': 'https://github.com/rspeer/wordfreq',
            'frequency_data_sha256': sha(data_file),
            'frequency_coverage': 'mixed corpora through approximately 2021; written form, not reading or sense',
            'license': 'CC BY-SA 4.0', 'jmdict_sha256': sha(jmdict),
            'human_reviewed': False, 'entries': entries}


def make_order(rows, evidence, policy):
    ids = [r['word_id'] for r in rows]
    if len(ids) != len(set(ids)) or any(r['jlpt_level'] not in LEVELS for r in rows):
        raise ValueError('Duplicate word IDs or invalid level')
    n5 = defaultdict(list)
    easiest_surface = {}
    for r in rows:
        lv = LEVELS.index(r['jlpt_level'])
        easiest_surface[r['surface']] = min(lv, easiest_surface.get(r['surface'], lv))
        if r['jlpt_level'] == 'N5':
            n5[r['surface']].append(r['word_id'])
    core = set(policy['n5_core'].split())
    social = set(policy['n3_daily_social'].split())
    abstract = set(policy['abstract'].split())
    idioms = set(policy['idioms'].split())
    synonyms = {w for group in policy['synonym_groups'] for w in group}
    groups = defaultdict(list)
    for r in rows:
        wid, surface, level = r['word_id'], r['surface'], r['jlpt_level']
        e = evidence.get('entries', {}).get(wid, {})
        if e and (e['surface'], e['reading'], e['level']) != (surface, r['reading_kana'], level):
            raise ValueError(f'Stale evidence identity: {wid}')
        freq = float(e.get('zipf', 0))
        if not math.isfinite(freq) or not 0 <= freq <= 9:
            raise ValueError(f'Invalid frequency: {wid}')
        pos = json.loads(r['pos_codes_json'])
        verb = any(p.startswith('v') for p in pos)
        adjective = any(p.startswith('adj-') for p in pos)
        content_word = verb or adjective or any(p in {'n', 'n-adv', 'adv'} for p in pos)
        everyday_nva = verb or adjective or 'n' in pos
        # A single kanji/suffix's aggregate frequency must not make an advanced
        # reading look more frequent than its elementary homograph.
        shared_easier_form = easiest_surface[surface] < LEVELS.index(level)
        affix = bool(pos) and all(p in {'n-suf', 'n-pref', 'suf', 'pref', 'ctr', 'prt', 'num'} for p in pos)
        # Single characters aggregate many readings/affix uses. At N3/N1 they
        # cannot alone establish frequent standalone vocabulary (e.g. 奴/やっこ,
        # 機/はた, 件/くだん). Their level/content still stays untouched.
        usable_frequency = not shared_easier_form and not affix and len(surface) >= 2
        gloss_tokens = set(re.findall(r'[a-z]+', ' '.join(json.loads(r['gloss_en_json'])).lower()))
        is_abstract = surface in abstract or bool(gloss_tokens & ABSTRACT_GLOSSES)
        is_idiom = surface in idioms or e.get('idiomatic', False)
        compound = sum('\u3400' <= c <= '\u9fff' for c in surface) >= 2
        related = sorted({i for base in policy['n4_n5_related'].get(surface, []) for i in n5[base]})
        stage, reason = 2, 'remaining_or_low_frequency'
        if e.get('all_senses_rare', False):
            reason = 'dictionary_rare_or_historical'
        elif level == 'N5':
            if surface in core:
                stage, reason = 0, 'editorial_core'
            elif everyday_nva and freq >= 3.5:
                stage, reason = 1, 'frequent_everyday_content_word'
        elif level == 'N4':
            if related:
                stage, reason = 0, 'editorial_link_to_n5'
            elif usable_frequency and freq >= 3.5 and (verb or compound or is_idiom):
                stage, reason = 1, 'frequent_verb_or_compound'
        elif level == 'N3':
            if surface in social or (usable_frequency and content_word and freq >= 4.0 and not is_abstract):
                stage, reason = 0, 'everyday_social_or_frequent_content_word'
            elif is_abstract:
                stage, reason = 1, 'editorial_abstract'
        elif level == 'N2':
            if usable_frequency and compound and freq >= 4.0:
                stage, reason = 0, 'frequent_kanji_compound'
            elif surface in synonyms or (e.get('sense_count', 0) >= 2 and freq >= 3.3 and not affix):
                stage, reason = 1, 'editorial_synonym_or_dictionary_multiple_senses'
        elif level == 'N1':
            if usable_frequency and content_word and freq >= 4.0:
                stage, reason = 0, 'frequent_advanced_content_word'
            elif (is_abstract and freq >= 2.5) or is_idiom:
                stage, reason = 1, 'editorial_abstract_or_idiomatic'
        if not e:
            # Fixture/new words lacking pinned evidence remain at the end.
            stage, reason, related = 2, 'evidence_missing', []
        groups[level].append({'word_id': wid, 'jlpt_level': level, 'stage': stage,
                              'frequency_zipf': freq, 'reason': reason,
                              'related_n5_json': dump(related), 'source_index': r['source_index']})
    result = []
    for level in LEVELS:
        group = sorted(groups[level], key=lambda r: (r['stage'], -r['frequency_zipf'], r['source_index'], r['word_id']))
        for rank, r in enumerate(group, 1):
            r = dict(r, rank=rank)
            del r['source_index']
            result.append(r)
    return result


def install(db, evidence=None, policy=None):
    evidence = evidence if evidence is not None else json.loads(EVIDENCE_PATH.read_text())
    policy = policy if policy is not None else json.loads(POLICY_PATH.read_text())
    rows = words(db)
    order = make_order(rows, evidence, policy)
    db.execute(SCHEMA)
    # Caller owns the transaction. Validate before deleting old ranks.
    db.execute('DELETE FROM word_learning_order')
    db.executemany('''INSERT INTO word_learning_order
        (word_id,jlpt_level,stage,rank,frequency_zipf,reason,related_n5_json)
        VALUES(:word_id,:jlpt_level,:stage,:rank,:frequency_zipf,:reason,:related_n5_json)''', order)
    db.execute('INSERT OR REPLACE INTO source_info VALUES(?,?)',
               ('learning_order', dump({'version': 1, 'policy_sha256': hashlib.sha256(dump(policy).encode()).hexdigest(),
                'evidence_sha256': hashlib.sha256(dump(evidence).encode()).hexdigest(),
                'method': 'editorial_stages_then_surface_frequency', 'human_reviewed': False,
                'frequency_source': evidence.get('frequency_source'), 'stages': policy['stages']})))
    by_id = {r['word_id']: r for r in rows}
    return {'version': 1, 'words': len(order), 'human_reviewed': False,
            'levels': {level: {'stages': [
                {'label': label, 'count': sum(r['jlpt_level'] == level and r['stage'] == stage for r in order)}
                for stage, label in enumerate(policy['stages'][level])],
                'first_30': [{'surface': by_id[r['word_id']]['surface'], 'reading': by_id[r['word_id']]['reading_kana'],
                              'rank': r['rank'], 'stage': r['stage'] + 1, 'zipf': r['frequency_zipf']}
                             for r in order if r['jlpt_level'] == level and r['rank'] <= 30]}
                for level in LEVELS},
            'frequency_matched': sum(r['frequency_zipf'] > 0 for r in order),
            'reason_counts': dict(Counter(r['reason'] for r in order))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--db', type=Path, required=True)
    parser.add_argument('--refresh-evidence', action='store_true')
    parser.add_argument('--jmdict', type=Path)
    parser.add_argument('--evidence', type=Path, default=EVIDENCE_PATH)
    parser.add_argument('--report', type=Path, default=ROOT/'reports/learning-order-data.json')
    args = parser.parse_args()
    if not args.db.exists():
        raise ValueError('Existing content DB required')
    with sqlite3.connect(args.db) as db:
        db.execute('PRAGMA foreign_keys=ON')
        if args.refresh_evidence:
            if not args.jmdict:
                parser.error('--refresh-evidence requires --jmdict')
            evidence = generate_evidence(words(db), args.jmdict)
            args.evidence.write_text(json.dumps(evidence, ensure_ascii=False, indent=2)+'\n')
        else:
            evidence = json.loads(args.evidence.read_text())
        before = db.execute('SELECT * FROM vocab ORDER BY word_id').fetchall()
        result = install(db, evidence)
        assert before == db.execute('SELECT * FROM vocab ORDER BY word_id').fetchall()
        assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
        assert not db.execute('PRAGMA foreign_key_check').fetchall()
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps({k: v for k, v in result.items() if k != 'levels'}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
