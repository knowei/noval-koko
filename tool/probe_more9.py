import re
import urllib.parse
import urllib.request

UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')


def fetch(u, data=None, ref=None):
    h = {'User-Agent': UA}
    if ref:
        h['Referer'] = ref
    if data:
        h['Content-Type'] = 'application/x-www-form-urlencoded'
        data = data.encode('ascii')
    r = urllib.request.Request(u, data=data, headers=h)
    resp = urllib.request.urlopen(r, timeout=25)
    return resp.geturl(), resp.read().decode('utf-8', 'replace')


# sfacg 目录：章节链接所在的容器
t = open('tool/ln_probe/sfacg_toc.html', encoding='utf-8', errors='replace').read()
i = t.find('/Novel/758795/1005748/9350352/')
print('SFACGCAT', t[max(0, i - 500):i + 300].replace('\n', ' ')[:800])

# 汉典古籍 搜索结果结构
z = open('tool/ln_probe/zdicgj_search.html', encoding='utf-8', errors='replace').read()
i = z.find('西游记')
print('==== ZDIC ctx', z[max(0, i - 600):i + 400].replace('\n', ' ')[:900])
print('ZDIC classes', sorted(set(re.findall(r'class="([^"]+)"', z)))[:30])
for m in re.finditer(r'<a[^>]*href="([^"]*)"[^>]*>([^<]{0,40}西游记[^<]{0,40})</a>', z):
    print('ZDIC LINK', m.group(1), '|', m.group(2))
