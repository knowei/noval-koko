# 修 docs/live_sources.json 里的搜索规则（封面 / 选择器 / 字段）。
# 用法：python tool/fix_live_sources.py
import io
import json
import sys

sys.stdout.reconfigure(encoding="utf-8")

PATH = "docs/live_sources.json"

with io.open(PATH, encoding="utf-8") as f:
    sources = json.load(f)

patched = []

for s in sources:
    name = s.get("bookSourceName", "")
    rs = s.setdefault("ruleSearch", {})

    # 看漫画：搜索列表里的图是 img[data-src]（协议相对地址）。
    # 注意 jsoup 链式 `tag.div.0@tag.img@data-src` 取不到，用 CSS 选择器。
    if name == "看漫画kanman":
        rs["coverUrl"] = "@css:div.thumbnail img@data-src"
        rs["author"] = ""
        patched.append(name + ": coverUrl → div.thumbnail img[data-src]")

    # 轻之文库：站上有两套搜索结果模板（桌面 / 移动），选择器要都能命中
    if name == "轻之文库":
        rs["bookList"] = "@css:a.search-book"
        rs["name"] = "@css:div.book-name, div.book-title@text"
        rs["author"] = "@css:div.book-extra, span.author@text##\\s*[丨/]\\s*(著)?.*$"
        rs["intro"] = "@css:div.book-intro, p.intro@text"
        rs["coverUrl"] = "@css:img@src"
        rs["kind"] = ""
        rs["lastChapter"] = ""
        patched.append(name + ": ruleSearch 兼容桌面/移动两套模板")

with io.open(PATH, "w", encoding="utf-8", newline="\n") as f:
    json.dump(sources, f, ensure_ascii=False, indent=2)
    f.write("\n")

print("patched:", *patched, sep="\n  ")
print("total sources:", len(sources))
