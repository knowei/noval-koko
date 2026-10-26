import io
import json

UA_WIN = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')

NEW = [
    {
        'bookSourceName': 'SF轻小说',
        'bookSourceUrl': 'https://book.sfacg.com',
        'bookSourceType': 0,
        'bookSourceGroup': '💜轻小说',
        'bookSourceComment': '中文轻小说站。搜索 s.sfacg.com，目录 /MainIndex/，正文 #ChapterBody；'
                             '名称/作者取 meta keywords（页面里推荐位有同名 class，避免误取）。',
        'enabled': True,
        'enabledCookieJar': False,
        'enabledExplore': False,
        'searchUrl': 'http://s.sfacg.com/?Key={{key}}&S=1&SS=0',
        'header': json.dumps({'User-Agent': UA_WIN, 'Referer': 'https://book.sfacg.com/'},
                             ensure_ascii=False),
        'ruleSearch': {
            'bookList': '@css:table.comic_cover ul',
            'name': '@css:strong.F14PX a@text',
            'author': '',
            'bookUrl': '@css:strong.F14PX a@href',
            'coverUrl': '@css:img@src',
            'intro': '@css:li!1@text',
            'kind': '',
            'lastChapter': '',
            'updateTime': '',
            'wordCount': '',
            'checkKeyWord': '',
        },
        'ruleBookInfo': {
            'name': '@css:meta[name="keywords"]@content##^([^,]*),.*$###$1',
            'author': '@css:meta[name="keywords"]@content##^[^,]*,([^,]*).*$###$1',
            'intro': '@css:.book-summary!0@text',
            'coverUrl': '',
            'kind': '',
            'lastChapter': '',
            'wordCount': '',
            'tocUrl': '@js:(function(){return baseUrl.replace(/\\/$/,"")+"/MainIndex/";})()',
        },
        'ruleToc': {
            'chapterList': '@css:.catalog-list li',
            'chapterName': '@css:a@text',
            'chapterUrl': '@css:a@href',
            'isVolume': '',
            'isVip': '',
        },
        'ruleContent': {'content': '@css:#ChapterBody@html'},
    },
    {
        'bookSourceName': '漢典古籍',
        'bookSourceUrl': 'https://gj.zdic.net',
        'bookSourceType': 0,
        'bookSourceGroup': '📚名著',
        'bookSourceComment': '中文古籍/名著全文（繁体）。EmpireCMS 搜索走 /e/search/index.php POST keyboard；'
                             '目录在 div.article-bookdata 的 li，正文 div.article-body。',
        'enabled': True,
        'enabledCookieJar': False,
        'enabledExplore': False,
        'searchUrl': 'https://gj.zdic.net/e/search/index.php,{"method":"POST","body":"keyboard={{key}}&show=title&classid=0"}',
        'header': json.dumps({'User-Agent': UA_WIN, 'Referer': 'https://gj.zdic.net/'},
                             ensure_ascii=False),
        'ruleSearch': {
            'bookList': '@css:div.article-details',
            'name': '@css:div.article-title a@text',
            'author': '',
            'bookUrl': '@css:div.article-title a@href',
            'coverUrl': '',
            'intro': '',
            'kind': '',
            'lastChapter': '',
            'updateTime': '',
            'wordCount': '',
            'checkKeyWord': '',
        },
        'ruleBookInfo': {
            'name': '@css:h1!0@text',
            'author': '',
            'intro': '@css:meta[name="description"]@content',
            'coverUrl': '',
            'kind': '',
            'lastChapter': '',
            'wordCount': '',
            'tocUrl': '',
        },
        'ruleToc': {
            'chapterList': '@css:div.article-bookdata li',
            'chapterName': '@css:a@text',
            'chapterUrl': '@css:a@href',
            'isVolume': '',
            'isVip': '',
        },
        'ruleContent': {'content': '@css:div.article-body@html'},
    },
    {
        'bookSourceName': 'Project Gutenberg',
        'bookSourceUrl': 'https://www.gutenberg.org',
        'bookSourceType': 0,
        'bookSourceGroup': '📚名著',
        'bookSourceComment': '英文公版名著（7 万+ 本）。搜索页 HTML；书籍详情页取 #book_title；'
                             '正文用 /cache/epub/{id}/pg{id}-images.html 单页全文，去掉 header/footer 版权块，'
                             '整本作为一章「全文」交给阅读器分页。',
        'enabled': True,
        'enabledCookieJar': False,
        'enabledExplore': False,
        'searchUrl': 'https://www.gutenberg.org/ebooks/search/?query={{key}}',
        'header': json.dumps({'User-Agent': UA_WIN}, ensure_ascii=False),
        'ruleSearch': {
            'bookList': '@css:li.booklink',
            'name': '@css:span.title@text',
            'author': '@css:span.subtitle@text',
            'bookUrl': '@css:a.link@href',
            'coverUrl': '@css:img.cover-thumb@src',
            'intro': '',
            'kind': '',
            'lastChapter': '',
            'updateTime': '',
            'wordCount': '',
            'checkKeyWord': '',
        },
        'ruleBookInfo': {
            'name': '@css:h1#book_title@text## by .*$###',
            'author': '@css:a[itemprop="creator"]!0@text##,\\s*\\d{4}.*$###',
            'intro': '',
            'coverUrl': '',
            'kind': '',
            'lastChapter': '',
            'wordCount': '',
            'tocUrl': '@js:(function(){var m=baseUrl.match(/ebooks\\/(\\d+)/);return m?("https://www.gutenberg.org/cache/epub/"+m[1]+"/pg"+m[1]+"-images.html"):baseUrl;})()',
        },
        'ruleToc': {
            'chapterList': '@js:(function(){return ["<a href=\\""+baseUrl+"\\">全文</a>"];})()',
            'chapterName': '@css:a@text',
            'chapterUrl': '@css:a@href',
            'isVolume': '',
            'isVip': '',
        },
        'ruleContent': {
            'content': '@js:(function(){var s=java.ajax(baseUrl);'
                       's=s.replace(/<header[\\s\\S]*?<\\/header>/,"");'
                       's=s.replace(/<footer[\\s\\S]*?<\\/footer>/,"");return s;})()',
        },
    },
]

KAKUYOMU_GROUP = '🇯🇵日轻'

path = 'docs/live_sources.json'
live = json.load(io.open(path, encoding='utf-8'))
names = {s['bookSourceName'] for s in live}

kak = json.load(io.open('sample_sources/kakuyomu.json', encoding='utf-8'))
if isinstance(kak, list):
    kak = kak[0]
kak = dict(kak)
kak['bookSourceGroup'] = KAKUYOMU_GROUP
kak['bookSourceComment'] = '日本轻小说（カクヨム / KADOKAWA）。目录藏在页面 __NEXT_DATA__ 的 Apollo 缓存里，' \
                           '规则用 @js 解析 TableOfContentsChapter 顺序后拼 <a>，正文取 widget-episodeBody 的段落。'

for s in NEW + [kak]:
    if s['bookSourceName'] in names:
        live = [x for x in live if x['bookSourceName'] != s['bookSourceName']]
    live.append(s)

io.open(path, 'w', encoding='utf-8').write(
    json.dumps(live, ensure_ascii=False, indent=2) + '\n')

print('total', len(live))
for s in live:
    print(' -', s['bookSourceName'], '|', s.get('bookSourceGroup', ''))
