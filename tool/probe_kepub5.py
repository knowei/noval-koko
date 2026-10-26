# -*- coding: utf-8 -*-
"""kepub: 书籍章节页 + 搜索页真实交互。"""
import io
import re
import sys

import requests
from bs4 import BeautifulSoup

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


def get(url, name=None, **kw):
    r = S.get(url, headers=H, timeout=25, **kw)
    r.encoding = r.apparent_encoding or "utf-8"
    if name:
        io.open(f"tool/kp_{name}", "w", encoding="utf-8").write(r.text)
    return r


# 1) 书籍章节页
r = get(f"{BASE}/book/10044/10001", "chap.html")
s = BeautifulSoup(r.text, "html.parser")
log("== 章节页 /book/10044/10001", len(r.text), "chars")
log("  <title>:", (s.title.get_text().strip() if s.title else "?")[:80])
for sel in ["#content", "h1", ".chapter-title", ".article-title", ".book-name"]:
    els = s.select(sel)
    log(f"  {sel!r} n={len(els)}", (els[0].get_text(' ', strip=True)[:40] if els else ''))
log("  导航链接：")
for a in s.select("a"):
    t = a.get_text(" ", strip=True)
    if t in ("上一章", "下一章", "目录", "返回目录", "章节目录"):
        log("    ", t, "->", a.get("href"))
log("  所有 /book/10044/ 链接：", [a.get("href") for a in s.select("a[href*='/book/10044/']")][:8])

# 2) 搜索页的脚本与表单
r2 = get(f"{BASE}/search.html?keyword=%E5%B1%B1%E9%9B%A8", "search3.html")
s2 = BeautifulSoup(r2.text, "html.parser")
log("== 搜索页")
for sc in s2.select("script[src]"):
    log("  script:", sc.get("src"))
for f in s2.select("form"):
    log("  form:", str(f)[:200].replace("\n", " "))
log("  body 片段:", re.sub(r"\s+", " ", s2.select_one(".main, .container, body").get_text(" ", strip=True))[:400] if s2.select_one("body") else "")

# 3) 试探其它搜索路径
for p in [
    "/search.html?keyword=%E5%B1%B1%E9%9B%A8&page=1",
    "/search/%E5%B1%B1%E9%9B%A8",
    "/library?keyword=%E5%B1%B1%E9%9B%A8",
    "/library?search=%E5%B1%B1%E9%9B%A8",
    "/original?keyword=%E5%B1%B1%E9%9B%A8",
    "/search.html?q=%E5%B1%B1%E9%9B%A8",
    "/search.html?word=%E5%B1%B1%E9%9B%A8",
    "/search.html?keywords=%E5%B1%B1%E9%9B%A8",
]:
    rr = get(BASE + p)
    ss = BeautifulSoup(rr.text, "html.parser")
    nbooks = len(ss.select("a[href^='/book/']"))
    log(f"  {p} -> {rr.status_code} {len(rr.text)}B books={nbooks}")

io.open("tool/kp_probe5.txt", "w", encoding="utf-8").write(out.getvalue())
sys.exit(0)
