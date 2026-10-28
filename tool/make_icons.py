# /// script
# 应用图标生成器（M6.1）：把手绘稿 tool/icon_source.png 处理成全平台图标。
#
# 处理链路：
#   1. 色度抠图   —— 用 (R+G)/2-B 把奶油色蜡笔笔触从蓝底上分离，并反解混色，
#                    顺带清掉原图底部的照片暗边；
#   2. alpha 拉伸 —— 压缩半透明雾斑，让笔触在小尺寸下依然实、不发灰；
#   3. 重新构图   —— 压到「深夜蓝」径向渐变底上（替代原图平蓝，提升对比度）；
#   4. 分平台导出 —— Android 传统图标 / 自适应图标（背景+前景分层）/ 圆形 /
#                    iOS 全尺寸 / Web。
#
# 用法：
#   python tool/make_icons.py            # 生成全部图标
#   python tool/make_icons.py --preview  # 额外输出一张多尺寸预览图
# 依赖：Pillow、numpy
# ///
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "tool" / "icon_source.png"
RES = ROOT / "android" / "app" / "src" / "main" / "res"
IOS_ICON_DIR = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
WEB_ICON_DIR = ROOT / "web" / "icons"

# ── 视觉参数 ────────────────────────────────────────────────────────────────
SRC_BG = np.array([107.0, 136.0, 169.0], np.float32)  # 原图底色（用于反解混色）
D_BG, D_INK = -48.5, 16.5          # 色度差锚点：蓝底 / 奶油笔触
LUM_GUARD = (126.0, 20.0)          # 比背景更暗 → 判为背景（照片暗边）
ALPHA_WINDOW = (0.21, 0.57)        # alpha 对比拉伸窗口（去雾斑）

BG_LIGHT = (78, 100, 132)          # 渐变亮部（画面上方偏左）
BG_DARK = (38, 50, 72)             # 渐变暗部（四角）
BG_CENTER = (0.46, 0.40)
VIGNETTE = 0.80

ART_FILL_SQUARE = 0.86             # 方形图标：图形包围盒占画布比例
ART_FILL_ROUND = 0.74              # 圆形图标：圆内完整（实测墨迹最大半径 ≈0.95R）
ART_FILL_ADAPTIVE = 0.74 * 72 / 108  # 自适应：换算到 108dp 画布（可见区仅中央 72dp）
ART_FILL_MASKABLE = 0.56           # Web maskable（需预留 20% 安全边）

# Android 传统图标边长 / 自适应图标 108dp 画布边长
DENSITIES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ADAPTIVE_DENSITIES = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


# ── 1. 抠图 ────────────────────────────────────────────────────────────────
def key_art(img: Image.Image) -> np.ndarray:
    """返回 float32 RGBA（0-255），背景 alpha 已归零。"""
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    chroma = (r + g) / 2.0 - b
    lum = 0.299 * r + 0.587 * g + 0.114 * b

    alpha = np.clip((chroma - D_BG) / (D_INK - D_BG), 0.0, 1.0)
    alpha *= np.clip((lum - LUM_GUARD[0]) / LUM_GUARD[1], 0.0, 1.0)

    # 反解混色 obs = a·ink + (1-a)·bg → ink
    denom = np.clip(alpha, 0.18, 1.0)[:, :, None]
    ink = np.clip(SRC_BG + (a - SRC_BG) / denom, 0.0, 255.0)
    return np.dstack([ink, alpha * 255.0]).astype(np.float32)


def stretch_alpha(rgba: np.ndarray, window: tuple[float, float]) -> np.ndarray:
    lo, hi = window
    alpha = np.clip((rgba[:, :, 3] / 255.0 - lo) / (hi - lo), 0.0, 1.0)
    out = rgba.copy()
    out[:, :, 3] = alpha * 255.0
    return out


def crop_to_content(rgba: np.ndarray, threshold: float = 60.0) -> np.ndarray:
    mask = rgba[:, :, 3] > threshold
    ys, xs = np.where(mask)
    return rgba[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]


# ── 2. 底色 ────────────────────────────────────────────────────────────────
def make_bg(size: int) -> Image.Image:
    """深夜蓝径向渐变 + 细颗粒。"""
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / (size - 1)
    cx, cy = BG_CENTER
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / VIGNETTE
    t = np.clip(dist, 0, 1)[..., None] ** 1.5
    light = np.array(BG_LIGHT, np.float32)
    dark = np.array(BG_DARK, np.float32)
    rgb = light + (dark - light) * t
    grain = np.random.default_rng(7).normal(0.0, 2.0, (size, size, 1))
    rgb = np.clip(rgb + grain, 0, 255).astype(np.uint8)
    return Image.fromarray(rgb).filter(ImageFilter.GaussianBlur(size * 0.005))


# ── 3. 缩放（预乘，避免半透明边缘发灰/发蓝）────────────────────────────────
def premul_scale(rgba: np.ndarray, w: int, h: int) -> Image.Image:
    rgb, alpha = rgba[:, :, :3], rgba[:, :, 3:4] / 255.0
    premul = np.dstack([rgb * alpha, alpha * 255.0]).astype(np.uint8)
    scaled = np.asarray(
        Image.fromarray(premul, "RGBA").resize((w, h), Image.LANCZOS)
    ).astype(np.float32)
    a2 = np.clip(scaled[:, :, 3:4] / 255.0, 1e-6, 1.0)
    rgb2 = np.clip(scaled[:, :, :3] / a2, 0, 255)
    return Image.fromarray(np.dstack([rgb2, scaled[:, :, 3:4]]).astype(np.uint8), "RGBA")


