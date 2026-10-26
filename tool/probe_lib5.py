import urllib.request, gzip
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
def get(u):
    r = urllib.request.Request(u, headers={"User-Agent": UA, "Accept-Language":"zh-CN,zh;q=0.9"})
    try:
        with urllib.request.urlopen(r, timeout=20) as resp:
            raw = resp.read()
            if resp.headers.get("Content-Encoding") == "gzip":
                raw = gzip.decompress(raw)
            return resp.status, len(raw), resp.geturl()
    except Exception as e:
        return None, 0, str(e)[:60]
urls = [
 "https://www.linovelib.com/search.php?searchkey=%E5%8F%B2%E8%8E%B1%E5%A7%86",
 "https://www.linovelib.com/modules/article/search.php?searchkey=%E5%8F%B2%E8%8E%B1%E5%A7%86",
 "https://www.linovelib.com/page.php?bid=1",
 "https://www.linovelib.com/top.html",
 "https://www.linovelib.com/wenku/weblightnovel/1.html",
 "https://www.linovelib.com/topfull/allvisit/1.html",
 "https://www.linovelib.com/wenku/",
]
for u in urls:
    print(get(u), u)
