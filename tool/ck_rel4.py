import re,sys,urllib.request
sys.stdout.reconfigure(encoding="utf-8")
op=urllib.request.build_opener(urllib.request.ProxyHandler({"http":"http://127.0.0.1:7897","https":"http://127.0.0.1:7897"}))
op.addheaders=[("User-Agent","Mozilla/5.0")]
def get(u): return op.open(u,timeout=30).read().decode("utf-8","ignore")
h=get("https://github.com/knowei/noval-koko/actions/runs/41420670408")
for kw in ["Success","Failure","completed"]:
    print(kw, "->", h.count(kw))
r=get("https://github.com/knowei/noval-koko/releases/tag/v0.7.1")
i=r.find("markdown-body")
seg=re.sub(r'<[^>]+>','',r[i:i+4000]).replace("&quot;",'"').replace("&#39;","'").replace("&amp;","&")
seg=re.sub(r'\n{2,}','\n',seg).strip()
print("--- notes ---"); print(seg[:600])
