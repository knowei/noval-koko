import urllib.request, urllib.parse, gzip, re
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
def req(url, data=None, ref=None):
    h = {"User-Agent": UA, "Accept": "text/html,application/xhtml+xml,*/*;q=0.8",
         "Accept-Language": "zh-CN,zh;q=0.9", "Referer": ref or url}
    if data is not None:
        h["Content-Type"] = "application/x-www-form-urlencoded"
        data = urllib.parse.urlencode(data).encode()
    r = urllib.request.Request(url, data=data, headers=h)
    try:
        with urllib.request.urlopen(r, timeout=25) as resp:
            raw = resp.read()
            if resp.headers.get("Content-Encoding") == "gzip":
                raw = gzip.decompress(raw)
            return resp.status, raw, resp.geturl(), dict(resp.headers)
    except Exception as e:
        return None, str(e).encode(), url, {}

st, body, url, hdrs = req("https://www.linovelib.com/S6/", data={"searchkey": "史莱姆"}, ref="https://www.linovelib.com/")
print("status", st, "len", len(body), "final", url)
print("ct:", hdrs.get("Content-Type"))
open("tool/ln_probe/lib_search.html", "wb").write(body)
head = body[:600].decode("utf-8", "replace")
print(head)
