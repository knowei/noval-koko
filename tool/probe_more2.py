import re
import urllib.parse
import urllib.request

UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')
MUA = ('Mozilla/5.0 (Linux; Android 8.0; Pixel 2 Build/OPD3.170816.012) '
       'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.71 Mobile Safari/537.36')


def probe(tag, url, kw, enc='utf-8', mobile=False, save=None, referer=None):
    h = {'User-Agent': MUA if mobile else UA,
         'Accept-Language': 'zh-CN,zh;q=0.9'}
    if referer:
        h['Referer'] = referer
    try:
        r = urllib.request.Request(url, headers=h)
        resp = urllib.request.urlopen(r, timeout=20)
        body = resp.read().decode(enc, 'replace')
    except Exception as e:  # noqa: BLE001
        print('%-14s ERR %s' % (tag, e))
        return None
    print('%-14s %s len=%d kwIn=%s links=%d' %
          (tag, resp.geturl()[:55], len(body), kw in body,
           len(re.findall(r'<a [^>]*href="[^"]+"', body))))
    if save:
        open('tool/ln_probe/' + save, 'w', encoding='utf-8').write(body)
    return body


kw = '西游记'

probe('gushiwen-www', 'https://www.gushiwen.cn/search.aspx?value=' + urllib.parse.quote(kw),
      kw, save='gushiwen2.html')
probe('shicimingju', 'https://www.shicimingju.com/search.html?keyword=' + urllib.parse.quote(kw),
      kw, save='shicimingju.html')
probe('eywedu', 'https://www.eywedu.com/', kw, save='eywedu.html')
probe('tianyabooks', 'https://www.tianyabooks.com/', kw, save='tianyabooks.html')
probe('zdicgj-home', 'https://gj.zdic.net/', kw, save='zdicgj2.html')
probe('guoxuedaohang', 'http://www.guoxuedaohang.com/', kw, save='gxdh.html')
probe('wenxue360', 'https://www.wenxuemi6.com/', kw, save='wenxuemi.html')
probe('sfacg-book', 'https://book.sfacg.com/Search/?Key=' + urllib.parse.quote(kw),
      kw, save='sfacg2.html')
probe('qbtr-home', 'https://www.qbtr.cc/', '轻小说', save='qbtr2.html')
