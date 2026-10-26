import io, re, sys, os

path = sys.argv[1] if len(sys.argv) > 1 else 'tool/ln_probe/linovel_net.html'
raw = open(path, 'rb').read()
text = None
for enc in ('gbk', 'gb18030', 'utf-8'):
    try:
        text = raw.decode(enc)
        print('decoded with', enc)
        break
    except Exception as e:
        print(enc, 'fail', e)
if text is None:
    text = raw.decode('utf-8', errors='ignore')

# 保存成 utf-8 方便后续用 read 工具看
io.open(path + '.utf8.html', 'w', encoding='utf-8').write(text)

key = sys.argv[2] if len(sys.argv) > 2 else '史莱姆'
i = text.find(key)
print('len', len(text), 'first hit at', i)
print('====================')
start = text.rfind('<div', 0, max(0, i - 3000))
print(text[max(0, i - 2500):i + 2500])
