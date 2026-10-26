import urllib.request, gzip, re
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
r = urllib.request.Request("https://www.linovelib.com/novel/2013.html", headers={"User-Agent": UA})
with urllib.request.urlopen(r, timeout=25) as resp:
    raw = resp.read()
    if resp.headers.get("Content-Encoding") == "gzip": raw = gzip.decompress(raw)
html = raw.decode("utf-8", "replace")
print("len", len(html))
for m in re.finditer(r'<a[^>]*class="[^"]*read-btn[^"]*"[^>]*>', html):
    print("READBTN:", m.group(0))
print("catalog links:", re.findall(r'href="(/novel/2013/[^"]*)"', html)[:5])
