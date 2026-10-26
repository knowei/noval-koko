import urllib.request, urllib.parse, gzip
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
def get(url, ref=None):
    r = urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Language": "zh-CN,zh;q=0.9", "Referer": ref or url})
    try:
        with urllib.request.urlopen(r, timeout=20) as resp:
            raw = resp.read()
            if resp.headers.get("Content-Encoding") == "gzip":
                raw = gzip.decompress(raw)
            return resp.status, len(raw), resp.geturl(), raw[:120]
    except Exception as e:
        return None, 0, url, str(e).encode()

cands = [
 "https://www.linovelib.com/search/?searchkey=%E5%8F%B2%E8%8E%B1%E5%A7%86",
 "https://www.linovelib.com/search?searchkey=%E5%8F%B2%E8%8E%B1%E5%A7%86",
 "https://www.linovelib.com/s?q=%E5%8F%B2%E8%8E%B1%E5%A7%86",
 "https://www.linovelib.com/Search/?searchkey=%E5%8F%B2%E8%8E%B1%E5%A7%86",
 "https://www.linovelib.com/top/",
 "https://www.linovelib.com/novel/2601.html",
 "https://www.linovelib.com/novel/2601/catalog",
]
for u in cands:
    st, ln, final, head = get(u)
    print(st, ln, final, "|", head[:80].decode("utf-8","replace").replace("\n"," "))
