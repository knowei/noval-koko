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
io.open("tool/wm_manga.html", "w", encoding="utf-8").write(body)
OUT.write("manga %s len=%d\n" % (st, len(body)))

allhref = re.findall(r'href="([^"]+)"', body)
OUT.write("total hrefs %d\n" % len(allhref))
uniq = []
for h in allhref:
    if h not in uniq:
        uniq.append(h)
for h in uniq[:40]:
    OUT.write("  %s\n" % h)
OUT.write("--- 'chapter' substrings ---\n")
for m in list(re.finditer(r"chapter", body))[:6]:
    OUT.write("  %s\n" % body[max(0, m.start() - 120):m.start() + 160].replace("\n", " "))

io.open("tool/wm_probe.txt", "w", encoding="utf-8").write(OUT.getvalue())
print("done")
