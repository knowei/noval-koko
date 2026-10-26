import urllib.request, gzip, re
UA = "Mozilla/5.0 (Linux; Android 8.0.0; Pixel 2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.71 Mobile Safari/537.36"
r = urllib.request.Request("http://m.hetunxs.com/167/167272/", headers={"User-Agent": UA})
with urllib.request.urlopen(r, timeout=20) as resp:
    raw = resp.read()
    if resp.headers.get("Content-Encoding") == "gzip":
        raw = gzip.decompress(raw)
html = raw.decode("utf-8", "replace")
open("tool/ln_probe/hetun_toc.html","w",encoding="utf-8").write(html)
print("len", len(html))
for m in re.finditer(r"<a[^>]*>[^<]{0,12}(下一页|下页|下一页|尾页)[^<]{0,12}</a>", html):
    print("NEXT:", m.group(0))
print("--- pager block ---")
i = html.find("下一页")
print(html[max(0,i-600):i+200] if i>=0 else "no 下一页")
print("--- chapter anchors count:", len(re.findall(r'<a[^>]+href="[^"]*167272[^"]*"', html)))
