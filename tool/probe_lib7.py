import urllib.request, urllib.parse, gzip
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
def call(u, data=None, extra=None):
    h = {"User-Agent": UA, "Accept": "text/html,application/xhtml+xml,*/*;q=0.8",
         "Accept-Language": "zh-CN,zh;q=0.9", "Referer": "https://www.linovelib.com/",
         "Origin": "https://www.linovelib.com"}
    if extra: h.update(extra)
    body = urllib.parse.urlencode(data).encode() if data else None
    if body: h["Content-Type"] = "application/x-www-form-urlencoded"
    r = urllib.request.Request(u, data=body, headers=h)
    try:
        with urllib.request.urlopen(r, timeout=25) as resp:
            raw = resp.read()
            if resp.headers.get("Content-Encoding") == "gzip": raw = gzip.decompress(raw)
            return resp.status, len(raw), resp.geturl(), raw[:200].decode("utf-8","replace")
    except Exception as e:
        return None, 0, u, str(e)[:80]

k = urllib.parse.quote("史莱姆")
tests = [
 ("POST /S6/ xhr", "https://www.linovelib.com/S6/", {"searchkey": "史莱姆"}, {"X-Requested-With": "XMLHttpRequest", "Accept": "*/*"}),
 ("GET /S6/?searchkey", "https://www.linovelib.com/S6/?searchkey=%s" % k, None, None),
 ("POST /sou/", "https://www.linovelib.com/sou/", {"searchkey": "史莱姆"}, None),
 ("GET /sou/?searchkey", "https://www.linovelib.com/sou/?searchkey=%s" % k, None, None),
 ("POST /search/", "https://www.linovelib.com/search/", {"searchkey": "史莱姆"}, None),
 ("GET /topfull/allvisit/1.html", "https://www.linovelib.com/topfull/allvisit/1.html", None, None),
]
for name, u, data, extra in tests:
    print(name, call(u, data, extra))
