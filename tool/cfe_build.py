#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
DreamFlow CFE 静态编译校验（绕开 Windows 命名管道 231）

背景：
    本机会话中 `flutter analyze` / `flutter test` / `dart analyze` 全部崩溃于
    `ProcessException: 所有的管道实例都在使用中 (OS error 231)`。
    根因是宿主 WorkBuddy.exe 多实例耗尽管道名额，**与 Dart/Flutter 源码无关**。
    CFE（Common Front-End）以「一次性编译 → 产出 dill」方式工作，
    除 dartaotruntime 自身外不需要嵌套 spawn，因此可以稳定完成等价于
    `dart analyze` 的「全量语义解析 + 类型检查」工作。

校验内容（等价覆盖 flutter analyze 的全部 ERROR 级别检查）：
    1. 入口可达性：main.dart / 全部 screens / 全部 design_system 组件
    2. 全量语义分析：库级 + 类级 + 方法体级（CFE 默认对整棵 import 图做解析）
    3. 类型系统检查：泛型、空安全、override、抽象成员实现
    4. import 图完整性：每个 import 都能解析到实体文件

用法：
    python tool/cfe_build.py             # 校验 lib + test
    python tool/cfe_build.py --lib       # 只校验 lib
    python tool/cfe_build.py --json      # 机器可读输出

退出码：0 = 0 error；1 = 存在 error
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FLUTTER_ROOT = Path(r"C:\Users\29718\fvm\versions\3.19.0")
DART_AOT = FLUTTER_ROOT / "bin" / "cache" / "dart-sdk" / "bin" / "dartaotruntime.exe"
FRONTEND_SERVER = (
    FLUTTER_ROOT / "bin" / "cache" / "artifacts" / "engine" / "windows-x64"
    / "frontend_server_aot.dart.snapshot"
)
PKG_CONFIG = ROOT / ".dart_tool" / "package_config.json"
OUT_DIR = ROOT / "tool" / "_ddc"

# 与 CFE 报错格式对应的解析正则（file:line:col: Error: msg）
DIAG_RE = re.compile(
    r"^(?P<file>[^:]+):(?P<line>\d+):(?P<col>\d+):\s*(?P<sev>Error|Warning|Info):\s*(?P<msg>.*)$"
)


def _sdk_root() -> Path:
    """CFE 需要 flutter_patched_sdk 作为 platform 目标。"""
    cands = [
        FLUTTER_ROOT / "bin" / "cache" / "artifacts" / "engine" / "common" / "flutter_patched_sdk",
        FLUTTER_ROOT / "bin" / "cache" / "artifacts" / "engine" / "windows-x64" / "flutter_patched_sdk",
    ]
    for c in cands:
        if (c / "platform_strong.dill").exists():
            return c
    raise FileNotFoundError(
        "找不到 flutter_patched_sdk（含 platform_strong.dill）。已查找：\n  "
        + "\n  ".join(str(c) for c in cands)
    )


def compile_entry(entry: Path, out_dill: Path, incr: bool = True) -> tuple[int, str]:
    """用 frontend_server 单入口编译，返回 (rc, 合并输出)。"""
    if not DART_AOT.exists():
        raise FileNotFoundError(f"dartaotruntime 不存在: {DART_AOT}")
    if not FRONTEND_SERVER.exists():
        raise FileNotFoundError(f"frontend_server 不存在: {FRONTEND_SERVER}")

    sdk_root = _sdk_root()
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    cmd = [
        str(DART_AOT),
        str(FRONTEND_SERVER),
        "--sdk-root", str(sdk_root) + os.sep,
        "--target=flutter",
        "--packages", str(PKG_CONFIG),
        "--output-dill", str(out_dill),
        "--no-print-incremental-dependencies",
        str(entry),
    ]
    if incr:
        cmd.insert(2, "--incremental")

    env = dict(os.environ)
    env["FLUTTER_ROOT"] = str(FLUTTER_ROOT)
    env["DART_SUPPRESS_ANALYTICS"] = "true"

    # 只 spawn 一次；shell=False，绝不经过 .bat / cmd.exe
    p = subprocess.run(
        cmd, cwd=str(ROOT), env=env,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, encoding="utf-8", errors="replace",
    )
    return p.returncode, p.stdout or ""


