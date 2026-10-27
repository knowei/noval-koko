import sys, re
import requests
sys.stdout.reconfigure(encoding='utf-8')
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
def S():
    s=requests.Session(); s.trust_env=False
    s.headers.update({"User-Agent":UA,"Accept-Language":"zh-CN,zh;q=0.9"})
    return s
def show(name, u, enc=None):
    try:
        r=S().get(u, timeout=20)
        r.encoding = enc or r.apparent_encoding
        h=r.text
        print(f"== {name} {r.status_code} {len(r.content)}B enc={r.encoding} title={re.search(r'<title>(.*?)</title>', h, re.S).group(1).strip()[:60] if '<title>' in h else '?'}")
        return h
    except Exception as e:
        print(f"== {name} ERR {type(e).__name__}: {str(e)[:80]}")
        return ''

h1=show("wenku8 book", "https://www.wenku8.net/book/2163.htm")
if h1:
    print("  h1:", re.findall(r'<h1[^>]*>(.*?)</h1>', h1, re.S)[:2])
    print("  table links:", re.findall(r'href="(/book/\d+\.htm)"', h1)[:3])
    print("  chapter/catalog links:", re.findall(r'href="([^"]*(?:index|chapter|read)[^"]*)"', h1)[:8])
    print("  meta:", re.findall(r'<meta[^>]*(?:og:|keywords|description)[^>]*>', h1)[:4])
    print("  info text:", re.sub(r'\s+',' ',re.sub(r'<[^>]+>',' ',h1))[:300])
