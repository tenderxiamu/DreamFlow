# -*- coding: utf-8 -*-
"""DreamFlow 字体子集化 v2。

背景（M6.8 实测）：上一版子集只有 318 个汉字，而 lib/ 实际用到 977 个汉字，
缺 680 个（含「想 / 能 / 很 / 大 / 太 / 真 / 会 / 做」等高频字）。Flutter 遇到
cmap 里没有的字会逐字回退到系统字体，于是同一段话里一部分字是楷体、一部分是
系统黑体，字面高度与字重都不一致 —— 用户看到的就是「字号忽大忽小」。

v2 策略：
1. 字符集 = 源码全部字符 + GB2312 一级汉字（3755）+ 中文标点 + ASCII
2. 毛笔体（MaShanZheng）保留全字集子集，用于标题 / 大数字，覆盖源码零缺字
3. 正文不再打包楷体：正文与动态文本一律走系统字体栈（见 df_type.dart），
   平台自带 CJK 字体 100% 覆盖，LLM 输出任何生僻字都不会掉字
4. 子集完成后自动校验：源码汉字必须零缺失，否则脚本失败

源字体（全量）放在 tool/fonts_src/，不入库（约 30 MiB）。
下载：
  MaShanZheng  https://github.com/google/fonts/raw/main/ofl/mashanzheng/MaShanZheng-Regular.ttf
  Cormorant     https://github.com/google/fonts/raw/main/ofl/cormorantgaramond/CormorantGaramond%5Bwght%5D.ttf
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent          # dreamflow_flutter/
SRC = ROOT / "tool" / "fonts_src"
FONTS = ROOT / "assets" / "fonts"
VENV_PY = Path(r"C:\Users\29718\.workbuddy\binaries\python\envs\default\Scripts\python.exe")

CJK_PUNCT = "，。、；：？！“”‘’（）《》〈〉【】〔〕—…·～×÷％＋－＝｜℃　"
EXTRA = "①②③④⑤⑥⑦⑧⑨⑩←→↑↓√×÷°′″€$¥"

# (源文件, 输出文件, 是否含中文)
FONTS_SPEC = [
    ("MaShanZheng-Regular.ttf", "MaShanZheng-Regular.ttf", True),
    ("CormorantGaramond.ttf", "CormorantGaramond.ttf", False),
]


def source_hanzi() -> set:
    """lib/ 与 test/ 中出现的全部汉字（含注释外的一切字符，宁多勿少）。"""
    out = set()
    for sub in ("lib", "test"):
        d = ROOT / sub
        if not d.exists():
            continue
        for p in d.rglob("*.dart"):
            for ch in p.read_text(encoding="utf-8", errors="ignore"):
                if 0x4E00 <= ord(ch) <= 0x9FFF:
                    out.add(ch)
    return out


def gb2312_level1() -> set:
    """GB2312 一级汉字 3755 个（日常表达覆盖 99.5%+）。"""
    out = set()
    for b1 in range(0xB0, 0xD8):
        for b2 in range(0xA1, 0xFF):
            try:
                out.add(bytes([b1, b2]).decode("gb2312"))
            except UnicodeDecodeError:
                pass
    return out


def main() -> int:
    if not VENV_PY.exists():
        print(f"[!!] venv 不存在: {VENV_PY}")
        return 1

    used = source_hanzi()
    print(f"源码汉字：{len(used)} 种")

    for src_name, dst_name, with_cjk in FONTS_SPEC:
        sp = SRC / src_name
        dp = FONTS / dst_name
        if not sp.exists():
            print(f"[!!] 缺源字体 {sp}")
            return 1

        text = set(chr(c) for c in range(0x20, 0x7F)) | set(CJK_PUNCT) | set(EXTRA)
        if with_cjk:
            text |= used
            text |= gb2312_level1()
        text.discard("\n")
        text.discard("\t")
        text.discard("\r")

        cmd = [
            str(VENV_PY), "-m", "fontTools.subset", str(sp),
            "--text=" + "".join(sorted(text)),
            "--layout-features=*",
            "--flavor=",
            "--output-file=" + str(dp),
            "--no-hinting",
            "--desubroutinize",
            "--drop-tables+=DSIG",
        ]
        r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="ignore")
        if r.returncode != 0:
            print(f"[!!] {src_name} 子集化失败:\n{(r.stderr or '')[:600]}")
            return 1
        so, sn = sp.stat().st_size, dp.stat().st_size
        print(f"[OK] {dst_name:34s} {so/1048576:6.2f} MiB → {sn/1048576:6.2f} MiB "
              f"({sn/so*100:5.1f}%)  字符 {len(text)}")

    # ── 校验：源码汉字必须零缺失 ─────────────────────────────────────────
    import importlib.util
    spec = importlib.util.spec_from_file_location("ttf_cmap", ROOT / "tool" / "ttf_cmap.py")
    if spec and spec.loader:
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        data, tables = mod.read_tables(str(FONTS / "MaShanZheng-Regular.ttf"))
        have = mod.cmap_codepoints(data, tables)
        miss = sorted(c for c in used if ord(c) not in have)
        if miss:
            print(f"[!!] MaShanZheng 仍缺 {len(miss)} 字：{''.join(miss)}")
            return 1
        print(f"[OK] 校验通过：源码 {len(used)} 个汉字在 MaShanZheng 子集中零缺失")
    return 0


if __name__ == "__main__":
    sys.exit(main())
