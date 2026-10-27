import sys, json, requests
sys.stdout.reconfigure(encoding='utf-8')
url="https://www.cimoc.top/cimoc/sourc/master/raw/sourceBaseUrl.json"
s=requests.Session(); s.trust_env=False
s.headers.update({"User-Agent":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"})
try:
    r=s.get(url, timeout=25)
    print("status", r.status_code, "bytes", len(r.content))
    print("ctype", r.headers.get("content-type"))
    open("tool/cimoc_bases.json","wb").write(r.content)
    txt=r.text
    print("head:", txt[:400].replace("\n"," "))
except Exception as e:
    print("ERR", type(e).__name__, str(e)[:120])
