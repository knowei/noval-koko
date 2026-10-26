import re, urllib.request, gzip
cat = open("tool/ln_probe/lib_catalog.html", encoding="utf-8", errors="replace").read()
vols = re.split(r'<div class="volume clearfix"', cat)
for i, v in enumerate(vols[1:], 1):
    print("vol", i, "li:", len(re.findall(r'<li class="col-4"', v)), "| title:", re.findall(r'<h2 class="v-line"><a[^>]*>([^<]*)</a>', v)[:1])
print("tail:", cat[-1200:].replace("\n"," ")[:1200])

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
r = urllib.request.Request("https://www.linovelib.com/novel/2601/100997.html", headers={"User-Agent": UA, "Referer": "https://www.linovelib.com/novel/2601/catalog"})
with urllib.request.urlopen(r, timeout=25) as resp:
    raw = resp.read()
    if resp.headers.get("Content-Encoding") == "gzip": raw = gzip.decompress(raw)
html = raw.decode("utf-8", "replace")
open("tool/ln_probe/lib_chap2.html","w",encoding="utf-8").write(html)
print("==== chapter page len", len(html))
for cid in ['id="acontent"', "read-content", "chapter-content", "article-text", "<p>"]:
    print(cid, html.count(cid))
i = html.find('id="acontent"')
print(html[max(0,i-200):i+500] if i>0 else html[:400])
