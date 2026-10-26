# -*- coding: utf-8 -*-
"""生成「墨町」应用图标：Android 各密度 + 自适应图标前景 + Windows .ico。

运行：python tool/make_icon.py
设计：墨绿底 + 米白翻开的书 + 沙色书签，扁平、小尺寸可辨。
"""
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_MASTER = os.path.join(ROOT, 'assets', 'icon')
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
ICO = os.path.join(ROOT, 'windows', 'runner', 'resources', 'app_icon.ico')

BASE = 1024          # 逻辑尺寸
SS = 2               # 超采样倍数
S = BASE * SS

BG_TOP = (0x6E, 0x8C, 0x78)
BG_BOTTOM = (0x2C, 0x45, 0x37)
PAPER = (0xF7, 0xF3, 0xE8)
PAPER_EDGE = (0xDD, 0xD4, 0xBB)
RIBBON = (0xD9, 0xA8, 0x76)
INK = (0x22, 0x36, 0x2B)


def sc(*v):
    return [x * SS for x in v]


def qbez(p0, p1, p2, n=48):
    """二次贝塞尔采样（输入/输出均为已缩放的画布坐标）。"""
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        x = u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0]
        y = u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]
        out.append((x, y))
    return out


def gradient_bg(size):
    img = Image.new('RGB', (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        c = tuple(int(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3))
        d.line([(0, y), (size, y)], fill=c)
    return img


def rounded_mask(size, radius):
    m = Image.new('L', (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return m


def book_shapes(scale=1.0, dy=0.0):
    """返回 (左页点集, 右页点集, 书脊线, 书签点集)，围绕 1024 画布中心缩放。"""
    cx, cy = 512, 512
    def p(x, y):
        return (((cx + (x - cx) * scale) * SS), ((cy + (y - cy) * scale + dy) * SS))

    spine_top = p(512, 398)
    spine_bot = p(512, 722)
    out_l_top = p(172, 366)
    out_l_bot = p(172, 664)
    out_r_top = p(852, 366)
    out_r_bot = p(852, 664)

    left = [p(512, 398)]
    left += qbez(spine_top, p(340, 358), out_l_top)
    left += qbez(out_l_top, p(150, 520), out_l_bot)[1:]
    left += qbez(out_l_bot, p(342, 712), spine_bot)[1:]
    left.append(spine_bot)

    right = [p(512, 398)]
    right += qbez(spine_top, p(684, 358), out_r_top)
    right += qbez(out_r_top, p(874, 520), out_r_bot)[1:]
    right += qbez(out_r_bot, p(682, 712), spine_bot)[1:]
    right.append(spine_bot)

    ribbon = [p(612, 386), p(676, 386), p(676, 636), p(644, 594), p(612, 636)]
    return left, right, (spine_top, spine_bot), ribbon


def compose(scale=1.0, dy=0.0, with_bg=True):
    size = S
    if with_bg:
        img = gradient_bg(size).convert('RGBA')
    else:
        img = Image.new('RGBA', (size, size), (0, 0, 0, 0))

    left, right, spine, ribbon = book_shapes(scale, dy)

    # 书下方的柔和投影
    shadow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse([225 * SS, 700 * SS, 800 * SS, 790 * SS], fill=(0, 0, 0, 55))
    shadow = shadow.filter(ImageFilter.GaussianBlur(22 * SS))
    img = Image.alpha_composite(img, shadow)

    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # 纸张厚度（整体下移一点点的暗色副本）
    thick = 10 * SS
    for pts in (left, right):
        d.polygon([(x, y + thick) for x, y in pts], fill=PAPER_EDGE)
    # 纸面
    for pts in (left, right):
        d.polygon(pts, fill=PAPER)
    # 书脊阴影
    d.line([spine[0], spine[1]], fill=(0xC8, 0xBE, 0xA2, 255), width=int(7 * SS))
    # 书签
    d.polygon(ribbon, fill=RIBBON, outline=None)
    img = Image.alpha_composite(img, layer)
    return img


def save_png(img, path, size, radius=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out = img.resize((size, size), Image.LANCZOS)
    if radius is not None:
        mask = rounded_mask(size, max(1, radius * size / BASE))
        base = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        base.paste(out, (0, 0), mask)
        out = base
    out.save(path, 'PNG')


def main():
    master = compose()
    os.makedirs(OUT_MASTER, exist_ok=True)
    save_png(master, os.path.join(OUT_MASTER, 'icon.png'), 1024, radius=232)
    # 整块方形母版（给商店/文档用）
    save_png(master, os.path.join(OUT_MASTER, 'icon_full.png'), 1024)

    # Android 传统图标（带圆角底）
    for dpi, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        save_png(master, os.path.join(RES, f'mipmap-{dpi}', 'ic_launcher.png'), size, radius=232)
        save_png(master, os.path.join(RES, f'mipmap-{dpi}', 'ic_launcher_round.png'), size, radius=size / 2)

    # 自适应图标前景（透明底，内容缩到安全区）
    fg = compose(scale=0.62, dy=10)
    for dpi, size in [('mdpi', 108), ('hdpi', 162), ('xhdpi', 216), ('xxhdpi', 324), ('xxxhdpi', 432)]:
        save_png(fg, os.path.join(RES, f'mipmap-{dpi}', 'ic_launcher_foreground.png'), size)

    # Windows 图标
    ico_sizes = [16, 24, 32, 48, 64, 128, 256]
    frames = [master.resize((s, s), Image.LANCZOS).convert('RGBA') for s in ico_sizes]
    os.makedirs(os.path.dirname(ICO), exist_ok=True)
    frames[-1].save(ICO, format='ICO', sizes=[(s, s) for s in ico_sizes])

    print('icon 生成完成')
    print(ICO)


if __name__ == '__main__':
    main()
