"""Resumable local example translation candidates. Never certifies a translation.

The model weights stay outside the APK. Source English is itself a translation:
these drafts require a Japanese/Korean meaning and naturalness review.
"""
import argparse, hashlib, json, re, sqlite3, sys, time
from pathlib import Path
from localization_common import append_jsonl, read_jsonl

def issues(text):
    out=[]
    if not re.search('[가-힣]',text):out.append('no_korean')
    if re.search(r'(.{2,15})\1\1',text):out.append('repetition')
    if re.search('[ぁ-んァ-ヶ一-鿿]',text):out.append('untranslated_script')
    return out

def main():
    import ctranslate2
    from transformers import M2M100Tokenizer
    p=argparse.ArgumentParser();p.add_argument('--db',required=True);p.add_argument('--model',required=True);p.add_argument('--out',default='pipeline/localization/example_machine_drafts.jsonl');p.add_argument('--threads',type=int,default=8);a=p.parse_args()
    cache=Path(a.out).with_suffix('.cache.jsonl')
    known={r['key']:r for r in read_jsonl(cache)}
    with sqlite3.connect(a.db) as db:
        examples=db.execute('SELECT example_id,text_ja,text_en FROM examples ORDER BY word_id,sequence').fetchall()
    unique={hashlib.sha256((ja+'\0'+en).encode()).hexdigest():(ja,en) for _,ja,en in examples if en}
    missing=[(k,*v) for k,v in unique.items() if k not in known]
    tok=M2M100Tokenizer.from_pretrained(a.model,local_files_only=True);tok.src_lang='en'
    model=ctranslate2.Translator(a.model,device='cpu',compute_type='int8',inter_threads=1,intra_threads=a.threads)
    t=time.time()
    for start in range(0,len(missing),32):
        batch=missing[start:start+32]
        tokens=[tok.convert_ids_to_tokens(tok.encode(en)) for _,ja,en in batch]
        results=model.translate_batch(tokens,target_prefix=[['__ko__']]*len(batch),beam_size=4,max_decoding_length=180,repetition_penalty=1.1)
        for (key,ja,en),r in zip(batch,results):
            value=tok.decode(tok.convert_tokens_to_ids(r.hypotheses[0]),skip_special_tokens=True).strip()
            row=dict(key=key,value=value,qa_flags=issues(value));append_jsonl(cache,row);known[key]=row
        if start%320==0:print('translated',min(start+32,len(missing)),'/',len(missing),'seconds',round(time.time()-t),flush=True)
    with Path(a.out).open('w') as f:
        for eid,ja,en in examples:
            key=hashlib.sha256((ja+'\0'+en).encode()).hexdigest();r=known.get(key)
            if not r or 'no_korean' in r['qa_flags'] or 'repetition' in r['qa_flags']:continue
            row=dict(entity_type='example',entity_id=eid,value=r['value'],method='local_machine_translation_en_to_ko',sources=['https://huggingface.co/jncraton/m2m100_418M-ct2-int8/tree/7c1b2620a4e58dacecbd8bf89cfd6da7eb9eb7b0','https://github.com/evanclan/OpenJLPT'],source=dict(text_ja=ja,text_en=en),qa_flags=r['qa_flags'],notes=['원자료 영어 번역에서 생성한 기계 번역 초안. 일본어 대조·문맥·자연스러움 검수 필요.'],human_review_required=True)
            f.write(json.dumps(row,ensure_ascii=False)+'\n')
    print('completed',len(known),flush=True)
if __name__=='__main__':main()
