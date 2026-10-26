# -*- coding: utf-8 -*-
import io
import re
import urllib.request

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
OUT = io.StringIO()


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Referer": "https://cn.webmota.com/"})
    try:
        with urllib.request.urlopen(req, timeout=25) as r:
            return r.status, r.read().decode("utf-8", "replace")
    except Exception as e:  # noqa: BLE001
        return -1, "ERR %s" % e


st, body = fetch("https://cn.webmota.com/comic/douluodalu-fengxuandongman")
OUT.write("manga page %s len=%d\n" % (st, len(body)))
hrefs = sorted(set(re.findall(r'href="(/comic/douluodalu-fengxuandongman[^"]*)"', body)))
OUT.write("slug hrefs: %d\n" % len(hrefs))
for h in hrefs[:6]:
    OUT.write("  %s\n" % h)
OUT.write("tail hrefs:\n")
for h in hrefs[-4:]:
    OUT.write("  %s\n" % h)

if hrefs:
    chap = "https://cn.webmota.com" + hrefs[-1]
    st2, body2 = fetch(chap)
    OUT.write("\nchapter page %s -> %s len=%d\n" % (chap, st2, len(body2)))
    imgs = re.findall(r'<img[^>]+(?:data-src|src)="([^"]+)"', body2)
    OUT.write("imgs: %d\n" % len(imgs))
    for u in imgs[:6]:
        OUT.write("  %s\n" % u)
    for kw in ["images", "chapterImages", "api/v2"]:
        i = body2.find(kw)
        if i >= 0:
            OUT.write("[%s] %s\n" % (kw, body2[max(0, i - 150):i + 300].replace("\n", " ")))

io.open("tool/bz_webmota_probe2.txt", "w", encoding="utf-8").write(OUT.getvalue())
print("done")
