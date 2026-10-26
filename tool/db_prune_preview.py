import sqlite3, json, io
db = r"C:\Users\zheng\AppData\Roaming\com.noval\noval\noval.db"
cur_src = json.load(open(r"D:\pro\work\proj\DSH\noval\docs\live_sources.json", encoding="utf-8"))
keep = {s["bookSourceUrl"].rstrip("/") for s in cur_src}
con = sqlite3.connect(db); c = con.cursor()
rows = list(c.execute("select url, name, enabled from book_source order by name"))
out = io.StringIO()
out.write("keep=%d\n" % len(keep))
for u, n, e in rows:
    out.write("%s %-24s enabled=%s keep=%s\n" % ("KEEP" if u.rstrip("/") in keep else "DEL ", n[:24], e, u.rstrip("/") in keep))
shelf = list(c.execute("select book_url, name, source_url from bookshelf"))
out.write("\nshelf %d\n" % len(shelf))
for bu, n, su in shelf:
    out.write("  %-22s %s keep=%s\n" % (n[:22], su, (su or "").rstrip("/") in keep))
open(r"D:\pro\work\proj\DSH\noval\tool\db_report.txt", "w", encoding="utf-8").write(out.getvalue())
print("sources", len(rows), "shelf", len(shelf))
