# -*- coding: utf-8 -*-
"""kepub.net 探活（直连，绕过系统代理）。"""
import io
import re
import sys

import requests

S = requests.Session()
S.trust_env = False  # 不走系统代理，应用里 Dio 也是直连

BASE = "https://www.kepub.net"
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
}

out = io.StringIO()


def log(*a):
    print(*a, file=out)


def get(url, **kw):
    try:
        r = S.get(url, headers=HEADERS, timeout=25, **kw)
        r.encoding = r.apparent_encoding or "utf-8"
        log(f"GET {url} -> {r.status_code} {len(r.content)}B {r.headers.get('content-type')}")
        return r
    except Exception as e:  # noqa: BLE001
        log(f"GET {url} -> EXC {type(e).__name__}: {str(e)[:160]}")
        return None


r = get(BASE + "/")
if r is not None and r.status_code == 200:
    html = r.text
    io.open("tool/kp_home.html", "w", encoding="utf-8").write(html)
    t = re.search(r"<title>(.*?)</title>", html, re.S)
    log("title:", t.group(1).strip() if t else "?")
    for m in re.finditer(r"<form[^>]*>", html, re.I):
        log("FORM:", m.group(0)[:300])
    for m in re.finditer(r"<input[^>]*>", html, re.I):
        log("INPUT:", m.group(0)[:220])
    uniq = []
    for l in re.findall(r'href="([^"]+)"', html):
        if l not in uniq:
            uniq.append(l)
    log("links:", len(uniq))
    for l in uniq[:50]:
        log("  ", l)

for path in [
    "/search?q=%E5%8F%B2%E8%8E%B1%E5%A7%86",
    "/search?key=%E5%8F%B2%E8%8E%B1%E5%A7%86",
    "/search/?q=%E5%8F%B2%E8%8E%B1%E5%A7%86",
    "/s?q=%E5%8F%B2%E8%8E%B1%E5%A7%86",
    "/index.php?keyword=%E5%8F%B2%E8%8E%B1%E5%A7%86",
    "/e/search/index.php?keyboard=%E5%8F%B2%E8%8E%B1%E5%A7%86&show=title",
]:
    rr = get(BASE + path)
    if rr is not None and rr.status_code == 200:
        log("  len", len(rr.text), "hits 史莱姆:", rr.text.count("史莱姆"))
        io.open("tool/kp_search.html", "w", encoding="utf-8").write(rr.text)

io.open("tool/kp_probe.txt", "w", encoding="utf-8").write(out.getvalue())
sys.exit(0)
