import re
import sys
import urllib.parse
import urllib.request

UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')
MUA = ('Mozilla/5.0 (Linux; Android 8.0; Pixel 2 Build/OPD3.170816.012) '
       'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.71 Mobile Safari/537.36')


def fetch(url, enc='utf-8', mobile=False, data=None, referer=None):
    h = {'User-Agent': MUA if mobile else UA,
         'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8'}
    if referer:
        h['Referer'] = referer
    if data is not None:
        h['Content-Type'] = 'application/x-www-form-urlencoded'
    r = urllib.request.Request(url, data=data, headers=h)
    resp = urllib.request.urlopen(r, timeout=25)
    return resp.geturl(), resp.read().decode(enc, 'replace')


def probe(tag, url, kw, enc='utf-8', mobile=False, data=None, referer=None, save=None):
    try:
        fin, body = fetch(url, enc, mobile, data, referer)
    except Exception as e:  # noqa: BLE001
        print('%-16s ERR %s' % (tag, e))
        return None
    has = kw in body
    print('%-16s %s len=%d kwIn=%s' % (tag, fin[:60], len(body), has))
    if save:
        open('tool/ln_probe/' + save, 'w', encoding='utf-8').write(body)
    return body


kw_ln = '史莱姆'
kw_cn = '西游记'
kw_en = 'pride'

probe('sfacg', 'http://s.sfacg.com/?Key=' + urllib.parse.quote(kw_ln.encode('gbk')) +
      '&S=1&SS=0', kw_ln, enc='gbk', save='sfacg.html')
probe('ciyuanji', 'https://www.ciyuanji.com/search/' + urllib.parse.quote(kw_ln) +
      '_0_0_0_0_0_1.html', kw_ln, save='ciyuanji.html')
probe('wenku8', 'https://www.wenku8.cc/modules/article/search.php?searchtype=articlename&searchkey=' +
      urllib.parse.quote(kw_ln.encode('gbk')) + '&page=1', kw_ln, enc='gbk',
      save='wenku8.html')
probe('gushiwen', 'https://m.gushiwen.cn/search.aspx?value=' + urllib.parse.quote(kw_cn) +
      '&valuej=' + urllib.parse.quote(kw_cn), kw_cn, mobile=True, save='gushiwen.html')
probe('gutenberg', 'https://www.gutenberg.org/ebooks/search/?query=' +
      urllib.parse.quote(kw_en), kw_en, save='gutenberg.html')
probe('zdic-gj', 'http://gj.zdic.net/search.php?keyword=' + urllib.parse.quote(kw_cn),
      kw_cn, save='zdicgj.html')
probe('guoxue', 'https://www.guoxuedashi.net/so.php?sw=' + urllib.parse.quote(kw_cn),
      kw_cn, save='guoxue.html')
probe('qbtr', 'https://www.qbtr.cc/e/search/index.php', kw_ln, enc='gb2312',
      data=('keyboard=' + urllib.parse.quote(kw_ln.encode('gb2312')) +
            '&show=title&classid=0').encode('ascii'),
      referer='https://www.qbtr.cc/', save='qbtr.html')
