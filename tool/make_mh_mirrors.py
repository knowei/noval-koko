"""生成「包子系」同构漫画站的源（bzmh.org / godamh.com）。

模板来自 sample_sources/baozimh.json：同一套 Astro 前端 + v2.apikk.top 目录/章节接口 +
/assets/runtime/chapter-decoder.js 图片解密。只换域名与显示名。
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
TPL = json.loads((ROOT / 'sample_sources' / 'baozimh.json').read_text(encoding='utf-8'))
UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')

MIRRORS = [
    ('bzmh.org', 'https://bzmh.org', '包子漫画·镜像', '🧩漫画',
     'bzmh.org 与 baozimh.org 同构（Astro 模板 + v2.apikk.top 接口 + chapter-decoder.js 解密）；'
     'baozimh.org 打不开时可用这个兜底。'),
    ('godamh', 'https://godamh.com', 'G站漫画', '🧩漫画',
     'godamh.com 同构包子系（不同构建的 chapter-decoder.js）；搜索/目录/图片均可用。'),
]


def build(path_key: str, base: str, name: str, group: str, comment: str) -> dict:
    src = json.loads(json.dumps(TPL))  # deep copy
    old = TPL['bookSourceUrl']

    def sub(obj):
        if isinstance(obj, str):
            return obj.replace(old, base)
        if isinstance(obj, dict):
            return {k: sub(v) for k, v in obj.items()}
        if isinstance(obj, list):
            return [sub(v) for v in obj]
        return obj

    src = sub(src)
    src['bookSourceName'] = name
    src['bookSourceGroup'] = group
    src['bookSourceComment'] = comment
    src['header'] = json.dumps({'User-Agent': UA, 'Referer': base + '/'}, ensure_ascii=False)
    out = ROOT / 'sample_sources' / f'{path_key}.json'
    out.write_text(json.dumps(src, ensure_ascii=False, indent=2), encoding='utf-8')
    print('written', out.relative_to(ROOT), len(json.dumps(src, ensure_ascii=False)), 'chars')
    return src


for key, base, name, group, comment in MIRRORS:
    build(key, base, name, group, comment)
