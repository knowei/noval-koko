import urllib.request, gzip, io, sys
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
def get(url, ref=None):
    req = urllib.request.Request(url, headers={
        "User-Agent": UA,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        "Referer": ref or url,
    })
    try:
        with urllib.request.urlopen(req, timeout=25) as r:
            raw = r.read()
            if r.headers.get("Content-Encoding") == "gzip":
                raw = gzip.decompress(raw)
            return r.status, raw
    except Exception as e:
        return None, str(e).encode()

for u in ["https://www.linovelib.com/", "https://www.linovelib.com/search/?searchkey=%E5%8F%B2%E8%8E%B1%E5%A7%86"]:
    st, body = get(u)
    print(u, "->", st, len(body) if isinstance(body, bytes) else body)
    if st == 200:
        open("tool/ln_probe/lib_" + ("home" if u.endswith("/") else "search") + ".html", "wb").write(body)
