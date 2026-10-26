import urllib.request, urllib.parse, gzip, re
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
def get(u, ref=None):
    h = {"User-Agent": UA, "Accept": "text/html,*/*;q=0.8", "Accept-Language":"zh-CN,zh;q=0.9", "Referer": ref or u}
    r = urllib.request.Request(u, headers=h)
    try:
        with urllib.request.urlopen(r, timeout=25) as resp:
            raw = resp.read()
            if resp.headers.get("Content-Encoding") == "gzip": raw = gzip.decompress(raw)
            return resp.status, raw, resp.geturl()
    except Exception as e:
        return None, str(e)[:60].encode(), u

for u in ["https://m.linovelib.com/", "https://m.linovelib.com/S6/", "https://www.linovelib.com/novel/2601/40988.html"]:
    st, raw, final = get(u)
    print(st, len(raw) if isinstance(raw, bytes) else raw, final)

st, raw, final = get("https://www.linovelib.com/novel/2601.html")
open("tool/ln_probe/lib_book.html","wb").write(raw)
st, raw, final = get("https://www.linovelib.com/novel/2601/catalog")
open("tool/ln_probe/lib_catalog.html","wb").write(raw)
print("saved", st)

# chapter url discovery from catalog
cat = open("tool/ln_probe/lib_catalog.html", encoding="utf-8", errors="replace").read()
hrefs = re.findall(r'href="([^"]+)"', cat)
import collections
print("catalog links sample:", [h for h in hrefs if h.startswith("/novel/2601/")][:8])
