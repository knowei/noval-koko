b = open('tool/ln_probe/sfacg_book.html', encoding='utf-8', errors='replace').read()
i = b.find('转生史莱姆娘，魔王变勇者白月光')
print(b[max(0, i - 2500):i + 1200])
