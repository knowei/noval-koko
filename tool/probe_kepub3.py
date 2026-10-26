# -*- coding: utf-8 -*-
"""分析 kepub 搜索页 / 书籍页 / 章节页结构，为书源规则找选择器。"""
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


def get(url):
    r = S.get(url, headers=H, timeout=25)
    r.encoding = r.apparent_encoding or "utf-8"
    return r


def show_sel(soup, sels, label):
    log(f"-- {label} --")
    for s in sels:
        els = soup.select(s)
        txt = ""
        if els:
            txt = re.sub(r"\s+", " ", els[0].get_text(" ", strip=True))[:70]
        log(f"  {s!r:44} n={len(els):3} first={txt}")


kw = "史莱姆"
r = get(f"{BASE}/search.html?keyword={kw}")
io.open("tool/kp_search2.html", "w", encoding="utf-8").write(r.text)
soup = BeautifulSoup(r.text, "html.parser")
log("== search page", len(r.text), "chars")
show_sel(soup, [
    ".book-list", ".book-list li", "ul.book-list li", ".search-list li",
    ".book-item", ".book-name", ".book-cover", ".book-info",
    "a[href^='/book/']", "img", ".no-data", ".empty",
], "search")
# 列出前几个 /book/ 链接及其上下文
cnt = 0
for a in soup.select("a[href^='/book/']"):
    cnt += 1
    if cnt > 8:
        break
    log("  LINK", a.get("href"), "|", a.get_text(" ", strip=True)[:40])
    par = a.find_parent(["li", "div"])
    if par is not None:
        log("    parent:", par.get("class"), re.sub(r"\s+", " ", par.get_text(" ", strip=True))[:120])

# 书籍页
r2 = get(f"{BASE}/book/10044")
io.open("tool/kp_book2.html", "w", encoding="utf-8").write(r2.text)
s2 = BeautifulSoup(r2.text, "html.parser")
log("== book page", len(r2.text), "chars")
show_sel(s2, [
    "h1", ".book-name", ".book-info", ".author", ".intro", ".desc",
    ".cover img", ".book-catalog a", ".chapter-list a", "a[href^='/article/']",
    ".catalog a", ".book-tags a", ".status", ".word-count",
], "book")
links = [a.get("href") for a in s2.select("a[href^='/article/']")][:6]
log("  article links:", links)

# 章节页
r3 = get(f"{BASE}/article/29921357")
io.open("tool/kp_article2.html", "w", encoding="utf-8").write(r3.text)
s3 = BeautifulSoup(r3.text, "html.parser")
log("== article page", len(r3.text), "chars")
show_sel(s3, [
    "h1", ".article-title", ".chapter-title", "#content", ".content",
    ".article-content", "#article-content", "p", ".next a", "a.next",
    ".chapter-nav a", "a[href^='/article/']",
], "article")
for sel in ["#content", ".content", ".article-content", "#article-content"]:
    els = s3.select(sel)
    if els:
        log(f"  text of {sel}: {len(els[0].get_text())} chars")

io.open("tool/kp_probe3.txt", "w", encoding="utf-8").write(out.getvalue())
sys.exit(0)
