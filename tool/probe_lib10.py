import re, urllib.request, gzip
cat = open("tool/ln_probe/lib_catalog.html", encoding="utf-8", errors="replace").read()
print("li.col-4 count:", len(re.findall(r'<li class="col-4"', cat)))
print("volume blocks:", len(re.findall(r'<div class="volume clearfix"', cat)))
print("ul.chapter-list:", cat.count('class="chapter-list clearfix"'))
print("pager:", re.findall(r'(下一页|下一頁|page|_2\.html)', cat)[:5])

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
r = urllib.request.Request("https://www.linovelib.com/novel/2601/40988.html", headers={"User-Agent": UA, "Referer": "https://www.linovelib.com/novel/2601/catalog"})
with urllib.request.urlopen(r, timeout=25) as resp:
    raw = resp.read()
    if resp.headers.get("Content-Encoding") == "gzip": raw = gzip.decompress(raw)
html = raw.decode("utf-8", "replace")
open("tool/ln_probe/lib_chap.html","w",encoding="utf-8").write(html)
print("chapter len", len(html))
for cid in ["acontent", "TextContent", "article-text", "read-content", "chapter-content"]:
    print(cid, html.count(cid))
i = html.find('id="acontent"')
if i < 0: i = html.find('class="read-content')
print(html[max(0,i-300):i+600])
