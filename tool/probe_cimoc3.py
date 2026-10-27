import sys, json, re, time
sys.stdout.reconfigure(encoding='utf-8')
import requests
from concurrent.futures import ThreadPoolExecutor

d=json.load(open("tool/cimoc_bases.json",encoding="utf-8"))
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
def base_of(v):
    if isinstance(v, dict): return (v.get("baseUrl") or "").strip()
    if isinstance(v, str): return v.strip()
    return ""
items=[]
for k,v in d.items():
    b=base_of(v)
    if b: items.append((k,b))
print("entries:", len(items))

def probe(item):
    k,b=item
    s=requests.Session(); s.trust_env=False
    s.headers.update({"User-Agent":UA,"Accept-Language":"zh-CN,zh;q=0.9",
                      "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"})
    t0=time.time()
    try:
        r=s.get(b, timeout=12, allow_redirects=True)
        ms=int((time.time()-t0)*1000)
        r.encoding=r.apparent_encoding
        m=re.search(r'<title[^>]*>(.*?)</title>', r.text, re.S)
        title=(m.group(1).strip()[:40] if m else '')
        return {"key":k,"base":b,"ok":True,"status":r.status_code,"bytes":len(r.content),
                "final":r.url,"ms":ms,"title":title}
    except Exception as e:
        ms=int((time.time()-t0)*1000)
        return {"key":k,"base":b,"ok":False,"status":0,"bytes":0,"final":"","ms":ms,
                "title":"","err":f"{type(e).__name__}: {str(e)[:70]}"}

with ThreadPoolExecutor(max_workers=16) as ex:
    res=list(ex.map(probe, items))
json.dump(res, open("tool/cimoc_probe.json","w",encoding="utf-8"), ensure_ascii=False, indent=1)
ok=[r for r in res if r["ok"] and r["status"]<400]
print("可达:", len(ok), "/", len(res))
for r in sorted(ok, key=lambda x:x["key"]):
    print(f"  {r['key']:22s} {r['status']} {r['bytes']:7d} {r['ms']:5d}ms {r['base'][:46]:48s} {r['title'][:26]}")
print("\n不可达:", len(res)-len(ok))
for r in sorted([x for x in res if not (x['ok'] and x['status']<400)], key=lambda x:x["key"]):
    why = r.get("err") or f"HTTP {r['status']}"
    print(f"  {r['key']:22s} {why[:64]:66s} {r['base'][:40]}")
