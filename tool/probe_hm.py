import sys, re, requests
sys.stdout.reconfigure(encoding='utf-8')
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
def g(u, ref=None):
    s=requests.Session(); s.trust_env=False
    h={"User-Agent":UA,"Accept-Language":"zh-CN,zh;q=0.9"}
    if ref: h["Referer"]=ref
    r=s.get(u, headers=h, timeout=25); r.encoding=r.apparent_encoding
    return r
def plain(h): return re.sub(r'\s+',' ',re.sub(r'<[^>]+>',' ',h)).strip()
BOOK = re.compile(r'href="/book/(\d+)\.htm"')

print("### wenku8 list pages")
for u in ["https://www.wenku8.net/modules/article/toplist.php?sort=allvisit",
          "https://www.wenku8.net/modules/article/sort.php?sort=all&page=1"]:
    try:
        r=g(u); n=len(BOOK.findall(r.text))
        print(" %s -> %s %dB books=%d" % (u, r.status_code, len(r.content), n))
    except Exception as e:
        print(" ERR", type(e).__name__, str(e)[:60])

print("### huanmengacg book page")
u="https://www.huanmengacg.com/index.php/book/info/6963"
try:
    r=g(u); h=r.text
    t=re.search(r'<title>(.*?)</title>', h, re.S)
    print(" %s %dB title=%s" % (r.status_code, len(r.content), t.group(1).strip()[:70] if t else '?'))
    print(" h:", [plain(x)[:40] for x in re.findall(r'<h[12][^>]*>(.*?)</h[12]>', h, re.S)][:4])
    print(" links:", re.findall(r'href="([^"]*(?:chapter|read|/book/)[^"]*)"', h)[:8])
    print(" text:", plain(h)[:400])
except Exception as e:
    print(" ERR", type(e).__name__, str(e)[:100])
