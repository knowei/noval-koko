"""kakuyomu 作品页：作者/简介/封面 的可用选择器。"""
import json
import re
import urllib.request

UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')
WORK = '16816700426194102610'


def get(url: str) -> str:
    req = urllib.request.Request(url, headers={'User-Agent': UA, 'Accept-Language': 'ja,en;q=0.8'})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode('utf-8', 'replace')


def main() -> None:
    w = get(f'https://kakuyomu.jp/works/{WORK}')

    print('== /users/ anchors ==')
    for m in list(re.finditer(r'href="/users/[^"]+"[^>]*>([^<]{1,40})</a>', w))[:6]:
        print('   ', re.sub(r'\s+', ' ', w[max(0, m.start() - 150):m.start() + 120])[-260:])

    print('== 简介候选 ==')
    for pat in ['og:description', 'catchphrase', 'introduction', 'あらすじ', 'Introduction']:
        ms = list(re.finditer(pat, w))
        print(f'  [{pat}] {len(ms)}')
        for mm in ms[:2]:
            print('     ', re.sub(r'\s+', ' ', w[max(0, mm.start() - 80):mm.start() + 260])[:340])

    m = re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', w, re.S)
    st = json.loads(m.group(1))['props']['pageProps']['__APOLLO_STATE__']
    wid = re.search(r'/works/(\d+)', w).group(1)
    # work 键可能不是 wid（id 与 url 不同）
    for k, v in st.items():
        if k.startswith('Work:'):
            print('WORK KEY', k, 'url id', wid)
            print('  title:', v.get('title'))
            print('  description:', str(v.get('description'))[:150])
            print('  author ref:', v.get('author'))
            break
    for k, v in st.items():
        if k.startswith('UserAccount:'):
            print('USER', k, v.get('activityName'), v.get('name'))
            break
    # 封面
    for k, v in st.items():
        if 'Image' in k or 'image' in str(v)[:60]:
            print('IMG?', k, str(v)[:120])
            break


if __name__ == '__main__':
    main()
