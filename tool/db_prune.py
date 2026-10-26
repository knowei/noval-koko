import sqlite3, json
db = r"C:\Users\zheng\AppData\Roaming\com.noval\noval\noval.db"
keep = {s["bookSourceUrl"].rstrip("/") for s in json.load(open(r"D:\pro\work\proj\DSH\noval\docs\live_sources.json", encoding="utf-8"))}
con = sqlite3.connect(db); c = con.cursor()
urls = [r[0] for r in c.execute("select url from book_source")]
dead = [u for u in urls if u.rstrip("/") not in keep]
c.executemany("delete from book_source where url=?", [(u,) for u in dead])
# 清掉指向已删除书源的书架条目与缓存章节
live = [r[0] for r in c.execute("select url from book_source")]
c.execute("delete from bookshelf where source_url not in (%s)" % ",".join("?" * len(live)), live)
kept_books = [r[0] for r in c.execute("select book_url from bookshelf")]
c.execute("delete from chapter where book_url not in (%s)" % ",".join("?" * len(kept_books)), kept_books) if kept_books else c.execute("delete from chapter")
con.commit()
print("deleted sources:", len(dead))
print("sources now:", c.execute("select count(*) from book_source").fetchone()[0])
print("shelf now:", c.execute("select count(*) from bookshelf").fetchone()[0])
print("chapters now:", c.execute("select count(*) from chapter").fetchone()[0])
for r in c.execute("select url, name from book_source order by name"):
    print("  keep:", r[1], r[0])
