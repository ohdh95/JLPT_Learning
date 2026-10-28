"""Resumable public-text translation. Strict source-segment alignment, paced retries.

Uses the public Google Translate web endpoint without account credentials or a
paid API. This endpoint is not a contracted API; failures stop rather than
silently importing misaligned translations. App runtime remains fully offline.
"""
import argparse,bisect,hashlib,json,re,sqlite3,time
from pathlib import Path
from localization_common import read_jsonl,append_jsonl
from translate_examples_madlad import flags
URL='https://translate.googleapis.com/translate_a/single'

def align(texts,segments):
    source='\n'.join(texts);starts=[];offset=0
    for text in texts:starts.append(offset);offset+=len(text)+1
    result=['']*len(texts);offset=0
    for segment in segments:
        translated,original=segment[:2]
        if not original or translated is None:raise ValueError('Missing aligned segment')
        if source[offset:offset+len(original)]!=original:raise ValueError('Source response mismatch')
        i=bisect.bisect_right(starts,offset)-1
        end=starts[i]+len(texts[i])+(i+1<len(texts))
        if offset+len(original)>end:raise ValueError('Segment crosses example boundary')
        result[i]+=translated;offset+=len(original)
    if offset!=len(source):raise ValueError('Truncated response')
    if any(not x.strip() for x in result):raise ValueError('Empty translation')
    return [x.strip() for x in result]

class Client:
    def __init__(self,delay=1.2):
        import requests
        self.session=requests.Session();self.last=0;self.delay=delay;self.requests=0
    def translate(self,texts):
        time.sleep(max(0,self.delay-(time.monotonic()-self.last)))
        response=None
        for attempt in range(4):
            self.last=time.monotonic();self.requests+=1
            response=self.session.get(URL,params={'client':'gtx','sl':'en','tl':'ko','dt':'t','q':'\n'.join(texts)},timeout=(15,60))
            if response.status_code in (429,500,502,503,504):
                if attempt==3:response.raise_for_status()
                time.sleep(min(60,15*(2**attempt)));continue
            response.raise_for_status();break
        try:return align(texts,response.json()[0])
        except (ValueError,IndexError,TypeError):
            if len(texts)==1:raise
            middle=len(texts)//2
            return self.translate(texts[:middle])+self.translate(texts[middle:])

def main():
    p=argparse.ArgumentParser();p.add_argument('--db',required=True);p.add_argument('--out',default='pipeline/localization/example_service_drafts.jsonl');p.add_argument('--delay',type=float,default=1.2);a=p.parse_args()
    cache=Path(a.out).with_suffix('.cache.jsonl');known={r['key']:r for r in read_jsonl(cache)}
    with sqlite3.connect(a.db) as db:rows=db.execute('SELECT example_id,text_ja,text_en FROM examples ORDER BY word_id,sequence').fetchall()
    clean=lambda text:re.sub(r'\s+',' ',text).strip()
    unique={hashlib.sha256(clean(en).encode()).hexdigest():clean(en) for _,ja,en in rows if en}
    missing=[(k,en) for k,en in unique.items() if k not in known];client=Client(a.delay);start=time.time();index=0
    while index<len(missing):
        batch=[];length=0
        while index<len(missing) and len(batch)<28:
            k,en=missing[index]
            if batch and length+len(en)>2600:break
            batch.append((k,en));length+=len(en)+1;index+=1
        values=client.translate([en for k,en in batch])
        for (key,en),value in zip(batch,values):
            row=dict(key=key,source_en=en,value=value);append_jsonl(cache,row);known[key]=row
        print('translated',index,'/',len(missing),'requests',client.requests,'seconds',round(time.time()-start),flush=True)
    with Path(a.out).open('w') as f:
        for eid,ja,en in rows:
            key=hashlib.sha256(clean(en).encode()).hexdigest();r=known[key]
            row=dict(entity_type='example',entity_id=eid,value=r['value'],method='google_en_ko_translation',sources=['https://translate.google.com/','https://github.com/evanclan/OpenJLPT'],source=dict(text_ja=ja,text_en=en),qa_flags=flags(r['value'],ja),human_review_required=True,notes=['원자료의 영어 풀이에서 한국어로 번역. 응답의 원문 구간을 요청과 완전 대조하여 예문별 대응 확인. 독립 사람 검수 완료 아님.'])
            f.write(json.dumps(row,ensure_ascii=False)+'\n')
    print('complete examples',len(rows),'unique English',len(known),flush=True)
if __name__=='__main__':main()
