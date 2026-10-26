# -*- coding: utf-8 -*-
"""看 kepub 的搜索脚本与书库/书籍/目录页结构。"""
import io
import re
import sys

import requests

S = requests.Session()
S.trust_env = False
BASE = "https://www.kepub.net"
H = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "zh-CN,zh;q=0.9",
}
out = io.StringIO()


def log(*a):
    print(*a, file=out)


def get(url, name=None):
    try:
        r = S.get(url, headers=H, timeout=25)
        r.encoding = r.apparent_encoding or "utf-8"
        log(f"GET {url} -> {r.status_code} {len(r.content)}B")
        if name:
            io.open(f"tool/kp_{name}", "w", encoding="utf-8").write(r.text)
        return r
    except Exception as e:  # noqa: BLE001
        log(f"GET {url} -> EXC {type(e).__name__}: {str(e)[:140]}")
        return None


js = get(BASE + "/js/common/header_search.js", "hsearch.js")
if js is not None and js.status_code == 200:
    log("---- header_search.js ----")
    log(js.text[:3000])

for p, n in [("/library", "library.html"), ("/book/10044", "book.html"), ("/article/29921357", "article.html")]:
    get(BASE + p, n)

# 猜测搜索接口
for p in [
    "/search/index?keyword=%E5%8F%B2%E8%8E%B1%E5%A7%86",
    "/search/index?q=%E5%8F%B2%E8%8E%B1%E5%A7%86",
    "/library/search?keyword=%E5%8F%B2%E8%8E%B1%E5%A7%86",
    "/api/search?keyword=%E5%8F%B2%E8%8E%B1%E5%A7%86",
    "/search.html?keyword=%E5%8F%B2%E8%8E%B1%E5%A7%86",
    "/books?keyword=%E5%8F%B2%E8%8E%B1%E5%A7%86",
]:
    r = get(BASE + p)
    if r is not None and r.status_code == 200:
        log("   len", len(r.text), "hits:", r.text.count("史莱姆"))

io.open("tool/kp_probe2.txt", "w", encoding="utf-8").write(out.getvalue())
sys.exit(0)
