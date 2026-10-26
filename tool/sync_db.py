import io
import json
import sqlite3
import time

PATH = 'docs/live_sources.json'
DB = r'C:\Users\zheng\AppData\Roaming\com.noval\noval\noval.db'

GROUP = {
    '看漫画kanman': '🧩漫画',
    '河豚小说hetunxs': '📖中文小说',
    '连载书lianzaisu': '📖中文小说',
    'SF轻小说': '📗中文轻小说',
    '轻之文库': '📗中文轻小说',
    '哔哩轻小说': '📗中文轻小说',
    'カクヨム': '🗾日文轻小说',
    '漢典古籍': '🏛名著',
    'Standard Ebooks': '🏛名著',
}

src = json.load(io.open(PATH, encoding='utf-8'))
for s in src:
    g = GROUP.get(s['bookSourceName'])
    if g:
        s['bookSourceGroup'] = g
io.open(PATH, 'w', encoding='utf-8').write(
    json.dumps(src, ensure_ascii=False, indent=2) + '\n')

now = int(time.time() * 1000)
c = sqlite3.connect(DB)
c.execute('DELETE FROM book_source')
for i, s in enumerate(src):
    c.execute(
        'INSERT INTO book_source(url,name,type,group_name,enabled,sort,json,updated_time)'
        ' VALUES(?,?,?,?,?,?,?,?)',
        (s['bookSourceUrl'], s['bookSourceName'], int(s.get('bookSourceType', 0)),
         s.get('bookSourceGroup', ''), 1, i,
         json.dumps(s, ensure_ascii=False), now))
c.commit()

print('db sources:')
for r in c.execute('select name,type,group_name,sort from book_source order by sort'):
    print('  ', r)
print('shelf books:', c.execute('select count(*) from bookshelf').fetchone()[0])
print('chapters:', c.execute('select count(*) from chapter').fetchone()[0])
