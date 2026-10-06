#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
圆表浏览器 (Wear Browser) 应用图标生成器
设计语言（与 圆表SSH 同族）:
  - 深空蓝→青黑 对角渐变背景 (OLED 友好)
  - 一圈细环象征圆形表盘
  - 中央青色地球仪：外圆 + 经线椭圆 + 赤道线 (网络/浏览意象)
  - 环上一颗绿色节点 = 加载/在线状态指示灯
输出:
  assets/icon/icon_source.png       1024 源图 (整体图标)
  assets/icon/icon_foreground.png   1024 自适应图标前景 (透明底, 内容收进安全区)
  assets/icon/icon_background.png   1024 自适应图标背景 (纯渐变)
  assets/icon/preview_96.png        96 小预览 (README 用)
  android/app/src/main/res/drawable-nodpi/wear_bnr.png  400x400 Wear 横幅
"""
import math
import os

from PIL import Image, ImageDraw

SS = 4096          # 超采样绘制尺寸
OUT = 1024         # 图标输出尺寸

# ---- 配色（与圆表SSH一致的家族色）----
BG_TOP = (13, 32, 56)        # 深蓝
BG_BOTTOM = (4, 8, 16)       # 近黑
GLOW = (10, 60, 82)          # 中心辉光 (青色调)
RING = (34, 211, 238, 90)    # 表环 青色 35% alpha
RING_HI = (34, 211, 238, 235)  # 环上高亮段
CYAN = (34, 211, 238)        # 地球仪线条
GREEN = (52, 211, 153)       # 在线节点
NODE_RING = (6, 12, 22)      # 节点周围挖空描边


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def make_background(size):
    """对角渐变 + 中心青色辉光"""
    small = 512
    img = Image.new("RGB", (small, small))
    px = img.load()
    for y in range(small):
        for x in range(small):
            t = (x + y) / (2 * (small - 1))
            px[x, y] = lerp(BG_TOP, BG_BOTTOM, t)
    img = img.resize((size, size), Image.LANCZOS)

    # 径向辉光 mask
    r_small = 256
    mask = Image.new("L", (r_small, r_small))
    mpx = mask.load()
    c = (r_small - 1) / 2.0
    for y in range(r_small):
        for x in range(r_small):
            d = math.hypot(x - c, y - c) / c
            v = max(0.0, 1.0 - d)
            mpx[x, y] = int(255 * (v ** 2) * 0.75)
    mask = mask.resize((size, size), Image.LANCZOS)
    glow = Image.new("RGB", (size, size), GLOW)
    img = Image.composite(glow, img, mask)
    return img


def I(v):
    return int(round(v))


def draw_ring(d, cx, cy, r, w):
    """表环: 底圈 35% 青 + 右上 1/4 高亮段"""
    box = [I(cx - r), I(cy - r), I(cx + r), I(cy + r)]
    d.ellipse(box, outline=RING, width=I(w))
    d.arc(box, start=-78, end=8, fill=RING_HI, width=I(w))


def draw_globe(d, cx, cy, r, w):
    """地球仪: 外圆 + 两条经线椭圆 + 赤道线 (s 归一化到 1024 画布)"""
    # 外圆
    d.ellipse([I(cx - r), I(cy - r), I(cx + r), I(cy + r)],
              outline=CYAN, width=I(w))
    # 经线（两条竖椭圆，模拟球面）
    for k in (0.38, 0.72):
        d.ellipse([I(cx - r * k), I(cy - r), I(cx + r * k), I(cy + r)],
                  outline=CYAN, width=I(w * 0.85))
    # 赤道（略带弧度：用扁椭圆的上下弧线不好取，用直线+圆端点）
    d.line([(I(cx - r), I(cy)), (I(cx + r), I(cy))],
           fill=CYAN, width=I(w))
    # 赤道上下各加一条纬线弧（增强"球"的识别度）
    for k in (0.5, -0.5):
        box = [I(cx - r * 0.94), I(cy + k * r - abs(k) * r * 0.35),
               I(cx + r * 0.94), I(cy + k * r + abs(k) * r * 0.35)]
        d.arc(box, start=200 if k > 0 else 160, end=340 if k > 0 else 200,
              fill=CYAN, width=I(w * 0.8))


def draw_node(d, cx, cy, r_ring, size, gap_color):
    """环上的绿色在线节点（带挖空圈，避免和环糊在一起）"""
    ang = math.radians(-45)  # 右上 45°
    nx = cx + r_ring * math.cos(ang)
    ny = cy + r_ring * math.sin(ang)
    if gap_color is not None:
        gap = size * 1.45
        d.ellipse([I(nx - gap), I(ny - gap), I(nx + gap), I(ny + gap)],
                  fill=gap_color)
    d.ellipse([I(nx - size), I(ny - size), I(nx + size), I(ny + size)],
              fill=GREEN)


def render(with_bg, safe_zone=False):
    """safe_zone=True: 内容缩到自适应图标安全区(约 62%); 用于前景层"""
    size = SS
    if with_bg:
        img = make_background(size)
    else:
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    k = size / 1024.0
    cx = cy = size / 2.0
    if safe_zone:
        r_ring = 285 * k
        w = 20 * k
        globe_r = 175 * k
        gw = 34 * k
        node = 34 * k
    else:
        r_ring = 430 * k
        w = 26 * k
        globe_r = 255 * k
        gw = 46 * k
        node = 46 * k

    draw_ring(draw, cx, cy, r_ring, w)
    draw_globe(draw, cx, cy, globe_r, gw)
    draw_node(draw, cx, cy, r_ring, node,
              NODE_RING if with_bg else None)
    return img


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(here)
    icon_dir = os.path.join(root, "assets", "icon")
    res_dir = os.path.join(root, "android", "app", "src", "main", "res",
                           "drawable-nodpi")
    os.makedirs(icon_dir, exist_ok=True)
    os.makedirs(res_dir, exist_ok=True)

    # 1) 完整源图标 (背景 + 内容)
    full = render(with_bg=True, safe_zone=False).resize((OUT, OUT), Image.LANCZOS)
    full.save(os.path.join(icon_dir, "icon_source.png"))

    # 2) 自适应图标前景 (透明底, 内容收进安全区)
    fg = render(with_bg=False, safe_zone=True).resize((OUT, OUT), Image.LANCZOS)
    fg.save(os.path.join(icon_dir, "icon_foreground.png"))

    # 3) 自适应图标背景 (纯渐变)
    bg = make_background(OUT)
    bg.save(os.path.join(icon_dir, "icon_background.png"))

    # 4) README 小预览
    full.resize((96, 96), Image.LANCZOS).save(
        os.path.join(icon_dir, "preview_96.png"))

    # 5) Wear OS 横幅 400x400
    full.resize((400, 400), Image.LANCZOS).save(
        os.path.join(res_dir, "wear_bnr.png"))

    print("图标已生成:")
    for p in ["assets/icon/icon_source.png", "assets/icon/icon_foreground.png",
              "assets/icon/icon_background.png", "assets/icon/preview_96.png",
              "android/app/src/main/res/drawable-nodpi/wear_bnr.png"]:
        print("  -", p)


if __name__ == "__main__":
    main()
