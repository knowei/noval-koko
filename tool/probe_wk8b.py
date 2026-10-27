import sys, re, requests
sys.stdout.reconfigure(encoding='utf-8')
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
def gets(u, ref=None, method="get", data=None):
    s=requests.Session(); s.trust_env=False
    h={"User-Agent":UA,"Accept-Language":"zh-CN,zh;q=0.9"}
    if ref: h["Referer"]=ref
    r = s.get(u, headers=h, timeout=20) if method=="get" else s.post(u, headers=h, data=data, timeout=20)
    r.encoding=r.apparent_encoding
    return r

u="https://www.wenku8.net/novel/2/2163/78330.htm"
r=gets(u, ref="https://www.wenku8.net/novel/2/2163/index.htm")
h=r.text
print("== chapter", r.status_code, len(r.content), r.encoding)
print("  title:", re.search(r'<title>(.*?)</title>', h, re.S).group(1).strip() if '<title>' in h else '?')
print("  #content present:", 'id="content"' in h, "| #contentmain:", 'id="contentmain"' in h)
m=re.search(r'<div id="content"[^>]*>(.*?)</div>', h, re.S)
if m:
    t=re.sub(r'<br\s*/?>','\n',m.group(1)); t=re.sub(r'<[^>]+>','',t)
    print("  text len:", len(t.strip()))
    print("  head:", t.strip()[:150].replace("\n"," / "))
print("  nav links:", re.findall(r'href="(\d+\.htm)"[^>]*>([^<]{1,10})</a>', h)[:6])
# search
for kw in ["妹妹人生","剑来"]:
    for tmpl in ["https://www.wenku8.net/modules/article/search.php?searchkey={}",
                 "https://www.wenku8.net/modules/article/search.php?searchtype=articlename&searchkey={}"]:
        try:
            url=tmpl.format(requests.utils.quote(kw.encode("gbk")))
            rr=gets(url, ref="https://www.wenku8.net/")
            links=re.findall(r'href="(/book/\d+\.htm)"[^>]*>([^<]{1,40})', rr.text)
            print(f"[{kw}] {rr.status_code} {len(rr.content)}B hits={len(links)} {links[:3]}")
        except Exception as e:
            print(f"[{kw}] ERR {type(e).__name__} {str(e)[:60]}")
