import urllib.request, urllib.parse, gzip
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
def post(u, data):
    h = {"User-Agent": UA, "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
         "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8", "Referer": "https://www.linovelib.com/",
         "Origin": "https://www.linovelib.com",
         "Content-Type": "application/x-www-form-urlencoded",
         "Upgrade-Insecure-Requests": "1"}
    body = urllib.parse.urlencode(data, encoding="utf-8").encode()
    r = urllib.request.Request(u, data=body, headers=h, method="POST")
    try:
        with urllib.request.urlopen(r, timeout=25) as resp:
            raw = resp.read()
            if resp.headers.get("Content-Encoding") == "gzip": raw = gzip.decompress(raw)
            return resp.status, len(raw), raw[:300].decode("utf-8","replace").replace("\n"," ")
    except Exception as e:
        return None, 0, str(e)[:80]

for data in [
  {"searchkey": "史莱姆"},
  {"searchkey": "史莱姆", "searchtype": "all"},
  {"searchkey": "史莱姆", "type": "articlename"},
  {"searchkey": "史莱姆", "searchtype": "articlename"},
  {"key": "史莱姆"},
]:
    print(list(data.keys()), post("https://www.linovelib.com/S6/", data))
