"""Explicit, resumable editorial passes over immutable Japanese/Korean pairs.

`show` supplies a numbered range to the reviewer. `record` is called only after
that range was read; stdin contains index|corrected Korean for changes. Unchanged
rows receive a retained decision, never human_reviewed. Import requires coverage
of every source ID and an exact source/input snapshot match.
"""
import argparse
import collections
import datetime
import hashlib
import json
import sqlite3
import sys
from pathlib import Path
from localization_common import digest, validate_candidate
from translate_examples_madlad import flags

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / 'pipeline/localization/full_review'


def read(path):
    return [json.loads(s) for s in path.read_text(encoding='utf-8').splitlines() if s.strip()]


def save(path, rows):
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(''.join(json.dumps(r, ensure_ascii=False) + '\n' for r in rows), encoding='utf-8')
    temporary.replace(path)


def initialize():
    path = FOLDER / 'input.jsonl'
    if path.exists():
        raise ValueError('Review input already exists; preserve the original snapshot')
    grouped = collections.OrderedDict()
    with sqlite3.connect(ROOT / 'assets/content.sqlite') as db:
        for eid, ja, en, ko, tid, level in db.execute('''
          SELECT e.example_id,e.text_ja,e.text_en,e.text_ko,e.tatoeba_id,v.jlpt_level
          FROM examples e JOIN vocab v USING(word_id)
          ORDER BY v.jlpt_level DESC,v.source_index,e.sequence'''):
            key = (ja, ko)
            item = grouped.setdefault(key, dict(index=len(grouped)+1, ja=ja, before=ko, examples=[]))
            item['examples'].append(dict(id=eid, en=en, tatoeba_id=tid, level=level))
    FOLDER.mkdir(parents=True, exist_ok=True)
    save(path, grouped.values())
    print('Immutable review pairs:', len(grouped))


def record(rows, start, end):
    changes = {}
    for line in sys.stdin:
        if not line.strip():
            continue
        index, value = line.strip().split('|', 1)
        index = int(index)
        if not start <= index <= end or index in changes or not value.strip():
            raise ValueError('Invalid/duplicate correction index')
        changes[index] = value.strip()
    selected = [r for r in rows if start <= r['index'] <= end]
    if len(selected) != end-start+1:
        raise ValueError('Range outside input')
    path = FOLDER / 'decisions.jsonl'
    decisions = {r['index']:r for r in read(path)} if path.exists() else {}
    for row in selected:
        index = row['index']
        if index in decisions:
            raise ValueError(f'Already recorded: {index}')
        value = changes.get(index, row['before'])
        decisions[index] = dict(index=index, ja=row['ja'], before=row['before'], after=value,
            decision='corrected' if value != row['before'] else 'retained',
            reviewer='Codex AI', review_type='Japanese source and Korean translation semantic/fluency review',
            human_reviewed=False)
    save(path, [decisions[i] for i in sorted(decisions)])
    print('Reviewed', len(decisions), '/', len(rows), 'Changed in range', len(changes))


def amend(rows):
    """Save a second explicit reading without discarding the earlier decision."""
    path = FOLDER / 'decisions.jsonl'
    original = read(path)
    decisions = {r['index']: r for r in original}
    inputs = {r['index']: r for r in rows}
    if len(decisions) != len(original):
        raise ValueError('Duplicate review decisions')
    seen = set()
    for line in sys.stdin:
        if not line.strip():
            continue
        index, value = line.strip().split('|', 1)
        index = int(index)
        if index in seen or index not in decisions or not value.strip():
            raise ValueError('Invalid, duplicate, or unreviewed amendment index')
        seen.add(index)
        item = decisions[index]
        source = inputs[index]
        if item['ja'] != source['ja'] or item['before'] != source['before']:
            raise ValueError('Review source changed')
        if item['after'] == value.strip():
            continue
        item.setdefault('amendments', []).append(dict(
            previous_after=item['after'], previous_decision=item['decision'],
            amended_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
            reviewer='Codex AI', human_reviewed=False))
        item['after'] = value.strip()
        item['decision'] = 'corrected' if item['after'] != source['before'] else 'retained'
    save(path, [decisions[i] for i in sorted(decisions)])
    print('Explicit amendments:', len(seen))