def place(art: np.ndarray, canvas: int, fill: float) -> Image.Image:
    """图形按 fill 比例缩放并居中，返回透明底图层。"""
    h, w = art.shape[:2]
    target = canvas * fill
    scale = target / max(w, h)
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    layer = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    layer.alpha_composite(premul_scale(art, nw, nh), ((canvas - nw) // 2, (canvas - nh) // 2))
    return layer


def flat_icon(art: np.ndarray, canvas: int, fill: float) -> Image.Image:
    bg = make_bg(canvas).convert("RGBA")
    bg.alpha_composite(place(art, canvas, fill))
    return bg


def circular(icon: Image.Image) -> Image.Image:
    s = icon.size[0]
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, s - 1, s - 1), fill=255)
    out = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    out.paste(icon, (0, 0), mask)
    return out


# ── 4. 导出 ────────────────────────────────────────────────────────────────
def save(img: Image.Image, path: Path, size: int, keep_alpha: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    out = img.resize((size, size), Image.LANCZOS)
    if not keep_alpha:
        out = out.convert("RGB")
    out.save(path, optimize=True)
    print(f"  {path.relative_to(ROOT)}  ({size}px)")


def export_android(master: Image.Image, art: np.ndarray) -> None:
    print("Android 传统图标：")
    for density, size in DENSITIES.items():
        d = RES / f"mipmap-{density}"
        save(master, d / "ic_launcher.png", size)
        save(circular(flat_icon(art, 512, ART_FILL_ROUND)), d / "ic_launcher_round.png", size, True)

    print("Android 自适应图标（108dp 画布）：")
    for density, size in ADAPTIVE_DENSITIES.items():
        d = RES / f"mipmap-{density}"
        save(make_bg(size), d / "ic_launcher_bg.png", size)          # 背景满铺渐变
        save(place(art, size, ART_FILL_ADAPTIVE), d / "ic_launcher_fg.png", size, True)


def export_ios(master: Image.Image) -> None:
    contents = IOS_ICON_DIR / "Contents.json"
    meta = json.loads(contents.read_text(encoding="utf-8"))
    count = 0
    for entry in meta.get("images", []):
        name = entry.get("filename")
        if not name:
            continue
        px = round(float(entry["size"].split("x")[0]) * int(entry["scale"].rstrip("x")))
        master.resize((px, px), Image.LANCZOS).convert("RGB").save(
            IOS_ICON_DIR / name, optimize=True
        )
        count += 1
    (IOS_ICON_DIR / "AppIcon-1024.png").write_bytes(
        (IOS_ICON_DIR / "Icon-App-1024x1024@1x.png").read_bytes()
    )
    print(f"iOS AppIcon: {count} 张 → {IOS_ICON_DIR.name}/")


def export_web(master: Image.Image, art: np.ndarray) -> None:
    print("Web 图标：")
    save(master, ROOT / "web" / "favicon.png", 32)
    save(master, WEB_ICON_DIR / "Icon-192.png", 192)
    save(master, WEB_ICON_DIR / "Icon-512.png", 512)
    maskable = flat_icon(art, 512, ART_FILL_MASKABLE)
    save(maskable, WEB_ICON_DIR / "Icon-maskable-192.png", 192)
    save(maskable, WEB_ICON_DIR / "Icon-maskable-512.png", 512)


def preview(master: Image.Image, art: np.ndarray) -> Path:
    """多尺寸 + 圆形遮罩预览，便于人工验收。"""
    out = ROOT / "tool" / "_icon_preview.png"
    cell = 190
    cols = 5
    sheet = Image.new("RGB", (cell * cols + 20, cell + 40), (236, 238, 242))
    sheet.paste(master.resize((cell - 10, cell - 10), Image.LANCZOS), (10, 10))
    for i, px in enumerate((192, 96, 48), start=1):
        tile = master.resize((px, px), Image.LANCZOS)
        sheet.paste(tile, (10 + i * cell + (cell - 10 - px) // 2, 10 + (cell - 10 - px) // 2))
    disc = circular(flat_icon(art, 512, ART_FILL_ROUND)).resize((cell - 10, cell - 10), Image.LANCZOS)
    sheet.paste(disc, (10 + 4 * cell, 10), disc)
    sheet.save(out)
    return out


def check_safe_circle(art: np.ndarray) -> None:
    """圆形遮罩安全区自检：墨迹最大半径须留在圆内（自适应按同一构图换算）。"""
    size = 1024
    flat = np.asarray(flat_icon(art, size, ART_FILL_ROUND).convert("L")).astype(float)
    yy, xx = np.mgrid[0:size, 0:size]
    radius = np.hypot(xx - (size - 1) / 2, yy - (size - 1) / 2) / ((size - 1) / 2)
    r = float(radius[flat > 150].max())
    flag = "OK" if r <= 0.99 else "越界，请调小 ART_FILL_ROUND"
    print(f"圆形安全区自检：墨迹最大半径 {r:.2f}R  {flag}")


def main() -> None:
    if not SRC.exists():
        sys.exit(f"源图缺失: {SRC}")
    art = crop_to_content(stretch_alpha(key_art(Image.open(SRC)), ALPHA_WINDOW))
    master = flat_icon(art, 1024, ART_FILL_SQUARE)
    print(f"笔触层 {art.shape[1]}x{art.shape[0]} → 主稿 1024x1024")
    check_safe_circle(art)
    print()

    export_android(master, art)
    export_ios(master)
    export_web(master, art)

    if "--preview" in sys.argv:
        print(f"预览: {preview(master, art).relative_to(ROOT)}")
    print("done")


if __name__ == "__main__":
    main()
