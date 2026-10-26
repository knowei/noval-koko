"""kakuyomu 细节探针：章节标题选择器 / 作品简介 / 长作品目录完整性 + 搜索项内封面。"""
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


def show(tag: str, s: str, n: int = 2, w: int = 260) -> None:
    hits = list(re.finditer(re.escape(tag), s))[:n]
    print(f'[{tag}] hits={len(list(re.finditer(re.escape(tag), s)))}')
    for m in hits:
        print('   ', re.sub(r'\s+', ' ', s[m.start():m.start() + w])[:w])


def main() -> None:
    # 1) 长作品目录：437 话
    w = get('https://kakuyomu.jp/works/16816700426194102610')
    eps = set(re.findall(r'/works/16816700426194102610/episodes/(\d+)', w))
    print('长作品 episode 唯一数:', len(eps), '页面大小', len(w))

    # 2) 章节页标题选择器
    e = get('https://kakuyomu.jp/works/16816700426194102610/episodes/16816700426202365994')
    for pat in ['episodeTitle', 'contentMain-header', 'widget-episodeBody', 'widget-episodeTitle']:
        show(pat, e, 2, 200)

    # 3) 作品页简介/作者/封面
    for pat in ['og:image', 'workDescription', 'widget-workDescription', 'pr-1', 'js-ogp', 'author']:
        show(pat, w, 1, 200)

    # 4) 搜索项里的封面图
    q = urllib.parse.quote('スライム')
    s = get(f'https://kakuyomu.jp/search?q={q}')
    print('搜索结果 img 数:', len(re.findall(r'<img', s)))
    show('<img', s, 3, 260)


if __name__ == '__main__':
    main()
