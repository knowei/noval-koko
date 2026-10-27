import sys, re, requests
sys.stdout.reconfigure(encoding='utf-8')
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
s=requests.Session(); s.trust_env=False
s.headers.update({"User-Agent":UA,"Accept-Language":"zh-CN,zh;q=0.9","Referer":"https://www.wenku8.net/"})
PAT = r'book/\d+\.htm'
tests=[
 ("GET search.php?searchkey", "https://www.wenku8.net/modules/article/search.php?searchkey=%E5%A6%B9%E5%A6%B9%E4%BA%BA%E7%94%9F"),
 ("GET search.php?keyword", "https://www.wenku8.net/modules/article/search.php?keyword=%E5%A6%B9%E5%A6%B9%E4%BA%BA%E7%94%9F"),
 ("GET waps.php?searchkey", "https://www.wenku8.net/modules/article/waps.php?searchkey=%E5%A6%B9%E5%A6%B9%E4%BA%BA%E7%94%9F"),
 ("GET m.wenku8 book", "https://m.wenku8.net/book/2163.htm"),
]
for name,u in tests:
    try:
        r=s.get(u, timeout=20, allow_redirects=True)
        r.encoding=r.apparent_encoding
        t=re.sub(r'\s+',' ',re.sub(r'<[^>]+>',' ',r.text))
        n=len(re.findall(PAT, r.text))
        print(name, "->", r.status_code, len(r.content), "B final=", r.url[:60], "books=", n)
        print("   ", t[:140])
    except Exception as e:
        print(name, "ERR", type(e).__name__, str(e)[:70])
