"""DreamFlow Flutter 代码结构自检（无需 spawn 子进程）。

检查项：
1. 所有 `import 'package:dreamflow/...'` 目标文件是否存在
2. 每个文件用到的 Df* 符号，是否由「本文件定义」或「直接 import 的文件」提供
   —— 可同时捕获：拼写错误、缺失 import
3. 每个文件是否存在未使用的 dreamflow 内部 import
4. 括号 / 花括号配平（粗粒度语法完整性）
"""
from __future__ import annotations

import pathlib
import re
import sys

LIB = pathlib.Path(__file__).resolve().parents[1] / "lib"
PKG = "dreamflow"

RE_IMPORT = re.compile(r"^import\s+'([^']+)'", re.M)
RE_CLASS = re.compile(r"^(?:class|enum|mixin|extension)\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
RE_SYMBOL = re.compile(r"\b(Df[A-Za-z0-9_]*)\b")

problems: list[str] = []
notes: list[str] = []

files = sorted(LIB.rglob("*.dart"))

# 1+2. 建立 symbol -> defining file 索引
defined: dict[str, str] = {}
for f in files:
    src = f.read_text(encoding="utf-8")
    for name in RE_CLASS.findall(src):
        defined.setdefault(name, str(f.relative_to(LIB)))

missing_imports: list[str] = []
for f in files:
    rel = str(f.relative_to(LIB))
    src = f.read_text(encoding="utf-8")

    imports: list[str] = RE_IMPORT.findall(src)
    provided: set[str] = set()
    imported_files: list[pathlib.Path] = []

    for imp in imports:
        if imp.startswith("dart:"):
            continue
        if imp.startswith("package:%s/" % PKG):
            target = LIB / imp[len("package:%s/" % PKG):]
        elif imp.startswith("package:"):
            continue  # 第三方 / SDK 包，不在本次自检范围
        else:
            target = (f.parent / imp).resolve()

        if not target.exists():
            problems.append(f"[IMPORT] {rel}: 目标文件不存在 -> {imp}")
            continue
        imported_files.append(target)
        provided |= set(RE_CLASS.findall(target.read_text(encoding="utf-8")))
    provided |= set(RE_CLASS.findall(src))

    body = src
    used = set(RE_SYMBOL.findall(body))
    used.discard(rel)  # 避免误判
    for sym in sorted(used):
        if sym in provided:
            continue
        if sym in defined:
            missing_imports.append(
                f"[MISSING-IMPORT] {rel}: 使用了 {sym}（定义于 {defined[sym]}），但未直接 import"
            )
        else:
            problems.append(f"[UNDEFINED] {rel}: 使用了未定义的符号 {sym}")

    # 3. 未使用的内部 import
    for target in imported_files:
        names = set(RE_CLASS.findall(target.read_text(encoding="utf-8")))
        if names and not (names & used):
            notes.append(
                f"[UNUSED-IMPORT] {rel}: {target.relative_to(LIB)} 的公开符号未被使用"
            )

    # 4. 配平
    for open_ch, close_ch, label in (("{", "}", "花括号"), ("(", ")", "圆括号"), ("[", "]", "方括号")):
        # 粗略配平：忽略字符串内容的影响可接受（本例无字符串内括号）
        diff = src.count(open_ch) - src.count(close_ch)
        if diff != 0:
            problems.append(f"[SYNTAX] {rel}: {label}不配平（差 {diff}）")

declared = len(defined)
print(f"扫描 {len(files)} 个 Dart 文件，识别 {declared} 个公开声明\n")

if problems:
    print("== 阻断级问题 ==")
    for p in problems:
        print(" ", p)
if missing_imports:
    print("== 缺失 import ==")
    for p in missing_imports:
        print(" ", p)
if notes:
    print("== 提示 ==")
    for n in notes:
        print(" ", n)

if not problems and not missing_imports:
    print("结构自检通过：导入路径全部有效，Df* 符号全部可达。")

sys.exit(1 if (problems or missing_imports) else 0)
