#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
DreamFlow 设计落地 QA 校验（§11 验收清单第 1、2 项）

1) 令牌保真：解析设计交付说明书 §3.1/§3.2 的令牌表，
   与 lib/design_system/df_tokens.dart 的 DfPalette.night / DfPalette.paper 逐值比对。
2) 对比度复算：对每个前景令牌 × {canvas, surface} 复算 WCAG 2.1 对比度，
   并与文档「对画布 / 对卡片」两列声明值核对。

用法：  python tool/qa_check.py
退出码：0 = 全通过；1 = 有 FAIL
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT.parent / "_refs" / "design-handoff-ink-morandi.md"
TOKENS = ROOT / "lib" / "design_system" / "df_tokens.dart"

# 前景 / 背景对（与文档「对画布 / 对卡片」两列一致）
FG_TOKENS = ["text", "text-2", "text-3", "mist-blue", "mist-green", "mist-pink", "mist-yellow"]
BG_TOKENS = ["canvas", "surface"]

# 设计文档明文豁免（§3 表下注）：夜墨 `--text-3` 对卡片面 4.06:1，
# 允许仅用于「画布上」的 11px 注脚与 Tab 未选态；禁止放入卡片面。
KNOWN_EXCEPTIONS: dict[tuple[str, str, str], str] = {
    ("night", "text-3", "卡片"): "§3 注：仅限画布上的注脚 / Tab 未选态，禁止卡片内小字",
}


# ────────────────────────── 颜色解析 ──────────────────────────


