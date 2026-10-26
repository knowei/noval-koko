import re

for f, kw in (('sfacg3.html', '史莱姆'), ('ciyuanji.html', '史莱姆')):
    body = open('tool/ln_probe/' + f, encoding='utf-8', errors='replace').read()
    print('=====', f, len(body))
    idxs = [m.start() for m in re.finditer(re.escape(kw), body)][:3]
    for i in idxs:
        print('--- around', i)
        print(body[max(0, i - 500):i + 300].replace('\n', ' ')[:800])
