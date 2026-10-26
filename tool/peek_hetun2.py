import urllib.request, gzip, re
UA = "Mozilla/5.0 (Linux; Android 8.0.0; Pixel 2 Build/OPD3.170816.012) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.71 Mobile Safari/537.36"
for url, name in [("http://m.hetunxs.com/167/167272/", "hetun_toc")]:
    r = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "text/html,*/*", "Accept-Language":"zh-CN,zh;q=0.9"})
    with urllib.request.urlopen(r, timeout=20) as resp:
        raw = resp.read()
        if resp.headers.get("Content-Encoding") == "gzip":
            raw = gzip.decompress(raw)
    html = raw.decode("utf-8", "replace")
    open("tool/ln_probe/%s.html" % name, "w", encoding="utf-8").write(html)
    print(name, "len", len(html))
    i = html.find("下一页")
    if i >= 0:
        print("NEXT CTX:", html[max(0,i-400):i+120].replace("\n"," "))
    else:
        print("no 下一页; tail:", html[-800:].replace("\n"," "))
    print("li count:", len(re.findall(r"<li", html)))
