import re,sys,urllib.request
sys.stdout.reconfigure(encoding="utf-8")
op=urllib.request.build_opener(urllib.request.ProxyHandler({"http":"http://127.0.0.1:7897","https":"http://127.0.0.1:7897"}))
op.addheaders=[("User-Agent","Mozilla/5.0"),("Accept-Language","zh-CN")]
def get(u):
    return op.open(u,timeout=30).read().decode("utf-8","ignore")
h=get("https://github.com/knowei/noval-koko/actions/runs/41420670408")
m=re.search(r'<title>(.*?)</title>',h,re.S); print("title:", m.group(1).strip() if m else "?")
for kw in ["in progress","Success","Failure","queued","In progress","completed"]:
    if kw in h: print("contains:", kw)
a=get("https://github.com/knowei/noval-koko/releases/expanded_assets/v0.7.1")
names=re.findall(r'href="(/knowei/noval-koko/releases/download/v0\.7\.1/[^"]+)"',a)
sizes=re.findall(r'<span[^>]*class="[^"]*text-xs[^"]*"[^>]*>\s*([\d.]+\s*[KM]B)\s*</span>',a)
print("assets:", len(names))
for n in names: print("  ", n.split("/")[-1])
print("sizes:", sizes)
