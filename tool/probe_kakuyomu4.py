"""定位 kakuyomu 作品页 __NEXT_DATA__ 里 目录/作者/简介 的 JSON 路径。"""
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


def walk(v, path='$', depth=0, out=None):
    if out is None:
        out = []
    if depth > 5:
        return out
    if isinstance(v, dict):
        for k, vv in list(v.items())[:40]:
            p = f'{path}.{k}'
            if k.startswith(('Episode:', 'TableOfContentsChapter:', 'Work:')) or 'pollo' in k:
                out.append(p)
                continue
            walk(vv, p, depth + 1, out)
    return out


def main() -> None:
    w = get(f'https://kakuyomu.jp/works/{WORK}')
    m = re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', w, re.S)
    j = json.loads(m.group(1))
    pp = j['props']['pageProps']
    print('pageProps keys:', list(pp.keys()))
    for k in pp:
        if 'pollo' in k or 'tate' in k or 'tate'.lower() in k.lower():
            print('candidate:', k, type(pp[k]))
    hits = walk(pp)
    print('paths:', hits[:10])

    # 找 apollo cache：含 Episode: 键的字典
    def find_cache(v, path='$', depth=0):
        if depth > 6:
            return
        if isinstance(v, dict):
            if any(str(k).startswith('Episode:') for k in v.keys()):
                print('CACHE at', path, 'size', len(v))
                eps = [k for k in v if k.startswith('Episode:')]
                print('  episodes', len(eps))
                print('  first:', json.dumps(v[eps[0]], ensure_ascii=False)[:200])
                toc = [k for k in v if k.startswith('TableOfContentsChapter:')]
                print('  toc chapters', len(toc))
                if toc:
                    print('  toc0:', json.dumps(v[toc[0]], ensure_ascii=False)[:300])
                work = [k for k in v if k.startswith('Work:')]
                if work:
                    print('  work:', json.dumps(v[work[0]], ensure_ascii=False)[:400])
                return
            for k, vv in list(v.items())[:60]:
                find_cache(vv, f'{path}.{k}', depth + 1)
    find_cache(pp)


if __name__ == '__main__':
    main()
