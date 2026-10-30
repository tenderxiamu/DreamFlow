"""把「梦洄」宣传插画上的文字修掉，做成首页 Hero 卡片素材。

原图 1440×1079，首页卡片在 3x 屏上几乎 1:1 展示 —— 手抹的糊块一眼就能看见，
所以只能算，不能涂。要修的是六处：Dream / flow / 你的专属睡眠专家 / 竖排「梦洄」
/ 小生物旁的 Zzz / 两个角上的淡水印。

思路来自这张图的一个事实：**天空的高频能量极低**（`图 - 模糊(σ=9)` 标准差只有 3），
几乎全是柔和渐变。所以不用"贴一块别处的云"（那会带进对不上的云），
把字底下的颜色补出来、再撒同强度的颗粒就够了。

三个层次，缺一不可：

1. **蒙版**：深字按绝对暗阈值（L<105）、浅字按绝对亮阈值、Zzz 按「亮且偏冷」
   （Z 是冷白，小生物的耳朵和云是暖白，色相能把它们分开）、角上的水印分不开
   就整框补。宁可多圈一圈 —— 多填的都是天空，少填反而留笔画毛边。
2. **天空**：模糊→贴回已知像素，迭代 40 次，颜色从边界慢慢渗进空洞。
   **不能改用"最近的已知像素"**：浅色字的蒙版总有漏网的亮点，它们又成了供体，
   会把字越糊越大（试过：补完出两个浅色方块）。
3. **月亮**：内缘是一段圆弧（拟合残差中位 3~4px），字压上去会把边界拉扯成折线。
   所以先把整条弧拟合出来，再按 r 与该半径的关系判亮/暗、填本地平均色。
   这一步必须放在扩散**之后** —— 扩散会从亮面往左糊 20 多像素，月牙就没了。

最后补一层"笔刷纹理"（~15px 团块 + 细颗粒），否则补出来的区域太平，
高通图上一眼能看出补丁边界。

用法：
    python tool/make_poster.py <src> <dst> [--iters 40] [--passes 3] [--debug]
"""
from __future__ import annotations

import argparse
import os

import cv2
import numpy as np

# (x1, y1, x2, y2, kind, delta)
#   dark  = L < 105（黑字）
#   light = L > delta（浅灰字，天空和字之间有明显空隙）
#   glyph = L > delta 且偏冷（Zzz，用它才不会连小生物的耳朵一起削掉）
#   box   = 整框补（角上水印，和云的起伏分不开）
REGIONS = [
    (355, 50, 815, 262, 'dark', 0),      # Dream
    (500, 246, 812, 420, 'dark', 0),     # flow
    (0, 598, 822, 732, 'dark', 0),       # 你的专属睡眠专家
    (848, 78, 978, 295, 'light', 150),   # 竖排「梦洄」：天空 96~144，字 150~208
    # Zzz：不能用「整框补」—— 框会连小生物右边那只小耳朵一起削掉（试过）。
    # 用「亮且偏冷」双重条件：Z 是冷白（R−B ≈ −14），耳朵和云是暖白（+6 / +18）
    (1056, 522, 1186, 726, 'glyph', 165),
    # 角上的水印只比天空亮 7~12，跟云的起伏完全混在一起，阈值分不开 ——
    # 干脆整块框补（那块本来就是一整片平缓的暗角，扩散补出来看不出）
    (0, 0, 345, 132, 'box', 0),
    (1025, 0, 1440, 140, 'box', 0),
]

DARK_THR = 105
DILATE = 9
FEATHER = 2.0
GRAIN = 1.6
BLOB = 3.0
SIGMA = 6.0


def imread(path: str) -> np.ndarray:
    """cv2.imread 在 Windows 上不认中文路径（返回 None），绕道 imdecode"""
    buf = np.fromfile(path, dtype=np.uint8)
    img = cv2.imdecode(buf, cv2.IMREAD_COLOR)
    if img is None:
        raise SystemExit(f'读不到 {path}')
    return img


