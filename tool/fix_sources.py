import io
import json

path = 'docs/live_sources.json'
src = json.load(io.open(path, encoding='utf-8'))

se = json.load(io.open('sample_sources/standardebooks.json', encoding='utf-8'))
if isinstance(se, list):
    se = se[0]
se = dict(se)
se['bookSourceGroup'] = '📚名著'
se['bookSourceComment'] = ('英文公版名著（Standard Ebooks，服务端渲染、无反爬）。搜索 /ebooks?query=；'
                           '详情页取 h1 书名与 section#description 简介；目录在 bookUrl + "/text"；'
                           '正文取 main p。整本英文书会被阅读器自动分页。')

out = []
for s in src:
    name = s['bookSourceName']
    if name == 'Project Gutenberg':
        continue  # 用 Standard Ebooks 代替：Gutenberg 单页全文 70 万字，阅读器分页会卡
    if name == 'SF轻小说':
        s['ruleBookInfo']['name'] = '@css:meta[name="keywords"]@content##^([^,]+),.*$##$1'
        s['ruleBookInfo']['author'] = '@css:meta[name="keywords"]@content##^[^,]+,\\s*##'
        s['ruleToc']['chapterName'] = '@css:a@text##^\\s*VIP\\s*##'
    out.append(s)

out.append(se)
io.open(path, 'w', encoding='utf-8').write(
    json.dumps(out, ensure_ascii=False, indent=2) + '\n')

for s in out:
    print(' -', s['bookSourceName'], '|', s.get('bookSourceGroup', ''))
print('total', len(out))
