# -*- coding: utf-8 -*-
"""DreamFlow 字体子集化：按项目实际文案 + 常用字符收缩三套 OFL 字体。

产出 assets/fonts/*-Subset.ttf，替换原文件；字符集保证：
1. lib/ 全部 .dart 源码中出现的字符串字面量字符（现有文案零缺字）
2. ASCII 可打印区 + 常用中文标点 + 全角数字
3. 常用汉字补充（设计文档高频字），防后续小改文案缺字
"""
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # dreamflow_flutter/
FONTS = ROOT / "assets" / "fonts"
VENV_PY = Path(r"C:\Users\29718\.workbuddy\binaries\python\envs\default\Scripts\python.exe")

FONTS_SPEC = [
    # (原文件, 输出文件, 是否含中文字符集)
    ("MaShanZheng-Regular.ttf", "MaShanZheng-Subset.ttf", True),
    ("LXGWWenKai-Regular.ttf", "LXGWWenKai-Subset.ttf", True),
    ("CormorantGaramond.ttf", "CormorantGaramond-Subset.ttf", False),
]

# 常用中文标点 + 全角符号
CJK_PUNCT = "，。、；：？！“”‘’（）《》〈〉【】—…·～×÷％＋－＝｜℃ 　"

# 补充常用汉字（覆盖睡眠/情绪/时间/界面高频字，防新文案缺字）
COMMON_HANZI = (
    "一二三四五六七八九十百千万亿零两昨今明早晚昼夜晨夜梦睡醒眠息静安"
    "心情绪感平 relaxed 快慢深浅轻重呼吸放松身体头脑压力焦虑抑郁愉悦"
    "温暖凉热干湿晴阴雨雪风雾天气温度湿度分秒时刻年月周日周旬"
    "我开始结束完成进行暂停继续播放停止上下一首前后返回确认取消"
    "首页对话助眠报告我的设置目标记录历史趋势统计分析洞察建议"
    "健康生活作息习惯打卡提醒闹钟渐进入睡唤醒浅深quality分数评"
    "你好吗谢请别客气对不起没关系在不是有了没去说来去好"
)

def collect_source_chars() -> str:
    """提取 lib/ 与 test/ 所有 .dart 文件的字符串字面量字符。"""
    chars = set()
    pat = re.compile(r"'([^']*)'|\"([^\"]*)\"")
    for sub in ("lib", "test"):
        d = ROOT / sub
        for p in d.rglob("*.dart"):
            text = p.read_text(encoding="utf-8", errors="ignore")
            for m in pat.finditer(text):
                s = m.group(1) or m.group(2) or ""
                chars.update(s)
    return "".join(chars)

def main() -> int:
    if not VENV_PY.exists():
        print(f"[!!] venv 不存在: {VENV_PY}")
        return 1

    src_chars = collect_source_chars()
    print(f"源码字符数: {len(set(src_chars))}")

    for src, dst, with_cjk in FONTS_SPEC:
        sp = FONTS / src
        dp = FONTS / dst
        if not sp.exists():
            print(f"[!!] 缺字体 {src}")
            return 1

        text = set(src_chars) | set(CJK_PUNCT)
        if with_cjk:
            text |= set(COMMON_HANZI)
        # ASCII 可打印
        text |= {chr(c) for c in range(0x20, 0x7F)}
        text.discard("\n"); text.discard("\t"); text.discard("\r")

        unicodes = ",".join(f"U+{ord(c):04X}" for c in sorted(text) if ord(c) >= 0x20)
        cmd = [
            str(VENV_PY), "-m", "fontTools.subset", str(sp),
            f"--text={(''.join(sorted(text)))}",
            "--layout-features=*",
            "--flavor=",  # 保持 ttf
            "--output-file=%s" % dp,
            "--no-hinting",
            "--desubroutinize",
        ]
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode != 0:
            print(f"[!!] {src} 子集化失败:\n{r.stderr[:500]}")
            return 1
        so, sn = sp.stat().st_size, dp.stat().st_size
        print(f"[OK] {dst:36s} {so/1048576:6.2f} MiB → {sn/1048576:6.2f} MiB  ({sn/so*100:5.1f}%)")

    # 子集成功后替换原文件
    for _, dst, _ in FONTS_SPEC:
        stem = dst.replace("-Subset.ttf", "-Regular.ttf").replace(
            "CormorantGaramond-Regular.ttf", "CormorantGaramond.ttf")
        src_p = FONTS / dst
        dst_p = FONTS / stem
        if dst_p.exists() and dst_p != src_p:
            os.remove(dst_p)
        src_p.rename(dst_p)
    print("\n已用子集版替换原文件。")
    return 0

if __name__ == "__main__":
    sys.exit(main())
