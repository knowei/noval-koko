import os
import sqlite3

p = os.path.expandvars(r"%APPDATA%\com.noval\noval\noval.db")
c = sqlite3.connect(p)
print("db:", p)
print("sources:", c.execute("select count(*) from book_source").fetchone()[0])
print("shelf:", c.execute("select count(*) from bookshelf").fetchone()[0])
print("chapters:", c.execute("select count(*) from chapter").fetchone()[0])
print(
    "covers non-empty:",
    c.execute("select count(*) from bookshelf where cover is not null and cover<>''").fetchone()[0],
)
for row in c.execute("select name, source_name, (case when cover is null or cover='' then 'NO' else 'YES' end) from bookshelf"):
    print(" -", row)