def build_candidates(db, folder):
    """Reject partial/changed/duplicate reviews before producing any import rows."""
    rows = read(folder / 'input.jsonl')
    decisions = read(folder / 'decisions.jsonl')
    inputs = {r['index']: r for r in rows}
    reviewed = {r['index']: r for r in decisions}
    expected_indices = set(range(1, len(rows) + 1))
    if not rows or len(inputs) != len(rows) or set(inputs) != expected_indices:
        raise ValueError('Invalid or duplicate input indices')
    if len(reviewed) != len(decisions) or set(reviewed) != expected_indices:
        raise ValueError('Full unique review coverage required')
    originals = {eid: (ja, en) for eid, ja, en in db.execute(
        'SELECT example_id,text_ja,text_en FROM examples')}
    issue_path = folder / 'source_issues.jsonl'
    issues = read(issue_path) if issue_path.exists() else []
    issue_by_index = {}
    for issue in issues:
        index = issue['index']
        if index not in inputs or index in issue_by_index:
            raise ValueError('Invalid or duplicate source issue')
        source = inputs[index]
        if issue['ja'] != source['ja'] or issue['examples'] != source['examples']:
            raise ValueError('Source issue snapshot changed')
        if issue.get('human_reviewed') is not False or issue['status'] != 'needs_source_review':
            raise ValueError('Source issue cannot certify human review')
        issue_by_index[index] = issue
    result, seen = [], set()
    input_hash, decision_hash = digest(folder/'input.jsonl'), digest(folder/'decisions.jsonl')
    for index in sorted(inputs):
        source, decision = inputs[index], reviewed[index]
        if (source['ja'], source['before']) != (decision['ja'], decision['before']):
            raise ValueError('Review input snapshot changed')
        if decision.get('human_reviewed') is not False or decision.get('reviewer') != 'Codex AI':
            raise ValueError('AI decision cannot certify human review')
        value = decision['after']
        expected = 'retained' if value == source['before'] else 'corrected'
        if decision['decision'] != expected:
            raise ValueError('Decision does not match reviewed text')
        qa = flags(value, source['ja'])
        if qa and not decision.get('qa_editorial_exception'):
            raise ValueError(f'Unresolved output checks at {index}: {qa}')
        if not source['examples']:
            raise ValueError('Empty example group')
        for example in source['examples']:
            eid = example['id']
            if eid in seen:
                raise ValueError('Duplicate source example ID')
            seen.add(eid)
            if originals.get(eid) != (source['ja'], example['en']):
                raise ValueError(f'Changed source sentence: {eid}')
            links = ['https://github.com/evanclan/OpenJLPT']
            if example.get('tatoeba_id'):
                links.insert(0, f"https://tatoeba.org/en/sentences/show/{example['tatoeba_id']}")
            row = dict(entity_type='example', entity_id=eid, value=value,
                method='assistant_ja_ko_review', sources=links,
                source=dict(text_ja=source['ja'], text_en=example['en']),
                assistant_review='full_corpus_semantic_review',
                review_evidence=dict(index=index, decision=decision['decision'],
                    before=source['before'], reviewer='Codex AI',
                    review_type=decision['review_type'],
                    input_sha256=input_hash, decisions_sha256=decision_hash,
                    amendments=decision.get('amendments', [])),
                propagation_rule='Exact Japanese AND baseline Korean; Japanese independently reviewed; each original English retained',
                human_review_required=True)
            if index in issue_by_index:
                row['source_issue'] = issue_by_index[index]['issue']
            if decision.get('qa_editorial_exception'):
                row['qa_editorial_exception'] = decision['qa_editorial_exception']
            validate_candidate(row)
            result.append(row)
    if seen != set(originals):
        raise ValueError('Full unique example ID coverage required')
    return result