def imwrite(path: str, img: np.ndarray, quality: int = 94) -> None:
    ext = os.path.splitext(path)[1] or '.jpg'
    params = [] if ext.lower() == '.png' else [int(cv2.IMWRITE_JPEG_QUALITY), quality]
    ok, buf = cv2.imencode(ext, img, params)
    if not ok:
        raise SystemExit(f'编码失败 {path}')
    buf.tofile(path)


def build_mask(img: np.ndarray, debug: bool = False) -> np.ndarray:
    l = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY).astype(np.float32)
    h, w = l.shape
    out = np.zeros((h, w), np.uint8)
    for x1, y1, x2, y2, kind, delta in REGIONS:
        box = l[y1:y2, x1:x2]
        if kind == 'box':
            m = np.full(box.shape, 255, np.uint8)
        elif kind == 'glyph':
            rgb = img[y1:y2, x1:x2].astype(np.int16)
            warm = rgb[..., 2] - rgb[..., 0]          # R - B（BGR 顺序）
            m = ((box > delta) & (warm < 0)).astype(np.uint8) * 255
        elif kind == 'light':
            m = (box > delta).astype(np.uint8) * 255
        else:
            m = (box < DARK_THR).astype(np.uint8) * 255
        out[y1:y2, x1:x2] = m
        if debug:
            print(f'  {kind:5s} ({x1},{y1},{x2},{y2}) d={delta} -> {int((m > 0).sum())} px')
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (DILATE, DILATE))
    out = cv2.morphologyEx(out, cv2.MORPH_CLOSE, k)
    out = cv2.dilate(out, k)
    return out


def nearest_source(img: np.ndarray, mask: np.ndarray, source: np.ndarray) -> np.ndarray:
    """把 [source] 里离它最近的像素颜色抄给每个空洞像素

    硬边界（月牙）能顺着延伸进来，比模糊扩散强 —— 扩散会把月牙边缘糊成一团。

    注意 distanceTransformWithLabels 的约定：它算的是「每个非零像素到最近的零像素」，
    所以要把**供体当零**传进去（`1 - source`），标签才指向供体；
    传反了拿到的是一堆无意义下标，补出来的块颜色是乱的。
    """
    inv = (source == 0).astype(np.uint8)
    _, labels = cv2.distanceTransformWithLabels(
        inv, cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL
    )
    ys, xs = np.where(inv == 0)
    lut = np.zeros(int(labels.max()) + 1, dtype=np.int32)
    lut[labels[ys, xs]] = np.arange(ys.size, dtype=np.int32) + 1
    cy, cx = np.where(mask > 0)
    idx = lut[labels[cy, cx]] - 1
    out = img.astype(np.float32).copy()
    out[cy, cx] = img[ys[idx], xs[idx]]
    return out


def fit_inner_arc(l: np.ndarray, split: int = 155) -> tuple[float, float, float]:
    """把月牙内缘拟合成一段圆弧，返回 (cx, cy, r)

    逐行找「从左边第一次变亮」的位置得到内缘点；字压在边上那几行会偏，
    所以迭代剔除离群点再拟合。残差中位数 3~4px —— 这条边确实就是一段圆弧。
    """
    pts = []
    h = l.shape[0]
    for y in range(70, min(540, h), 2):
        xs = np.where(l[y, 470:880] > split)[0]
        if xs.size:
            pts.append((xs[0] + 470.0, float(y)))
    pts = np.array(pts, float)
    if len(pts) < 12:
        return (0.0, 0.0, 0.0)

    keep = np.ones(len(pts), bool)
    cx = cy = r = 0.0
    for _ in range(8):
        p = pts[keep]
        a = np.c_[2 * p[:, 0], 2 * p[:, 1], np.ones(len(p))]
        sol, *_ = np.linalg.lstsq(a, (p ** 2).sum(1), rcond=None)
        cx, cy = sol[0], sol[1]
        r = float(np.sqrt(max(sol[2] + cx ** 2 + cy ** 2, 0)))
        d = np.abs(np.hypot(pts[:, 0] - cx, pts[:, 1] - cy) - r)
        keep = d < max(8.0, float(np.percentile(d, 80)))
    return (cx, cy, r)


