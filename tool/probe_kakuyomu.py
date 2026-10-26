"""kakuyomu.jp 页面结构探针：搜索页 / 作品页 / 章节页。"""
import re
import urllib.parse
import urllib.request

UA = (
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
)


def get(url: str) -> str:
    req = urllib.request.Request(url, headers={'User-Agent': UA, 'Accept-Language': 'ja,en;q=0.8'})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode('utf-8', 'replace')


def sh(tag: str, s: str, n: int = 6, w: int = 220) -> None:
    print(f'--- {tag}: {len(s)} chars')
    for m in list(re.finditer(re.escape(tag), s))[:n]:
        seg = s[m.start():m.start() + w]
        seg = re.sub(r'\s+', ' ', seg)
        print('   ', seg[:w])


def main() -> None:
    q = urllib.parse.quote('スライム')
    s = get(f'https://kakuyomu.jp/search?q={q}')
    sh('href="/users/', s, 3)
    sh('<h3', s, 3)

    work = re.search(r'href="(/works/\d+)"', s)
    wurl = 'https://kakuyomu.jp' + work.group(1)
    print('\n== WORK', wurl)
    w = get(wurl)
    sh('<h1', w, 2)
    eps = re.findall(r'href="(/works/\d+/episodes/\d+)"', w)
    print('episode links:', len(eps), eps[:3])
    sh('episodes/', w, 2)
    # 简介
    for pat in ['og:description', 'あらすじ', 'widget-episodeTitle', '章']:
        sh(pat, w, 1, 160)

    if eps:
        eurl = 'https://kakuyomu.jp' + eps[0]
        print('\n== EPISODE', eurl)
        e = get(eurl)
        print('len', len(e))
        for pat in ['id="contentMain', 'widget-episodeBody', '<p id="p1"', '<h1', 'og:title']:
            sh(pat, e, 1, 300)
        ps = re.findall(r'<p id="p\d+"', e)
        print('p#pN count:', len(ps))


if __name__ == '__main__':
    main()
