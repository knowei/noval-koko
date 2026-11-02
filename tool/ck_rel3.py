import re,sys,urllib.request
sys.stdout.reconfigure(encoding="utf-8")
op=urllib.request.build_opener(urllib.request.ProxyHandler({"http":"http://127.0.0.1:7897","https":"http://127.0.0.1:7897"}))
op.addheaders=[("User-Agent","Mozilla/5.0"),("Accept-Language","zh-CN")]
def get(u): return op.open(u,timeout=30).read().decode("utf-8","ignore")
a=get("https://github.com/knowei/noval-koko/releases/expanded_assets/v0.7.1")
for m in re.finditer(r'/releases/download/v0\.7\.1/([^"]+)".*?>([\d.]+ [KMG]B)<', a, re.S):
    print(f"  {m.group(1):38s} {m.group(2)}")
r=get("https://github.com/knowei/noval-koko/releases/tag/v0.7.1")
body=re.search(r'<div class="markdown-body[^"]*"[^>]*>(.*?)</div>\s*</div>', r, re.S)
if body:
    t=re.sub(r'<[^>]+>','',body.group(1))
    t=re.sub(r'\n{2,}','\n',t).strip()
    print("--- release notes (前 700 字) ---")
    print(t[:700])
badge=re.findall(r'octicon-check[^>]*>|octicon-x[^>]*>', get("https://github.com/knowei/noval-koko/actions/runs/41420670408"))
print("check icons:", len(badge))
