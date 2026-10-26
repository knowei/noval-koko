import urllib.request, urllib.parse, gzip, re
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
h = {"User-Agent": UA, "Accept": "text/html,application/xhtml+xml,*/*;q=0.8",
     "Accept-Language": "zh-CN,zh;q=0.9", "Referer": "https://www.linovelib.com/",
     "Origin": "https://www.linovelib.com", "Content-Type": "application/x-www-form-urlencoded"}
body = urllib.parse.urlencode({"key": "史莱姆"}, encoding="utf-8").encode()
r = urllib.request.Request("https://www.linovelib.com/S6/", data=body, headers=h, method="POST")
with urllib.request.urlopen(r, timeout=25) as resp:
    raw = resp.read()
    if resp.headers.get("Content-Encoding") == "gzip": raw = gzip.decompress(raw)
html = raw.decode("utf-8", "replace")
open("tool/ln_probe/lib_search.html","w",encoding="utf-8").write(html)
print("len", len(html))
i = html.find("/novel/")
print("--- context around first /novel/ ---")
print(html[max(0,i-1500):i+800])
