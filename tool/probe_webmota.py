# -*- coding: utf-8 -*-
"""探 webmota（包子漫画的另一个前端），看章节页图片是否明文。"""
import io
import json
import re
import urllib.parse

import urllib.request

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
OUT = io.StringIO()


def fetch(url, headers=None):
    h = {"User-Agent": UA, "Referer": "https://cn.webmota.com/"}
    if headers:
        h.update(headers)
    req = urllib.request.Request(url, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=25) as r:
            return r.status, r.read().decode("utf-8", "replace")
    except Exception as e:  # noqa: BLE001
        return -1, "ERR %s" % e


for url in [
    "https://cn.webmota.com/comic/douluodalu-fengxuandongman",
    "https://cn.webmota.com/manga/douluodalu-fengxuandongman",
    "https://cn.webmota.com/comic/133",
]:
    st, body = fetch(url)
    OUT.write("== %s -> %s len=%d\n" % (url, st, len(body)))
    if st == 200:
        chs = re.findall(r'href="([^"]*(?:chapter|/c/)[^"]*)"', body)[:8]
        OUT.write("   chapters: %s\n" % chs)
        for kw in ["__NUXT__", "images", "api/v2"]:
            i = body.find(kw)
            if i >= 0:
                OUT.write("   [%s] %s\n" % (kw, body[max(0, i - 100):i + 200].replace("\n", " ")))

io.open("tool/bz_webmota_probe.txt", "w", encoding="utf-8").write(OUT.getvalue())
print("done")
