import re


def show(path, pats, before=160, after=240, limit=2):
    h = open(path, encoding='utf-8', errors='replace').read()
    print('== %s len=%d' % (path, len(h)))
    for pat in pats:
        print('--- %s (x%d)' % (pat, h.count(pat)))
        for i, m in enumerate(re.finditer(re.escape(pat), h)):
            if i >= limit:
                break
            print(h[max(0, m.start() - before):m.start() + after].replace('\n', ' '))


if __name__ == '__main__':
    show('tool/ln_probe/lib_book.html',
         ['og:image', 'book-img', 'book-name', 'authorarticle', 'read_url'])
    show('tool/ln_probe/lib_catalog.html',
         ['volume-list', 'chapter-list'],
         before=120, after=300, limit=2)
    show('tool/ln_probe/lib_catalog.html', ['volumes'], before=100, after=400, limit=1)
