"""Build offline, morphology-aware links from example spans to stable word IDs.

Sudachi is build-time only. Store UTF-16 offsets for Dart, preserving original
text, reading restrictions, multiple homographs, and source lexemes separately.
"""
import argparse, collections, importlib.metadata, json, sqlite3, unicodedata
import gzip
from xml.etree.ElementTree import iterparse
from pathlib import Path

SCHEMA='''CREATE TABLE IF NOT EXISTS example_word_links(
 example_id TEXT NOT NULL REFERENCES examples(example_id) ON DELETE CASCADE,
 start_offset INTEGER NOT NULL, end_offset INTEGER NOT NULL,
 word_id TEXT NOT NULL REFERENCES vocab(word_id) ON DELETE CASCADE,
 match_form TEXT NOT NULL,
 PRIMARY KEY(example_id,start_offset,end_offset,word_id));
CREATE INDEX IF NOT EXISTS example_links_word ON example_word_links(word_id);'''

def kana(text):
    text=unicodedata.normalize('NFKC',text)
    return ''.join(chr(ord(c)-0x60) if 'ァ'<=c<='ヶ' else c for c in text)

def utf16(text):return len(text.encode('utf-16-le'))//2

class Matcher:
    def __init__(self, words, tokenizer):
        self.tokenizer=tokenizer;self.surfaces=collections.defaultdict(list)
        for wid,surface,reading in words:self.surfaces[surface].append((wid,kana(reading)))
        self.max_len=max(map(len,self.surfaces),default=0)
    def candidates(self, form, reading=None):
        rows=self.surfaces.get(form,[])
        if reading:
            matching=[wid for wid,r in rows if r==kana(reading)]
            if matching:return matching
            # Sudachi may choose another valid reading (明日: あす/あした).
            # Keep exact-headword lookup available; do not assert contextual sense.
        return [wid for wid,_ in rows]
    def spans(self, text):
        from sudachipy import tokenizer
        tokens=list(self.tokenizer.tokenize(text,tokenizer.Tokenizer.SplitMode.A))
        found=[];i=0
        while i<len(tokens):
            token=tokens[i];start=token.begin();best=None
            # Longest whole-token surface match: never link fragments inside words.
            for j in range(i,min(i+12,len(tokens))):
                end=tokens[j].end();form=text[start:end]
                if len(form)>self.max_len:break
                reading=''.join(t.reading_form() for t in tokens[i:j+1])
                ids=self.candidates(form,reading)
                if ids:best=(j+1,end,ids,form)
            if best is None:
                lemma=token.dictionary_form()
                # Conjugated verbs/adjectives link to their dictionary headword.
                if token.part_of_speech()[0] in ('動詞','形容詞','助動詞'):
                    ids=self.candidates(lemma)
                    if ids:best=(i+1,token.end(),ids,lemma)
                if best is None:
                    normalized=token.normalized_form()
                    ids=self.candidates(normalized,token.reading_form())
                    if ids:best=(i+1,token.end(),ids,normalized)
            if best:
                next_i,end,ids,form=best
                found.extend((utf16(text[:start]),utf16(text[:end]),wid,form) for wid in sorted(set(ids)))
                i=next_i
            else:i+=1
        return found

def dictionary_aliases(db,path):
    targets=collections.defaultdict(list)
    for wid,reading,jid in db.execute("SELECT word_id,reading_kana,jmdict_id FROM vocab WHERE reading_check='direct_jmdict_verified'"):
        targets[jid].append((wid,reading))
    result=[]
    with gzip.open(path,'rb') as f:
        for _,node in iterparse(f,events=('end',)):
            if node.tag!='entry':continue
            words=targets.get(int(node.findtext('ent_seq')),[])
            if words:
                spellings=[el.text for el in node.findall('k_ele/keb')]
                for reading in node.findall('r_ele'):
                    if reading.find('re_nokanji') is not None:continue
                    kana_text=reading.findtext('reb');restrictions={el.text for el in reading.findall('re_restr')}
                    for wid,expected in words:
                        if expected!=kana_text:continue
                        result.extend((wid,form,expected) for form in spellings if not restrictions or form in restrictions)
            node.clear()
    return result

def build(db,jmdict=None):
    from sudachipy import dictionary
    words=list(db.execute('SELECT word_id,surface,reading_kana FROM vocab'))
    aliases=dictionary_aliases(db,jmdict) if jmdict else []
    matcher=Matcher(words+aliases,dictionary.Dictionary().create())
    db.executescript(SCHEMA)
    rows=[];cache={};examples=db.execute('SELECT example_id,text_ja FROM examples').fetchall()
    for eid,text in examples:
        if text not in cache:cache[text]=matcher.spans(text)
        rows.extend((eid,*span) for span in cache[text])
    with db:
        db.execute('DELETE FROM example_word_links')
        db.executemany('INSERT INTO example_word_links VALUES(?,?,?,?,?)',rows)
        report={'examples':len(examples),'examples_linked':len({r[0] for r in rows}),'links':len(rows),
                'linked_words':len({r[3] for r in rows}),'sudachipy':importlib.metadata.version('SudachiPy'),
                'dictionary':importlib.metadata.version('SudachiDict-core'),
                'jmdict_aliases':len(set(aliases)),
                'offsets':'UTF-16','strategy':'longest whole-token surface; conjugated dictionary form; preserve homograph choices',
                'source':'https://github.com/WorksApplications/SudachiPy','certifies_sense':False}
        db.execute('INSERT OR REPLACE INTO source_info VALUES(?,?)',['example_word_links',json.dumps(report,ensure_ascii=False)])
    return report

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--db',required=True);p.add_argument('--report',default='reports/example-links.json');p.add_argument('--jmdict',type=Path);a=p.parse_args()
    with sqlite3.connect(a.db) as db:r=build(db,a.jmdict)
    Path(a.report).write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print(r)
