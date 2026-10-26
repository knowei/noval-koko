import sqlite3
db = r"C:\Users\zheng\AppData\Roaming\com.noval\noval\noval.db"
con = sqlite3.connect(db); cur = con.cursor()
for t in ("book_source","bookshelf"):
    cols = [r[1] for r in cur.execute(f"PRAGMA table_info({t})")]
    print(t, cols)
print("--- sources ---")
for r in cur.execute("select * from book_source limit 3"):
    print([x if not isinstance(x,str) or len(x)<60 else x[:60]+"..." for x in r])
