import io, sys

p = sys.argv[1]
raw = open(p, 'rb').read()
print('bytes', len(raw))
utf8_key = '史莱姆'.encode('utf-8')
gbk_key = '史莱姆'.encode('gbk')
print('utf8 hits', raw.count(utf8_key), 'gbk hits', raw.count(gbk_key))
print('title area hex:', raw[80:140])
# 判断有多少非法 utf-8
bad = 0
i = 0
while i < len(raw):
    b = raw[i]
    if b < 0x80:
        i += 1
        continue
    n = 2 if b >> 5 == 0b110 else 3 if b >> 4 == 0b1110 else 4 if b >> 3 == 0b11110 else 0
    if n == 0:
        bad += 1
        i += 1
        continue
    i += n
print('invalid-ish lead bytes', bad)
for enc in ('utf-8', 'gbk', 'gb18030', 'big5', 'utf-16'):
    try:
        raw.decode(enc)
        print('strict ok', enc)
    except Exception as e:
        print('strict fail', enc, e)
