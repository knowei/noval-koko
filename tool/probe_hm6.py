import sys, re, requests
sys.stdout.reconfigure(encoding='utf-8')
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
s=requests.Session(); s.trust_env=False
s.headers.update({"User-Agent":UA,"Accept-Language":"zh-CN,zh;q=0.9"})
def g(u, ref=None):
    h={}
    if ref: h["Referer"]=ref
    r=s.get(u, headers=h, timeout=25); r.encoding=r.apparent_encoding
    return r

print("=== search with key param ===")
for kw in ["妹妹人生","剑来","史莱姆"]:
    r=g("https://www.huanmengacg.com/index.php/book/search?key="+requests.utils.quote(kw),
        ref="https://www.huanmengacg.com/")
    h=r.text
    items=re.findall(r'<a href="(/index\.php/book/info/(\d+))"[^>]*>(.*?)</a>', h, re.S)
    title=[re.sub(r'<[^>]+>','',x[2]).strip()[:24] for x in items]
    print(" %s -> %s %dB items=%d %s" % (kw, r.status_code, len(r.content), len(items), title[:5]))
