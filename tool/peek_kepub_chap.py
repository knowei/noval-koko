import io
import re
import json
import requests

s = requests.Session()
s.trust_env = False
UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/124.0.0.0 Safari/537.36'
H = {'User-Agent': UA, 'Accept-Language': 'zh-CN,zh;q=0.9'}
out = []

for cid in ['10001', '10004', '10029']:
    u = 'https://www.kepub.net/book/10044/%s' % cid
    r = s.get(u, headers=H, timeout=30)
    h = r.text
    io.open('tool/kp_chap_%s.html' % cid, 'w', encoding='utf-8').write(h)
    m = re.search(r'<div[^>]*id="content"[^>]*>(.*?)</div>', h, re.S)
    body = m.group(1) if m else ''
    text = re.sub(r'<[^>]+>', '', body)
    text = text.replace('&nbsp;', ' ')
    out.append('chapter %s -> %s %dB contentlen=%d textlen=%d' % (cid, r.status_code, len(r.content), len(body), len(text.strip())))
    out.append('   text head: %s' % text.strip()[:120].replace('\n', ' '))
    navs = re.findall(r'<a[^>]+href="(/book/10044/\d+)"[^>]*>(.*?)</a>', h, re.S)
    out.append('   navs: %s' % json.dumps([[a, re.sub(r'<[^>]+>', '', b).strip()] for a, b in navs[:8]], ensure_ascii=False))
    out.append('   title: %s' % (re.findall(r'<title>(.*?)</title>', h)[:1]))
    # content div 的属性
    out.append('   content tag: %s' % (re.search(r'<div[^>]*id="content"[^>]*>', h).group(0) if m else None))
    # 是否有分页
    out.append('   page links: %s' % re.findall(r'href="([^"]*_\d+\.html)"', h)[:5])

io.open('tool/kp_chap_probe.txt', 'w', encoding='utf-8').write('\n'.join(out))
print('done')
