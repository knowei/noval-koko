"""kakuyomu 长作品目录来源探索：HTML 目次 / __NEXT_DATA__ / API。"""
import json
import re
import urllib.request

UA = (
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
)
WORK = '16816700426194102610'


def get(url: str) -> str:
    req = urllib.request.Request(url, headers={'User-Agent': UA, 'Accept-Language': 'ja,en;q=0.8'})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode('utf-8', 'replace')


def main() -> None:
    w = get(f'https://kakuyomu.jp/works/{WORK}')
    print('page len', len(w))
    print('occurrences of "episodes/":', len(re.findall(r'episodes/', w)))
    ids = sorted(set(re.findall(r'episodes/(\d+)', w)))
    print('episode ids:', len(ids), ids[:5])

    m = re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', w, re.S)
    print('has __NEXT_DATA__:', bool(m))
    if m:
        blob = m.group(1)
        print('next_data len', len(blob))
        ids2 = sorted(set(re.findall(r'"id":"(\d{10,})"', blob)))
        print('ids in next_data:', len(ids2))
        print('keys sample:', list(json.loads(blob).keys()) if blob else '')

    # 目次区域的容器
    for pat in ['目次', 'episodeList', 'widget-toc', 'Chapter', 'js-episode']:
        ms = list(re.finditer(pat, w))[:2]
        print(f'[{pat}] {len(list(re.finditer(pat, w)))}')
        for mm in ms:
            print('   ', re.sub(r'\s+', ' ', w[max(0, mm.start() - 120):mm.start() + 260])[:380])


if __name__ == '__main__':
    main()
