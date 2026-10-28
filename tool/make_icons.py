# /// script
# M6：生成应用图标（Android 全密度 mipmap + 自适应图标 + iOS AppIcon 1024）。
# 视觉：夜墨渐变底 + 雾粉月晕 + 马善政体「梦」字（宣纸白），对应设计 §5 夜墨令牌。
# 用法：python tool/make_icons.py
# ///
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android" / "app" / "src" / "main" / "res"
FONT = ROOT / "assets" / "fonts" / "MaShanZheng-Regular.ttf"
IOS_ICON_DIR = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"

# 夜墨令牌（df_tokens.dart）
BG_TOP = (28, 31, 36)  # surface2 #1C1F24
BG_BOTTOM = (15, 17, 20)  # canvas2 #0F1114
INK_TEXT = (242, 240, 234)  # text #F2F0EA
MIST_PINK = (212, 176, 172)  # mistPink #D4B0AC
MIST_GREEN = (176, 184, 168)  # mistGreen #B0B8A8

DENSITIES = {  # mipmap → 边长
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}
ADAPTIVE_DENSITIES = {  # 自适应图标画布 108dp
    "mdpi": 108,
    "hdpi": 162,
    "xhdpi": 216,
    "xxhdpi": 324,
    "xxxhdpi": 432,
}
MASTER = 1024
GLYPH = "梦"


def draw_background(size: int) -> Image.Image:
    """夜墨纵向渐变底 + 中心微光。"""
    bg = Image.new("RGB", (size, size))
    top, bottom = BG_TOP, BG_BOTTOM
    for y in range(size):
        t = y / (size - 1)
        row = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for_x = Image.new("RGB", (size, 1), row)
        bg.paste(for_x, (0, y))
    return bg


def draw_moon(size: int) -> Image.Image:
    """右上角雾粉月晕（多层高斯模糊，柔和不抢主体）。"""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy, r = int(size * 0.74), int(size * 0.26), int(size * 0.11)
    for radius, alpha in ((r * 2.1, 28), (r * 1.4, 46), (r, 90)):
        halo = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        ImageDraw.Draw(halo).ellipse(
            (cx - radius, cy - radius, cx + radius, cy + radius),
            fill=MIST_PINK + (alpha,),
        )
        halo = halo.filter(ImageFilter.GaussianBlur(size * 0.03))
        layer = Image.alpha_composite(layer, halo)
    # 月牙：实心圆减去偏移圆（用 L 通道蒙版，避免 RGBA 无法擦除）
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    md.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    off_x, off_y = int(r * 0.52), -int(r * 0.34)
    md.ellipse(
        (cx - r + off_x, cy - r + off_y, cx + r + off_x, cy + r + off_y),
        fill=0,
    )
    moon = Image.new("RGBA", (size, size), MIST_PINK + (235,))
    layer.paste(moon, (0, 0), mask)
    return layer


def glyph_layer(size: int, glyph_ratio: float) -> Image.Image:
    """「梦」字层。glyph_ratio = 字高 / 画布。"""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    font_size = int(size * glyph_ratio)
    font = ImageFont.truetype(str(FONT), font_size)
    d = ImageDraw.Draw(layer)
    left, top, right, bottom = d.textbbox((0, 0), GLYPH, font=font)
    w, h = right - left, bottom - top
    x = (size - w) // 2 - left
    y = (size - h) // 2 - top - int(size * 0.01)
    # 雾绿微投影，柔化边缘
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text((x + size * 0.006, y + size * 0.008), GLYPH,
                                font=font, fill=MIST_GREEN + (60,))
    shadow = shadow.filter(ImageFilter.GaussianBlur(size * 0.01))
    layer = Image.alpha_composite(layer, shadow)
    d = ImageDraw.Draw(layer)
    d.text((x, y), GLYPH, font=font, fill=INK_TEXT + (255,))
    return layer


def make_master(with_bg: bool = True) -> Image.Image:
    if with_bg:
        img = draw_background(MASTER).convert("RGBA")
    else:
        img = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
    img = Image.alpha_composite(img, draw_moon(MASTER))
    img = Image.alpha_composite(img, glyph_layer(MASTER, 0.52 if with_bg else 0.42))
    return img.convert("RGB")


def save_scaled(img: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(path, optimize=True)
    print(f"  {path.relative_to(ROOT)}  ({size}x{size})")


def main() -> None:
    assert FONT.exists(), f"字体缺失: {FONT}"
    master = make_master(with_bg=True)
    fg_master = make_master(with_bg=False)  # 自适应前景（透明底）

    print("常规启动图标：")
    for density, size in DENSITIES.items():
        d = RES / f"mipmap-{density}"
        save_scaled(master, d / "ic_launcher.png", size)
        save_scaled(master, d / "ic_launcher_round.png", size)

    print("自适应图标前景（108dp 画布，安全区 66dp）：")
    for density, size in ADAPTIVE_DENSITIES.items():
        save_scaled(fg_master, RES / f"mipmap-{density}" / "ic_launcher_fg.png", size)

    # iOS AppIcon：按 Contents.json 里声明的全部文件名逐尺寸重绘
    import json

    ios_done = 0
    contents = IOS_ICON_DIR / "Contents.json"
    if contents.exists():
        meta = json.loads(contents.read_text(encoding="utf-8"))
        for entry in meta.get("images", []):
            name = entry.get("filename")
            if not name:
                continue
            size_pt = float(entry["size"].split("x")[0])
            scale = int(entry["scale"].rstrip("x"))
            px = round(size_pt * scale)
            master.resize((px, px), Image.LANCZOS).save(
                IOS_ICON_DIR / name, optimize=True
            )
            ios_done += 1
    else:  # 无清单时兜底单图
        master.save(IOS_ICON_DIR / "AppIcon-1024.png", optimize=True)
        ios_done = 1
    print(f"  iOS AppIcon: {ios_done} 张 -> {IOS_ICON_DIR.name}/")

    print("done")


if __name__ == "__main__":
    main()
