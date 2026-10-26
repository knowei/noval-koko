# -*- coding: utf-8 -*-
"""生成「包子漫画」书源 JSON（Legado 格式）。

站点：baozimh.org（Astro 前端）+ v2.apikk.top 只读接口
  * 搜索 ：GET /s?q={key}      结果卡片 div.cardlist > div（h3 标题、a[href] 书籍、img 封面）
  * 详情 ：/manga/{slug}       简介/封面/标题走 /api/manga/get?mid={mid}&mode=all
  * 目录 ：/chapterlist/{slug} 页面含 id=allchapters data-mid="{mid}" → 接口 chapters[].attributes.slug
  * 正文 ：/manga/{slug}/{chapterSlug} 页面含 #chapterContent data-ms data-cs
           → /api/v2/chapter/getinfo?m={ms}&c={cs} 返回 data.info.images[]
"""
import io
import json
import os

UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)

# 取 mid + 详情接口的公共片段（bookInfo / toc 复用）
GET_MANGA = "\n".join([
    "var slug = baseUrl.split('/').pop();",
    "var page = java.ajax('https://baozimh.org/chapterlist/' + slug);",
    "var mm = /data-mid=\"(\\d+)\"/.exec(page);",
    "if (!mm) { return ''; }",
    "var raw = java.ajax('https://v2.apikk.top/api/manga/get?mid=' + mm[1] + '&mode=all');",
    "var o = JSON.parse(raw);",
    "var d = (o && o.data) || {};",
])

BOOK_NAME_JS = "@js:(function () {\n" + GET_MANGA + "\nreturn d.title || '';\n})()"
BOOK_INTRO_JS = "@js:(function () {\n" + GET_MANGA + "\nreturn d.desc || '';\n})()"
BOOK_COVER_JS = "@js:(function () {\n" + GET_MANGA + "\nreturn d.cover || '';\n})()"

TOC_JS = "\n".join([
    "(function () {",
    GET_MANGA,
    "var list = d.chapters || [];",
    "var out = [];",
    "for (var i = 0; i < list.length; i++) {",
    "  var a = list[i].attributes || {};",
    "  if (!a.slug) { continue; }",
    "  out.push('<a href=\"/manga/' + slug + '/' + a.slug + '\">' + (a.title || ('c' + i)) + '</a>');",
    "}",
    "return out;",
    "})()",
])

CONTENT_JS = "\n".join([
    "(function () {",
    # 章节页里 #chapterContent 带着 data-ms / data-cs，接口靠这两个值取图
    "var tag = /<[^>]*id=\"chapterContent\"[^>]*>/.exec(result);",
    "var ms = tag ? /data-ms=\"(\\d+)\"/.exec(tag[0]) : null;",
    "var cs = tag ? /data-cs=\"(\\d+)\"/.exec(tag[0]) : null;",
    "if (!ms || !cs) { return ''; }",
    "var raw = java.ajax('https://v2.apikk.top/api/v2/chapter/getinfo?m=' + ms[1] + '&c=' + cs[1]);",
    "var o = JSON.parse(raw);",
    "var info = (o && o.data && o.data.info) || {};",
    "var box = info.images || {};",
    "var payload = box.images;",
    "var line = box.line;",
    "if (!payload) { return ''; }",
    # 站点把图片地址整包加密，官方解密器挂在 /assets/runtime/chapter-decoder.js，会注册 window.__cimg
    "if (!window.__cimg) {",
    "  var dec = java.ajax('https://baozimh.org/assets/runtime/chapter-decoder.js');",
    "  new Function(dec)();",
    "}",
    "return window.__cimg.r(payload).then(function (list) {",
    "  var host = (line === 2) ? 'https://c-nd2-1.6wm.top' : 'https://c-nd3-1.6wm.top';",
    "  var out = [];",
    "  for (var i = 0; i < list.length; i++) { out.push(host + list[i].url); }",
    "  return out;",
    "});",
    "})()",
])

source = {
    "bookSourceName": "包子漫画",
    "bookSourceGroup": "🧩漫画",
    "bookSourceType": 2,
    "bookSourceUrl": "https://baozimh.org",
    "bookSourceComment": "包子漫画 baozimh.org：详情/目录/图片均走 v2.apikk.top 接口（mid 取自 /chapterlist 页面的 data-mid）",
    "enabled": True,
    "enabledExplore": False,
    "enabledCookieJar": True,
    "customOrder": 0,
    "weight": 0,
    "lastUpdateTime": 0,
    "respondTime": 180000,
    "header": json.dumps({"User-Agent": UA, "Referer": "https://baozimh.org/"}),
    "loginUrl": "",
    "loginCheckJs": "",
    "bookUrlPattern": "",
    "searchUrl": "https://baozimh.org/s?q={{key}}",
    "ruleSearch": {
        "bookList": "@css:div.cardlist > div",
        "name": "@css:h3@text",
        "author": "",
        "intro": "",
        "kind": "",
        "lastChapter": "",
        "bookUrl": "@css:a@href",
        "coverUrl": "@css:img@src",
    },
    "ruleBookInfo": {
        "name": BOOK_NAME_JS,
        "author": "",
        "intro": BOOK_INTRO_JS,
        "kind": "",
        "lastChapter": "",
        "coverUrl": BOOK_COVER_JS,
        "tocUrl": "@js:'https://baozimh.org/chapterlist/' + baseUrl.split('/').pop()",
        "wordCount": "",
    },
    "ruleToc": {
        "chapterList": "@js:" + TOC_JS,
        "chapterName": "@css:a@text",
        "chapterUrl": "@css:a@href",
    },
    "ruleContent": {
        "content": "@js:" + CONTENT_JS,
        "nextContentUrl": "",
        "imageStyle": "",
    },
    "ruleExplore": {},
}

os.makedirs("sample_sources", exist_ok=True)
with io.open("sample_sources/baozimh.json", "w", encoding="utf-8") as f:
    json.dump(source, f, ensure_ascii=False, indent=2)
print("written sample_sources/baozimh.json")
