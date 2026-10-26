# -*- coding: utf-8 -*-
"""kepub: 目录/章节/搜索细节。"""
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


def get(url, name=None):
    r = S.get(url, headers=H, timeout=25)
    r.encoding = r.apparent_encoding or "utf-8"
    if name:
        io.open(f"tool/kp_{name}", "w", encoding="utf-8").write(r.text)
    return r


# --- 书籍页目录链接 ---
r = get(f"{BASE}/book/10044")
s = BeautifulSoup(r.text, "html.parser")
log("== 目录前 8 条的 href 与文本")
for a in s.select(".chapter-list a")[:8]:
    log("  ", a.get("href"), "|", a.get_text(" ", strip=True)[:30])
log("== 目录容器候选")
for sel in [".chapter-list", ".book-chapter", ".catalog", ".chapter", ".directory"]:
    els = s.select(sel)
    log(f"  {sel!r} n={len(els)}")
log("== 元信息")
for sel in [".book-info", ".book-status", ".tag", ".book-meta"]:
    els = s.select(sel)
    if els:
        log(f"  {sel}: {re.sub(chr(10)+'+', ' | ', els[0].get_text(chr(10), strip=True))[:300]}")
cov = s.select_one("img")
log("  first img:", cov.attrs if cov else None)
log("  og:image:", [m.get("content") for m in s.select('meta[property="og:image"]')])
log("  og:novel:", [(m.get("property"), m.get("content")) for m in s.select("meta[property^='og:novel']")])

# --- 搜索多个关键词 ---
for kw in ["山雨", "骆驼祥子", "斗罗大陆", "鲁迅", "三体"]:
    rr = get(f"{BASE}/search.html?keyword={kw}")
    ss = BeautifulSoup(rr.text, "html.parser")
    n = len(ss.select("a[href^='/book/']"))
    log(f"  search {kw}: {rr.status_code} {len(rr.text)}B booklinks={n} empty={bool(ss.select('.empty'))}")
    if n:
        for a in ss.select("a[href^='/book/']")[:3]:
            log("     ", a.get("href"), "|", a.get_text(" ", strip=True)[:30])
        io.open("tool/kp_search_ok.html", "w", encoding="utf-8").write(rr.text)

# --- 章节页细节 ---
r3 = get(f"{BASE}/article/29921357", "article3.html")
s3 = BeautifulSoup(r3.text, "html.parser")
log("== 章节页")
log("  title tag:", (s3.title.get_text().strip() if s3.title else "?")[:60])
log("  h2/h3:", [h.get_text(" ", strip=True)[:30] for h in s3.select("h2,h3")][:5])
log("  .chapter-name:", [d.get_text(" ", strip=True)[:30] for d in s3.select(".chapter-name,.title,.article-name")][:5])
c = s3.select_one("#content")
if c is not None:
    log("  #content class:", c.get("class"))
    log("  #content head html:", str(c)[:400].replace("\n", " "))
    log("  has <p>:", len(c.select("p")))
log("  nav links:", [(a.get("href"), a.get_text(" ", strip=True)) for a in s3.select("a") if a.get_text(strip=True) in ("上一章", "下一章", "目录")][:6])

io.open("tool/kp_probe4.txt", "w", encoding="utf-8").write(out.getvalue())
sys.exit(0)
