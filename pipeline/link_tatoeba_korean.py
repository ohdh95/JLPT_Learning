"""Use only direct Japanese/Korean links, with exact source-text matching.

A community translation is still a draft in this app, not a human review of our
word sense or example suitability. Sentence IDs/authors/licenses are retained.
"""
import argparse,bz2,collections,json,sqlite3,tarfile
from pathlib import Path

def main():
    p=argparse.ArgumentParser();p.add_argument('--db',required=True);p.add_argument('--sources',type=Path,default=Path('downloads/localization'));p.add_argument('--out',type=Path,default=Path('pipeline/localization/example_tatoeba_drafts.jsonl'));a=p.parse_args()
    with sqlite3.connect(a.db) as db:examples=db.execute('SELECT example_id,tatoeba_id,text_ja FROM examples').fetchall()
    wanted={str(tid) for _,tid,_ in examples if tid}
    ko={}
    with bz2.open(a.sources/'kor_sentences_detailed.tsv.bz2','rt') as f:
        for line in f:
            cells=line.rstrip('\n').split('\t')
            if len(cells)>=4:ko[cells[0]]={'text':cells[2],'author':cells[3]}
    linked=collections.defaultdict(set)
    with tarfile.open(a.sources/'links.tar.bz2','r|bz2') as archive:
        for member in archive:
            if member.name!='links.csv':continue
            for line in archive.extractfile(member):
                src,dst=line.decode().strip().split('\t')
                if src in wanted and dst in ko:linked[src].add(dst)
                elif dst in wanted and src in ko:linked[dst].add(src)
    ja={}
    with bz2.open(a.sources/'jpn_sentences.tsv.bz2','rt') as f:
        for line in f:
            sid,lang,text=line.rstrip('\n').split('\t',2)
            if sid in linked:ja[sid]=text
    rows=[];changed=[]
    for eid,tid,text in examples:
        sid=str(tid)
        if sid not in linked:continue
        if ja.get(sid)!=text:
            changed.append({'example_id':eid,'tatoeba_id':tid,'original':text,'current':ja.get(sid)});continue
        kid=min(linked[sid],key=int);translation=ko[kid]
        rows.append(dict(entity_type='example',entity_id=eid,value=translation['text'],method='tatoeba_direct_link',sources=[f'https://tatoeba.org/en/sentences/show/{sid}',f'https://tatoeba.org/en/sentences/show/{kid}'],tatoeba_korean_id=int(kid),tatoeba_author=translation['author'],license='CC BY 2.0 FR',license_url='https://creativecommons.org/licenses/by/2.0/fr/',alternatives=[{'id':k,**ko[k]} for k in sorted(linked[sid],key=int)],notes=['직접 번역 링크와 일본어 원문 완전 일치 확인. 앱 문맥·한국어 자연스러움에 대한 사람 검수 완료 아님.'],human_review_required=True))
    a.out.write_text(''.join(json.dumps(r,ensure_ascii=False)+'\n' for r in rows))
    a.out.with_suffix('.rejected.json').write_text(json.dumps(changed,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'direct_linked_drafts':len(rows),'changed_source_text_rejected':len(changed),'korean_sentences':len(ko)},ensure_ascii=False))
if __name__=='__main__':main()