def export_review(db, folder):
    candidates = build_candidates(db, folder)
    output = folder.parent / 'example_full_review.jsonl'
    save(output, candidates)
    inputs = read(folder / 'input.jsonl')
    decisions = read(folder / 'decisions.jsonl')
    issue_path = folder / 'source_issues.jsonl'
    manifest = dict(
        exported_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        reviewer='Codex AI', human_review_completed=False,
        reviewed_pairs=len(inputs), reviewed_examples=len(candidates),
        changed_pairs=sum(d['decision'] == 'corrected' for d in decisions),
        changed_examples=sum(c['review_evidence']['decision'] == 'corrected' for c in candidates),
        examples_by_level=dict(collections.Counter(e['level'] for r in inputs for e in r['examples'])),
        input_sha256=digest(folder/'input.jsonl'),
        decisions_sha256=digest(folder/'decisions.jsonl'),
        output_sha256=digest(output),
        source_issues_sha256=digest(issue_path) if issue_path.exists() else None,
        unresolved_source_pairs=len(read(issue_path)) if issue_path.exists() else 0)
    (folder/'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    return manifest


def load_completed_review(db, folder):
    manifest = json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
    for name, key in [('input.jsonl','input_sha256'), ('decisions.jsonl','decisions_sha256'),
                      ('../example_full_review.jsonl','output_sha256')]:
        if digest(folder/name) != manifest[key]:
            raise ValueError('Completed review manifest hash mismatch')
    issue_path = folder/'source_issues.jsonl'
    if (digest(issue_path) if issue_path.exists() else None) != manifest['source_issues_sha256']:
        raise ValueError('Source issue manifest hash mismatch')
    candidates = build_candidates(db, folder)
    if candidates != read(folder.parent/'example_full_review.jsonl'):
        raise ValueError('Export differs from explicit review decisions')
    if manifest.get('human_review_completed') is not False or manifest.get('reviewer') != 'Codex AI':
        raise ValueError('AI manifest cannot certify human review')
    inputs = read(folder/'input.jsonl')
    expected = dict(reviewed_examples=len(candidates), reviewed_pairs=len(inputs),
        changed_examples=sum(c['review_evidence']['decision']=='corrected' for c in candidates),
        changed_pairs=sum(d['decision']=='corrected' for d in read(folder/'decisions.jsonl')),
        examples_by_level=dict(collections.Counter(e['level'] for r in inputs for e in r['examples'])),
        unresolved_source_pairs=len(read(issue_path)) if issue_path.exists() else 0)
    if any(manifest.get(k) != v for k,v in expected.items()):
        raise ValueError('Review manifest coverage/count mismatch')
    return candidates, manifest


def store_metadata(db, folder):
    candidates, manifest = load_completed_review(db, folder)
    db.execute('INSERT OR REPLACE INTO source_info VALUES(?,?)',
        ['full_example_semantic_review', json.dumps(manifest, ensure_ascii=False)])
    for row in candidates:
        if row.get('source_issue'):
            db.execute('''INSERT OR REPLACE INTO source_review
                (entity_type,entity_id,field_name,severity,issue_code,message)
                VALUES(?,?,?,?,?,?)''', ['example',row['entity_id'],'text_ja','warning',
                'FULL_REVIEW_SOURCE_CHECK_REQUIRED',row['source_issue']])


def main():
    p = argparse.ArgumentParser()
    p.add_argument('action', choices=['init','show','record','amend','status','export'])
    p.add_argument('--start', type=int, default=1)
    p.add_argument('--end', type=int)
    p.add_argument('--db', type=Path, default=ROOT/'assets/content.sqlite')
    a = p.parse_args()
    if a.action == 'init':
        initialize(); return
    if a.action == 'export':
        with sqlite3.connect(a.db.resolve().as_uri()+'?mode=ro', uri=True) as db:
            print(json.dumps(export_review(db, FOLDER), ensure_ascii=False, indent=2))
        return
    rows = read(FOLDER / 'input.jsonl')
    if a.action == 'show':
        for row in rows:
            if a.start <= row['index'] <= a.end:
                print(f"{row['index']}|{row['ja']}|{row['before']}")
    elif a.action == 'record':
        record(rows, a.start, a.end)
    elif a.action == 'amend':
        amend(rows)
    else:
        path = FOLDER / 'decisions.jsonl'
        decisions = read(path) if path.exists() else []
        reviewed = {r['index'] for r in decisions}
        missing = [r['index'] for r in rows if r['index'] not in reviewed]
        print(dict(total=len(rows), reviewed=len(decisions), changed=sum(r['decision']=='corrected' for r in decisions), next=missing[:10]))


if __name__ == '__main__':
    main()