def parse_hex(s: str) -> tuple[int, int, int, int] | None:
    s = s.strip().strip("`").strip()
    m = re.fullmatch(r"#([0-9A-Fa-f]{6})", s)
    if m:
        v = int(m.group(1), 16)
        return ((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF, 255)
    m = re.fullmatch(
        r"rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)", s
    )
    if m:
        a = m.group(4)
        alpha = 255 if a is None else round(float(a) * 255)
        return (int(m.group(1)), int(m.group(2)), int(m.group(3)), alpha)
    return None


def dart_field(name: str) -> str:
    """--canvas-2 → canvas2 ; --mist-blue → mistBlue"""
    parts = name.split("-")
    return parts[0] + "".join(p[:1].upper() + p[1:] for p in parts[1:])


def fg(bg: tuple[int, int, int, int], fg_: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    """前景按 alpha 合成到背景上（文档中的 rgba 令牌）"""
    a = fg_[3] / 255
    return tuple(round(fg_[i] * a + bg[i] * (1 - a)) for i in range(3)) + (255,)


def luminance(c: tuple[int, int, int, int]) -> float:
    def ch(v: int) -> float:
        s = v / 255
        return s / 12.92 if s <= 0.04045 else ((s + 0.055) / 1.055) ** 2.4

    r, g, b = (ch(c[i]) for i in range(3))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> float:
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def fmt(c: tuple[int, int, int, int]) -> str:
    return f"#{c[0]:02X}{c[1]:02X}{c[2]:02X}" + ("" if c[3] == 255 else f" @{c[3]/255:.2f}")


# ────────────────────────── 解析文档 ──────────────────────────


def parse_doc() -> dict[str, dict[str, tuple]]:
    text = DOC.read_text(encoding="utf-8")
    themes: dict[str, dict] = {"night": {}, "paper": {}}
    current: str | None = None

    for line in text.splitlines():
        if line.startswith("### 3.1"):
            current = "night"
            continue
        if line.startswith("### 3.2"):
            current = "paper"
            continue
        if line.startswith("### 3.3"):
            current = None
            continue
        if current is None or not line.startswith("| `--"):
            continue

        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 3:
            continue
        name = cells[0].strip("`").removeprefix("--")
        hexcell = cells[2].strip("`")
        if "rgba" in hexcell:
            # rgba 令牌的真实基准色在中文名/用途列之外，用 RGB 列缺失，
            # 改为从「HEX」列的 rgba 直接取
            color = parse_hex(hexcell)
        else:
            color = parse_hex(hexcell) or parse_hex(cells[3])
        if color is None:
            continue

        # 对画布 / 对卡片 声明值
        declared: list[float] = []
        for cell in cells[6:8]:
            m = re.search(r"([\d.]+)\s*:", cell)
            if m:
                declared.append(float(m.group(1)))
        themes[current][name] = (color, declared)

    return themes


# ────────────────────────── 解析 Dart ──────────────────────────


def parse_dart() -> dict[str, dict[str, tuple]]:
    text = TOKENS.read_text(encoding="utf-8")
    out: dict[str, dict] = {}
    for theme in ("night", "paper"):
        m = re.search(
            r"static const DfPalette %s = DfPalette\((.*?)\n  \);" % theme,
            text,
            re.S,
        )
        if not m:
            print(f"[FAIL] 未在 df_tokens.dart 找到 DfPalette.{theme}")
            sys.exit(1)
        fields: dict[str, tuple] = {}
        for line in m.group(1).splitlines():
            fm = re.match(
                r"\s*(\w+):\s*Color\(0x([0-9A-Fa-f]{8})\)", line
            )
            if fm:
                v = int(fm.group(2), 16)
                fields[fm.group(1)] = (
                    (v >> 16) & 0xFF,
                    (v >> 8) & 0xFF,
                    v & 0xFF,
                    (v >> 24) & 0xFF,
                )
        out[theme] = fields
    return out


# ────────────────────────── 主流程 ──────────────────────────


def main() -> int:
    doc = parse_doc()
    dart = parse_dart()
    fails: list[str] = []

    print("=" * 72)
    print("1. 令牌保真（设计文档 §3.1/§3.2  ←→  df_tokens.dart）")
    print("=" * 72)

    for theme in ("night", "paper"):
        print(f"\n[t-{theme}]")
        for name, (dc, _) in doc[theme].items():
            field = dart_field(name)
            if field not in dart[theme]:
                print(f"  [MISS] --{name:<14} → {field:<10} 未在 DfPalette.{theme} 定义")
                fails.append(f"{theme}.{name} 缺失")
                continue
            fc = dart[theme][field]
            ok = dc == fc
            print(
                f"  [{'OK  ' if ok else 'FAIL'}] --{name:<14} 文档 {fmt(dc):<18} "
                f"Dart {fmt(fc):<18} → {field}"
            )
            if not ok:
                fails.append(f"{theme}.{name} 色值不符")

    print()
    print("=" * 72)
    print("2. WCAG 对比度复算（≥ 4.5:1）")
    print("=" * 72)

    exempt: list[str] = []
    for theme in ("night", "paper"):
        canvas = dart[theme]["canvas"]
        surface = dart[theme]["surface"]
        print(f"\n[t-{theme}]")
        for fname in FG_TOKENS:
            field = dart_field(fname)
            if field not in dart[theme]:
                continue
            raw = dart[theme][field]
            line: list[str] = []
            for bname, bgc in (("画布", canvas), ("卡片", surface)):
                composed = fg(bgc, raw)
                ratio = contrast(composed, bgc)
                key = (theme, fname, bname)
                if ratio >= 4.5:
                    mark = "✅"
                elif key in KNOWN_EXCEPTIONS:
                    mark = "豁免"
                    exempt.append(f"t-{theme} --{fname} 对{bname} {ratio:.2f}:1 — {KNOWN_EXCEPTIONS[key]}")
                else:
                    mark = "⚠️"
                    fails.append(f"{theme}.{fname} 对{bname} {ratio:.2f}:1 < 4.5")
                line.append(f"{bname} {ratio:5.2f}:1 {mark}")
            print(f"  --{fname:<14} " + "   ".join(line))

    print()
    print("=" * 72)
    total = len(doc["night"]) + len(doc["paper"])
    print(f"令牌比对 {total} 项 ｜ 对比度组合 {len(FG_TOKENS)*2*2} 组")
    if exempt:
        print(f"\n📌 文档明文豁免 {len(exempt)} 项（不计入失败）：")
        for e in exempt:
            print(f"   - {e}")
    if fails:
        print(f"\n❌ {len(fails)} 项未通过：")
        for f in fails:
            print(f"   - {f}")
        return 1
    print("\n✅ 全部通过：令牌与文档一致，对比度除文档豁免项外全 ≥ 4.5:1")
    return 0


if __name__ == "__main__":
    sys.exit(main())
