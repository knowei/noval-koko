# -*- coding: utf-8 -*-
"""探针：SF轻小说 搜索→详情→目录→正文，检查 .catalog-list / #ChapterBody 是否在服务端 HTML 里。"""
import io
import re
import sys

import requests

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
H = {"User-Agent": UA, "Referer": "https://book.sfacg.com/"}

s = requests.Session()
s.headers.update(H)

kw = "\u5173\u4e8e\u6211\u8f6c\u751f\u6210\u4e3a\u53f2\u83b1\u59c6"
r = s.get("http://s.sfacg.com/", params={"Key": kw, "S": "1", "SS": "0"}, timeout=25)
print("search", r.status_code, len(r.content))
html = r.content.decode("utf-8", "replace")
io.open("tool/sf_search.html", "w", encoding="utf-8").write(html)

books = re.findall(r'href="(https?://book\.sfacg\.com/[^"]*?/)"', html)
print("book links:", books[:5])
if not books:
    sys.exit("no book link")

book = books[0]
print("book:", book)
r2 = s.get(book, timeout=25)
print("book page", r2.status_code, len(r2.content))
h2 = r2.content.decode("utf-8", "replace")
io.open("tool/sf_book.html", "w", encoding="utf-8").write(h2)
print("has catalog-list:", h2.count("catalog-list"))
print("MainIndex link:", "MainIndex" in h2)

toc = book.rstrip("/") + "/MainIndex/"
r3 = s.get(toc, timeout=25)
print("toc", r3.status_code, len(r3.content))
h3 = r3.content.decode("utf-8", "replace")
io.open("tool/sf_toc.html", "w", encoding="utf-8").write(h3)
print("catalog-list count:", h3.count("catalog-list"))
print("li count in catalog:", len(re.findall(r"catalog-list[\s\S]{0,4000}", h3)))
links = re.findall(r'<a[^>]+href="([^"]*?/C/\d+[^"]*)"', h3)
print("C links:", len(links), links[:3])
if not links:
    links = re.findall(r'href="([^"]+)">\s*[\u7b2c\u4e00-\u9fff]', h3)
    print("fallback links:", len(links), links[:5])

if links:
    cu = links[0]
    if cu.startswith("/"):
        cu = "https://book.sfacg.com" + cu
    print("chapter:", cu)
    r4 = s.get(cu, timeout=25)
    print("chapter", r4.status_code, len(r4.content))
    h4 = r4.content.decode("utf-8", "replace")
    io.open("tool/sf_chap.html", "w", encoding="utf-8").write(h4)
    print("ChapterBody count:", h4.count("ChapterBody"))
    m = re.search(r'id="ChapterBody"[\s\S]{0,400}', h4)
    print("body snippet:", (m.group(0)[:300] if m else "NONE"))
