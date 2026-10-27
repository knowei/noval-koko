import sys, re, requests
sys.stdout.reconfigure(encoding='utf-8')
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
s=requests.Session(); s.trust_env=False
s.headers.update({"User-Agent":UA,"Accept-Language":"zh-CN,zh;q=0.9"})
def g(u, ref=None):
    h={"Referer":ref} if ref else {}
    r=s.get(u, headers=h, timeout=25); r.encoding=r.apparent_encoding; return r
for u in ["https://www.wenku8.net/modules/article/toplist.php?sort=allvisit",
          "https://www.wenku8.net/modules/article/toplist.php?sort=allvote",
          "https://www.wenku8.net/index.php"]:
    try:
        r=g(u, ref="https://www.wenku8.net/")
        t=re.sub(r'\s+',' ',re.sub(r'<[^>]+>',' ',r.text))
        print("==", u, r.status_code, len(r.content))
        print("   text:", t[:260])
        print("   book links:", len(re.findall(r'book/\d+\.htm', r.text)))
    except Exception as e:
        print("==", u, "ERR", type(e).__name__, str(e)[:60])