def moon_repair(img: np.ndarray, mask: np.ndarray, base: np.ndarray,
                split: int = 155) -> tuple[np.ndarray, np.ndarray]:
    """月亮上的字：用拟合出的圆弧定形状

    为什么必须定形状：这条内缘是一段圆弧，字压在上面时每个笔画都会把边界
    往外拉一块，按最近像素抄出来的边就是一格一格的折线。既然它是圆弧，
    干脆把整条弧拟合出来，边界按 r 和 R 的关系判 —— 天生光滑。

    注意这里是**权重**而不是二值蒙版：修补区是用"亮面平均色"填的，那一片比
    月亮本身平，二值贴回去会在边界上留一圈方块边；权重往外羽化 12px 就看不出来了。
    """
    l = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY).astype(np.float32)
    hard = (mask > 0).astype(np.float32)
    cx, cy, r = fit_inner_arc(l, split)
    if r <= 0:
        return base, hard

    h, w = l.shape
    yy, xx = np.mgrid[0:h, 0:w]
    rr = np.hypot(xx - cx, yy - cy)

    # 只认月亮那一块亮面（画面里最大的亮连通域）。
    # 不能拿"所有亮像素"当月亮：梦洄 / Zzz 也是亮像素，而且都落在弧线外侧，
    # 会被判成"月亮的亮面"，于是补出一大块月白色的方块（试过，很明显）。
    lit_all = l > split
    n, lab, stats, _ = cv2.connectedComponentsWithStats(lit_all.astype(np.uint8), 8)
    if n < 2:
        return base, hard
    area = stats[1:, cv2.CC_STAT_AREA]
    lit = lab == (int(np.argmax(area)) + 1)
    near = cv2.dilate((lit * 255).astype(np.uint8),
                      cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (61, 61))) > 0

    arc_lit = rr > r
    # 权重 1：字盖住的地方
    weight = hard * near
    # 权重 2：字旁边、原图和圆弧说法不一致的那一段（被笔画拉扯歪的边），羽化过渡
    fade = np.clip(cv2.GaussianBlur(hard, (0, 0), 12) * 2.2, 0, 1)
    weight = np.maximum(weight, fade * (lit != arc_lit) * near)
    if weight.max() <= 0:
        return base, hard

    # 亮面：本地亮像素的平均色（跟着月亮自身的明暗走）
    wk = 25
    wb = lit.astype(np.float32)
    nb = cv2.blur(wb, (wk, wk))
    bright = cv2.blur(img * wb[..., None], (wk, wk)) / np.maximum(nb, 1e-3)[..., None]
    bright = np.where((nb > 0.05)[..., None], bright, base)
    # 暗面：最近像素会在空洞中间对出一圈"花瓣"接缝，所以再重模糊一次抹平
    #（暗面本来就没什么细节，模糊不会丢东西）
    dark = cv2.GaussianBlur(
        nearest_source(img, weight > 0, (~lit) & (mask == 0)), (0, 0), 9)

    # 弧线两侧 3px 内做软过渡，避免硬边
    alpha = np.clip((rr - r) / 3.0 + 0.5, 0.0, 1.0)[..., None]
    patch = bright * alpha + dark * (1 - alpha)
    out = base * (1 - weight[..., None]) + patch * weight[..., None]
    return out, weight


