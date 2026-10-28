#!/usr/bin/env python3
"""Download public primary-source files with TLS verification and record hashes."""
import argparse,hashlib,json,os
from datetime import datetime,timezone
from pathlib import Path
from urllib.request import Request,urlopen
SOURCES={
 'OpenJLPT-main.zip':'https://codeload.github.com/evanclan/OpenJLPT/zip/refs/heads/main',
 'JMdict_e.gz':'https://www.edrdg.org/pub/Nihongo/JMdict_e.gz',
}
def main():
    p=argparse.ArgumentParser();p.add_argument('--out',type=Path,default=Path('downloads'));a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
    manifest={}
    for name,url in SOURCES.items():
        output=a.out/name;tmp=output.with_suffix(output.suffix+'.part');h=hashlib.sha256()
        print('Downloading',url,flush=True)
        try:
            with urlopen(Request(url,headers={'User-Agent':'JLPT-offline-study/1.0'}),timeout=180) as r,tmp.open('wb') as f:
                for data in iter(lambda:r.read(1024*1024),b''):f.write(data);h.update(data)
            os.replace(tmp,output)
        except Exception:
            tmp.unlink(missing_ok=True)
            raise
        manifest[name]={'url':url,'sha256':h.hexdigest(),'bytes':output.stat().st_size,'downloaded_at':datetime.now(timezone.utc).isoformat()}
        (a.out/'source_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__':main()
