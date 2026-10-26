# -*- coding: utf-8 -*-
"""探针：SF轻小说 详情/目录/正文结构。只打印 ASCII 统计，中文细节写入 tool/sf_report.txt。"""
import io
import re

import requests

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
H = {"User-Agent": UA, "Referer": "http://book.sfacg.com/"}

s = requests.Session()
s.headers.update(H)
log = []


def say(x):
    log.append(str(x))
    print(str(x).encode("ascii", "replace").decode("ascii"))


book = "http://book.sfacg.com/Novel/261860"
r = s.get(book + "/", timeout=25)
say("book %s bytes=%d" % (r.status_code, len(r.content)))
h = r.content.decode("utf-8", "replace")
io.open("tool/sf_book.html", "w", encoding="utf-8").write(h)
say("has MainIndex: %s" % ("MainIndex" in h))
say("has catalog-list: %d" % h.count("catalog-list"))
say("ChapterBody: %d" % h.count("ChapterBody"))
m = re.search(r'<meta name="keywords" content="([^"]*)"', h)
say("keywords meta: %s" % (m.group(1) if m else "NONE").encode("ascii", "replace").decode("ascii"))

toc = book.rstrip("/") + "/MainIndex/"
r3 = s.get(toc, timeout=25)
say("toc %s bytes=%d" % (r3.status_code, len(r3.content)))
h3 = r3.content.decode("utf-8", "replace")
io.open("tool/sf_toc.html", "w", encoding="utf-8").write(h3)
say("toc catalog-list: %d" % h3.count("catalog-list"))
say("toc li: %d" % h3.count("<li"))
links = re.findall(r'href="(/[^"]*?/C/\d+[^"]*)"', h3) + re.findall(r'href="(https?://[^"]*?/C/\d+)"', h3)
say("C links: %d" % len(links))
for u in links[:6]:
    say("  link %s" % u)
say("toc count /C/ raw: %d" % h3.count("/C/"))
say("toc js-api hints: %s" % [k for k in ["ChapterList", "LoadChapter", "ajax", "getChapter", "api"] if k in h3])

# 目录页里是否有分页/翻页
say("toc page hints: %s" % [k for k in ["\u4e0b\u4e00\u9875", "page=", "PageIndex", "pageNum"] if k in h3])

if links:
    cu = links[0]
    if cu.startswith("/"):
        cu = "http://book.sfacg.com" + cu
    r4 = s.get(cu, timeout=25)
    say("chap %s bytes=%d" % (r4.status_code, len(r4.content)))
    h4 = r4.content.decode("utf-8", "replace")
    io.open("tool/sf_chap.html", "w", encoding="utf-8").write(h4)
    say("chap ChapterBody: %d" % h4.count("ChapterBody"))
    m2 = re.search(r'id="ChapterBody"[^>]*>([\s\S]{0,200})', h4)
    if m2:
        say("chap body snippet len=%d" % len(m2.group(1)))
        log.append("SNIPPET>>>" + m2.group(1))
    else:
        say("chap body: NONE")

io.open("tool/sf_report.txt", "w", encoding="utf-8").write("\n".join(log))
say("report written")
