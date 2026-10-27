import sys, re
import requests
sys.stdout.reconfigure(encoding='utf-8')
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
def gets(u, ref=None, enc=None):
    s=requests.Session(); s.trust_env=False
    h={"User-Agent":UA,"Accept-Language":"zh-CN,zh;q=0.9"}
    if ref: h["Referer"]=ref
    r=s.get(u, headers=h, timeout=20)
    r.encoding = enc or r.apparent_encoding
    return r

# 1) wenku8 catalog
u="https://www.wenku8.net/novel/2/2163/index.htm"
r=gets(u, ref="https://www.wenku8.net/book/2163.htm")
h=r.text
print("== wenku8 catalog", r.status_code, len(r.content), r.encoding)
print("  title:", re.search(r'<title>(.*?)</title>', h, re.S).group(1).strip() if '<title>' in h else '?')
cls=re.findall(r'<td class="ccss">.*?</td>', h, re.S)
print("  td.ccss count:", len(cls))
links=re.findall(r'<a href="([^"]+\.htm)"[^>]*>([^<]{1,40})</a>', h)
print("  links sample:", links[:6], "total", len(links))
# 2) first chapter
if links:
    cu=requests.compat.urljoin(u, links[0][0])
    r2=gets(cu, ref=u)
    h2=r2.text
    print("== wenku8 chapter", r2.status_code, len(r2.content), cu)
    print("  title:", re.search(r'<title>(.*?)</title>', h2, re.S).group(1).strip() if '<title>' in h2 else '?')
    for pat in [r'id="content"', r'id="contentmain"', r'id="booktext"', r'class="content"']:
        print(f"  {pat}: {len(re.findall(pat,h2))}")
    body=re.search(r'<div id="content"[^>]*>(.*?)</div>\s*<', h2, re.S)
    if body:
        txt=re.sub(r'<br\s*/?>','\n',body.group(1))
        txt=re.sub(r'<[^>]+>','',txt)
        print("  content len:", len(txt.strip()), "| head:", txt.strip()[:120].replace("\n"," / "))
