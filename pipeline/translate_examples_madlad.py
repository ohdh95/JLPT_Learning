"""Resumable Japanese -> Korean translation with MADLAD; review status stays draft."""
import argparse,hashlib,json,re,sqlite3,time
from pathlib import Path
from localization_common import read_jsonl,append_jsonl

MODEL='https://huggingface.co/Nextcloud-AI/madlad400-3b-mt-ct2-int8/tree/aa32bbdeba7880eff2096ec044cb155a340a9400'
def flags(text,ja):
    issues=[]
    if not re.search('[가-힣]',text):issues.append('no_korean')
    if re.search(r'(.{2,15})\1\1',text):issues.append('repetition')
    if re.search('[ぁ-んァ-ヶ一-鿿]',text):issues.append('untranslated_script')
    if len(text)>max(80,len(ja)*4):issues.append('long_output')
    return issues

def main():
    import ctranslate2
    from transformers import T5Tokenizer
    p=argparse.ArgumentParser();p.add_argument('--db',required=True);p.add_argument('--model',required=True)
    p.add_argument('--out',default='pipeline/localization/example_madlad_drafts.jsonl');p.add_argument('--sample',type=int);p.add_argument('--threads',type=int,default=8)
    a=p.parse_args();cache=Path(a.out).with_suffix('.cache.jsonl');known={r['key']:r for r in read_jsonl(cache)}
    with sqlite3.connect(a.db) as db:rows=db.execute('SELECT example_id,text_ja,text_en FROM examples ORDER BY word_id,sequence').fetchall()
    unique={hashlib.sha256(ja.encode()).hexdigest():ja for _,ja,en in rows}
    missing=[(k,ja) for k,ja in unique.items() if k not in known]
    if a.sample:missing=missing[:a.sample]
    tok=T5Tokenizer.from_pretrained(a.model,local_files_only=True,legacy=True)
    model=ctranslate2.Translator(a.model,device='cpu',compute_type='int8',inter_threads=1,intra_threads=a.threads)
    t=time.time()
    for start in range(0,len(missing),24):
        batch=missing[start:start+24]
        tokens=[tok.convert_ids_to_tokens(tok.encode('<2ko> '+ja)) for k,ja in batch]
        result=model.translate_batch(tokens,beam_size=3,max_decoding_length=180,repetition_penalty=1.1)
        for (key,ja),r in zip(batch,result):
            text=tok.decode(tok.convert_tokens_to_ids(r.hypotheses[0]),skip_special_tokens=True).strip()
            row={'key':key,'source_ja':ja,'value':text,'qa_flags':flags(text,ja)};append_jsonl(cache,row);known[key]=row
        print('translated',min(start+24,len(missing)),'/',len(missing),'seconds',round(time.time()-t),flush=True)
    with Path(a.out).open('w') as f:
        for eid,ja,en in rows:
            key=hashlib.sha256(ja.encode()).hexdigest();r=known.get(key)
            if not r:continue
            row=dict(entity_type='example',entity_id=eid,value=r['value'],method='madlad_ja_ko_translation',sources=[MODEL,'https://github.com/evanclan/OpenJLPT'],source=dict(text_ja=ja,text_en=en),qa_flags=r['qa_flags'],human_review_required=True,notes=['일본어 원문에서 직접 생성한 한국어 번역. 자동 형식 검사와 개별 교정 이력은 별도 보존. 독립 사람 검수 완료 아님.'])
            f.write(json.dumps(row,ensure_ascii=False)+'\n')
    print('completed',len(known),flush=True)
if __name__=='__main__':main()
