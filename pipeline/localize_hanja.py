"""Generate source-backed Korean hun/eum drafts, preserving variant provenance."""
from __future__ import annotations
import argparse, collections, json, re, sqlite3, unicodedata
from pathlib import Path
from localization_common import dump

LIB_URL='https://github.com/libhangul/libhangul/blob/main/data/hanja/hanja.txt'
UNI_URL='https://www.unicode.org/Public/17.0.0/ucd/Unihan.zip'

def load_hanja(path):
    result=collections.defaultdict(list)
    for line in Path(path).read_text().splitlines():
        if line.startswith('#') or line.count(':')<2: continue
        eum,char,description=line.split(':',2)
        if len(char)!=1 or not re.fullmatch('[가-힣]',eum):continue
        char=unicodedata.normalize('NFKC',char)
        for part in description.split(','):
            part=part.strip()
            if part.endswith(' '+eum):
                hun=part[:-len(eum)].strip()
            else:
                hun=part
            if re.search('[가-힣]',hun) and not re.search('[一-鿿]',hun) and '同字' not in hun and '俗字' not in hun and '略字' not in hun:
                record=(hun,eum)
                if record not in result[char]:result[char].append(record)
    return result

def choose(char, entries, unihan, existing=None):
    if existing and tuple(existing) in entries:return tuple(existing)
    # E is the educational/basic-hanja source, not a correctness certificate.
    edu={x.split(':')[0] for x in unihan.get(char,{}).get('kHangul','').split() if 'E' in x.split(':')[-1]}
    preferred=[p for p in entries if p[1] in edu]
    return (preferred or entries)[0]

def generate(db, data, unihan, variants, overrides):
    rows=[];missing=[]
    for char,oldhun,oldeum in db.execute('SELECT character,korean_hun,korean_eum FROM kanji ORDER BY jlpt_level DESC,character'):
        source_char=unicodedata.normalize('NFKC',char);method='libhangul';notes=[];sources=[LIB_URL,UNI_URL]
        if char in overrides:
            o=overrides[char];hun,eum=o['hun'],o['eum'];notes=[o['note']];sources+=o['sources'];method='assistant_source_comparison'
            source_char=o.get('source_character',source_char)
            entries=data.get(source_char,[])
        else:
            if source_char in variants:
                source_char=variants[source_char];method='libhangul_curated_variant'
            entries=data.get(source_char,[])
            if not entries:
                candidates=[]
                for field in ['kTraditionalVariant','kZVariant','kSemanticVariant']:
                    for hexchar in re.findall(r'U\+([0-9A-F]+)',unihan.get(source_char,{}).get(field,'')):
                        other=chr(int(hexchar,16))
                        if data.get(other) and other not in candidates:candidates.append(other)
                    if candidates:break
                if len(candidates)==1:
                    source_char=candidates[0];entries=data[source_char];method='libhangul_unihan_variant'
                elif len(candidates)>1:notes.append('ambiguous_variant:'+','.join(candidates))
            if not entries:
                missing.append({'character':char,'notes':notes});continue
            hun,eum=choose(source_char,entries,unihan,[oldhun,oldeum])
        readings={x.split(':')[0] for x in unihan.get(source_char,{}).get('kHangul','').split()}
        if source_char!=char:notes.append(f'일본 표기 {char}의 대응 한자 {source_char}를 참조')
        if len({p[1] for p in entries})>1:notes.append('여러 한국음 중 대표 훈음; 단어별 독음 분해와 다름')
        rows.append({'entity_type':'kanji','entity_id':char,'value':{'hun':hun,'eum':eum},'method':method,
            'sources':sources,'source_character':source_char,'alternatives':[list(p) for p in entries],
            'reading_crosscheck':'match' if eum in readings else ('mismatch' if readings else 'not_available'),
            'notes':notes})
    return rows,missing

def add_word_components(db):
    """Supplement word components without inventing JLPT levels or Japanese readings."""
    chars=[r[0] for r in db.execute('SELECT DISTINCT character FROM word_kanji WHERE character NOT IN (SELECT character FROM kanji) ORDER BY character')]
    with db:
        for char in chars:
            db.execute("INSERT INTO kanji(character,onyomi_json,kunyomi_json,meanings_en_json) VALUES(?,'[]','[]','[]')",[char])
        db.execute('INSERT OR REPLACE INTO source_info VALUES(?,?)',[
            'supplemental_word_kanji',dump({'characters':[r[0] for r in db.execute('SELECT character FROM kanji WHERE jlpt_level IS NULL ORDER BY character')],
                'origin':'OpenJLPT word_kanji components; hun/eum sources in localization_provenance',
                'jlpt_level_assigned':False,'japanese_readings_inferred':False})])
    return chars

def main():
    p=argparse.ArgumentParser();p.add_argument('--db',type=Path,required=True);p.add_argument('--sources',type=Path,default=Path('downloads/localization'));p.add_argument('--out',type=Path,default=Path('pipeline/localization/hanja_candidates.jsonl'));p.add_argument('--include-word-components',action='store_true');a=p.parse_args()
    base=Path(__file__).parent/'localization'
    with sqlite3.connect(a.db) as db:
        if a.include_word_components:add_word_components(db)
        rows,missing=generate(db,load_hanja(a.sources/'libhangul-hanja.txt'),json.loads((a.sources/'unihan-fields.json').read_text()),json.loads((base/'kanji_variants.json').read_text()),json.loads((base/'hanja_overrides.json').read_text()))
    a.out.write_text(''.join(dump(r)+'\n' for r in rows))
    a.out.with_suffix('.missing.json').write_text(json.dumps(missing,ensure_ascii=False,indent=2))
    print(dump({'drafts':len(rows),'missing':missing,'reading_checks':dict(collections.Counter(r['reading_crosscheck'] for r in rows))}))

if __name__=='__main__':main()