def diffuse(img: np.ndarray, known_px: np.ndarray, iters: int) -> np.ndarray:
    """模糊→把已知像素贴回去，反复迭代：颜色从边界慢慢渗进空洞"""
    h, w = img.shape[:2]
    small = cv2.resize(img, (w // 2, h // 2), interpolation=cv2.INTER_AREA)
    k = cv2.resize(known_px, (w // 2, h // 2), interpolation=cv2.INTER_NEAREST)
    x = small.copy()
    for _ in range(iters):
        x = cv2.GaussianBlur(x, (0, 0), SIGMA)
        x[k] = small[k]
    return cv2.resize(x, (w, h), interpolation=cv2.INTER_CUBIC)


def brush_texture(shape: tuple[int, int], rng: np.random.Generator) -> np.ndarray:
    """补出来的区域不能"太干净"

    填完之后色是对的，但整片平得像塑料 —— 高通图上一眼就能看出边界，
    因为周围有笔刷颗粒、这里没有。所以补两层：
    - 大一点的团块（~15px，放大自低频噪声）：像笔刷的起伏
    - 很细的颗粒：打散 JPEG 色带
    两层都是零均值，只加纹理不改颜色。
    """
    h, w = shape
    coarse = rng.normal(0, 1, (h // 15 + 2, w // 15 + 2)).astype(np.float32)
    blob = cv2.resize(coarse, (w, h), interpolation=cv2.INTER_CUBIC)
    blob = cv2.GaussianBlur(blob, (0, 0), 2.0)
    blob /= max(float(blob.std()), 1e-6)
    fine = rng.normal(0, 1, shape).astype(np.float32)
    fine = cv2.GaussianBlur(fine, (0, 0), 0.8)
    fine /= max(float(fine.std()), 1e-6)
    return (blob * BLOB + fine * GRAIN)[..., None]


def remove(img: np.ndarray, rng: np.random.Generator, iters: int) -> np.ndarray:
    mask = build_mask(img)

    # 1) 天空：扩散填充
    #   —— 这里**不能用"最近的已知像素"**：浅色字（梦洄 / Zzz / 水印）的蒙版是按
    #   对比度取的，笔画总有没盖住的一点，那些亮点又成了供体，把字越糊越大
    #   （真机试过：补完出两个浅色方块）。扩散只从蒙版边界取值，不会自产自销。
    low = diffuse(img, (mask == 0), iters) if iters else img.astype(np.float32)
    low[mask == 0] = img[mask == 0]

    # 2) 月亮：**放在扩散之后**。月牙边缘是硬边界，扩散会把它往左边糊过去
    low, moon_w = moon_repair(img, mask, low)

    # 3) 贴回：动过的地方整块换，边界外羽化过渡（月亮的权重自己带渐变）
    ch = (mask > 0).astype(np.float32)
    feath = np.clip(cv2.GaussianBlur(ch, (0, 0), FEATHER), 0, 1)
    feath = np.maximum(feath, ch)
    if moon_w.max() > 0:
        lunar = moon_w / max(float(moon_w.max()), 1e-6)
        feath = np.maximum(feath, lunar)
    feath = feath[..., None]

    filled = np.clip(low + brush_texture(img.shape[:2], rng), 0, 255)

    return np.clip(img.astype(np.float32) * (1 - feath) + filled * feath, 0, 255).astype(np.uint8)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('src')
    ap.add_argument('dst')
    ap.add_argument('--iters', type=int, default=40)
    ap.add_argument('--passes', type=int, default=3)
    ap.add_argument('--debug', action='store_true')
    a = ap.parse_args()

    img = imread(a.src)
    print(f'源图 {img.shape[1]}x{img.shape[0]}')
    if a.debug:
        print('蒙版:')
        build_mask(img, debug=True)

    rng = np.random.default_rng(20261028)
    out = img
    for i in range(a.passes):
        out = remove(out, rng, a.iters)
        print(f'  第 {i + 1} 遍完成')

    os.makedirs(os.path.dirname(os.path.abspath(a.dst)), exist_ok=True)
    imwrite(a.dst, out)
    print(f'写出 {a.dst}')

    if a.debug:
        m = build_mask(out)
        print(f'第二遍仍会命中的像素（越少越好）: {int((m > 0).sum())}')


if __name__ == '__main__':
    main()
