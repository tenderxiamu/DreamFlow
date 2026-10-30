"""把横拍天空照片处理成手机竖屏壁纸。

为什么不是「直接塞原图让 Flutter cover 裁」：
源图是 1280x960（4:3 横），手机是 9:19.5 竖。cover 裁完只剩中间 456px 宽，
再放大 2.4 倍，云会糊成一团脏斑。所以这里主动做三件事：

1. **先竖切**：按偏移量取一条竖带，构图由调用方指定（往左/往右让开塔吊、楼角）
2. **再重模糊**：壁纸是背景，不是照片。模糊之后文字才读得清，
   而且低分辨率放大这件事被模糊掩盖掉了 —— 这是关键，否则只能换竖拍素材
3. **加极轻噪点**：模糊 + JPEG 会在渐变色上拉出 banding，噪点用来打散它

用法：
    python tool/make_wallpaper.py <src> <dst> [--offset 0.5] [--blur 16]
"""
from __future__ import annotations

import argparse
import os

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

TW, TH = 1080, 2280  # 目标尺寸 9:19


def make(src: str, dst: str, offset: float, blur: float, sat: float,
         grain: float) -> None:
    im = Image.open(src).convert('RGB')
    w, h = im.size
    ratio = TW / TH

    if w / h > ratio:
        # 横图：切一条竖带
        cw = int(round(h * ratio))
        x0 = int(round((w - cw) * offset))
        box = (x0, 0, x0 + cw, h)
    else:
        # 竖图：切一条横带（绝大多数情况下用不到）
        ch = int(round(w / ratio))
        y0 = int(round((h - ch) * offset))
        box = (0, y0, w, y0 + ch)

    crop = im.crop(box).resize((TW, TH), Image.LANCZOS)
    crop = ImageEnhance.Color(crop).enhance(sat)
    crop = crop.filter(ImageFilter.GaussianBlur(blur))

    if grain > 0:
        a = np.asarray(crop).astype(np.float32)
        rng = np.random.default_rng(20261028)
        noise = rng.normal(0, grain * 255, (TH, TW, 1)).astype(np.float32)
        a = np.clip(a + noise, 0, 255)
        crop = Image.fromarray(a.astype(np.uint8))

    crop.save(dst, 'JPEG', quality=92, optimize=True, progressive=True)

    y = np.asarray(crop.convert('RGB')).astype(np.float32)
    lum = 0.2126 * y[..., 0] + 0.7152 * y[..., 1] + 0.0722 * y[..., 2]
    print('%-14s %5.0fKB  mean=%5.1f  p10=%5.1f  p90=%5.1f' % (
        os.path.basename(dst), os.path.getsize(dst) / 1024, lum.mean(),
        np.percentile(lum, 10), np.percentile(lum, 90)))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('src')
    ap.add_argument('dst')
    ap.add_argument('--offset', type=float, default=0.5)
    ap.add_argument('--blur', type=float, default=16)
    ap.add_argument('--sat', type=float, default=0.92)
    ap.add_argument('--grain', type=float, default=0.008)
    a = ap.parse_args()
    make(a.src, a.dst, a.offset, a.blur, a.sat, a.grain)


if __name__ == '__main__':
    main()