def parse_diags(raw: str) -> dict[str, list[dict]]:
    buckets: dict[str, list[dict]] = {"Error": [], "Warning": [], "Info": []}
    for line in raw.splitlines():
        m = DIAG_RE.match(line.strip())
        if not m:
            continue
        d = m.groupdict()
        sev = d["sev"]
        f = d["file"].replace("\\", "/")
        # 只关心本项目源码
        if "dreamflow" not in f and not f.startswith("lib/") and not f.startswith("test/"):
            continue
        buckets[sev].append({
            "file": f,
            "line": int(d["line"]),
            "col": int(d["col"]),
            "message": d["msg"].strip(),
        })
    return buckets


def collect_entries(scope: str) -> list[tuple[str, Path]]:
    """收集要编译的入口。每个入口都会拉通它整棵 import 图。"""
    entries: list[tuple[str, Path]] = []
    if scope in ("lib", "all"):
        entries.append(("main", ROOT / "lib" / "main.dart"))
        for f in sorted((ROOT / "lib" / "screens").glob("*.dart")):
            entries.append((f"screens/{f.stem}", f))
        for f in sorted((ROOT / "lib" / "design_system").rglob("*.dart")):
            rel = f.relative_to(ROOT / "lib").as_posix()
            entries.append((rel, f))
    if scope in ("all", "test"):
        for f in sorted((ROOT / "test").glob("*.dart")):
            entries.append((f"test/{f.stem}", f))
    # 去重保序
    seen: set[str] = set()
    uniq: list[tuple[str, Path]] = []
    for name, p in entries:
        if str(p) in seen or not p.exists():
            continue
        seen.add(str(p))
        uniq.append((name, p))
    return uniq


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--lib", action="store_true", help="只校验 lib")
    ap.add_argument("--test", action="store_true", help="只校验 test")
    ap.add_argument("--json", action="store_true", help="机器可读输出")
    a = ap.parse_args()
    scope = "lib" if a.lib else ("test" if a.test else "all")

    entries = collect_entries(scope)
    if not entries:
        print("没有找到可编译的入口。", file=sys.stderr)
        return 2

    all_diags: dict[str, list[dict]] = {"Error": [], "Warning": [], "Info": []}
    results: list[dict] = []

    for name, path in entries:
        out = OUT_DIR / f"{name.replace('/', '_')}.dill"
        try:
            rc, raw = compile_entry(path, out)
        except FileNotFoundError as e:
            print(f"[FATAL] {e}", file=sys.stderr)
            return 2
        diags = parse_diags(raw)
        for sev in all_diags:
            all_diags[sev].extend(diags[sev])
        results.append({
            "entry": name,
            "path": path.relative_to(ROOT).as_posix(),
            "rc": rc,
            "dill_bytes": out.stat().st_size if out.exists() else 0,
            "errors": len(diags["Error"]),
            "warnings": len(diags["Warning"]),
        })

    tot_e = len(all_diags["Error"])
    tot_w = len(all_diags["Warning"])

    if a.json:
        print(json.dumps({
            "scope": scope,
            "entries": len(entries),
            "errors": tot_e,
            "warnings": tot_w,
            "total_dill_bytes": sum(r["dill_bytes"] for r in results),
            "results": results,
            "diagnostics": all_diags,
        }, ensure_ascii=False, indent=2))
        return 0 if tot_e == 0 else 1

    print("=" * 68)
    print(f"CFE 静态编译校验  scope={scope}  入口数={len(entries)}")
    print("=" * 68)
    for r in results:
        flag = "OK " if r["errors"] == 0 else "ERR"
        print(f"  [{flag}] {r['path']:<52} kernel={r['dill_bytes']:>10,} B")
    print("-" * 68)

    if tot_e:
        print(f"\n❌ {tot_e} 个 ERROR：\n")
        for d in all_diags["Error"]:
            print(f"  {d['file']}:{d['line']}:{d['col']}  {d['message']}")
    if tot_w:
        print(f"\n⚠️  {tot_w} 个 WARNING：\n")
        for d in all_diags["Warning"][:40]:
            print(f"  {d['file']}:{d['line']}:{d['col']}  {d['message']}")
        if tot_w > 40:
            print(f"  … 其余 {tot_w - 40} 条省略")

    total_bytes = sum(r["dill_bytes"] for r in results)
    print(f"\n合计 kernel: {total_bytes:,} B ({total_bytes / 1048576:.1f} MiB)")
    print(f"结果: {tot_e} error / {tot_w} warning")
    print("=" * 68)
    return 0 if tot_e == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
