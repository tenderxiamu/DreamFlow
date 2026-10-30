"""DreamFlow Flutter 代码结构自检（无需 spawn 子进程）。

检查项：
1. 所有 `import 'package:dreamflow/...'` 目标文件是否存在
2. 每个文件用到的 Df* 符号，是否由「本文件定义」或「直接 import 的文件」提供
   —— 可同时捕获：拼写错误、缺失 import
3. 括号 / 花括号配平（粗粒度语法完整性）

「未使用的 import」不在这里查 —— 正则做不准（模块公开面包含顶层变量、
part 文件、小写单例），交给 `flutter analyze`（已把 unused_import 设为 warning）。

扫描前会先做两步清理，否则结果不可信：
- **去注释**：注释里提到的 `Df*` 不算引用。原实现扫全文，于是
  `/// 兜底画面（通常是 [DfScene]）` 被判成「用了 DfScene 但没 import」，
  8 条这种假阳性会让整份报告被忽略。
- **去字符串**：prompt 里的 `[情绪:标签·强度:低]` 会参与括号计数，
  让本该配平的 `df_persona.dart` 被判成「方括号差 -1」。
  （import 路径本身就是字符串，所以路径提取用"只去注释"的版本。）
"""
from __future__ import annotations

import pathlib
import re
import sys

LIB = pathlib.Path(__file__).resolve().parents[1] / "lib"
PKG = "dreamflow"

RE_IMPORT = re.compile(r"^import\s+'([^']+)'", re.M)
RE_EXPORT = re.compile(r"^export\s+'([^']+)'", re.M)
# typedef 也算公开声明：漏了它，「typedef DfReportLoader = ...」这种定义
# 会被判成「使用了未定义的符号」，直接冤枉成阻断级问题
RE_CLASS = re.compile(
    r"^(?:class|enum|mixin|extension|typedef)\s+([A-Za-z_][A-Za-z0-9_]*)", re.M
)
RE_SYMBOL = re.compile(r"\b(Df[A-Za-z0-9_]*)\b")
RE_PART = re.compile(r"^part\s+'([^']+)'", re.M)



def sanitize(src: str, *, keep_strings: bool) -> str:
    """抹掉注释（可选：连字符串一起抹），保持换行与字符位置。

    支持 Dart 的三引号字符串与 `r'...'` 原始字符串 —— 不认三引号的话，
    `'''` 会被当成三个单引号，引号状态从那里开始错乱，
    后面整段 prompt 都被当成"字符串内部"，扫描结果就全歪了。
    """
    out: list[str] = []
    i, n = 0, len(src)
    mode = ""  # "" | "line" | "block" | "string"
    delim = ""
    raw = False
    while i < n:
        c = src[i]
        if mode == "line":
            if c == "\n":
                mode = ""
                out.append(c)
            else:
                out.append(" ")
            i += 1
            continue
        if mode == "block":
            if src[i:i + 2] == "*/":
                mode = ""
                out.append("  ")
                i += 2
                continue
            out.append("\n" if c == "\n" else " ")
            i += 1
            continue
        if mode == "string":
            if src[i:i + len(delim)] == delim:
                out.append(delim if keep_strings else " " * len(delim))
                i += len(delim)
                mode = ""
                continue
            if not raw and c == "\\" and i + 1 < n:
                out.append(src[i:i + 2] if keep_strings else "  ")
                i += 2
                continue
            if keep_strings:
                out.append(c)
            else:
                out.append("\n" if c == "\n" else " ")
            i += 1
            continue

        if src[i:i + 2] == "//":
            mode = "line"
            out.append("  ")
            i += 2
            continue
        if src[i:i + 2] == "/*":
            mode = "block"
            out.append("  ")
            i += 2
            continue
        if c in ('"', "'"):
            raw = i > 0 and src[i - 1] == "r"
            delim = c * 3 if src[i:i + 3] == c * 3 else c
            mode = "string"
            out.append(src[i:i + len(delim)] if keep_strings else " " * len(delim))
            i += len(delim)
            continue
        out.append(c)
        i += 1
    return "".join(out)


problems: list[str] = []
files = sorted(LIB.rglob("*.dart"))

# 缓存两种清理结果，避免重复读盘
_no_comment: dict[pathlib.Path, str] = {}
_no_string: dict[pathlib.Path, str] = {}


def no_comment(p: pathlib.Path) -> str:
    if p not in _no_comment:
        _no_comment[p] = sanitize(p.read_text(encoding="utf-8"), keep_strings=True)
    return _no_comment[p]


def no_string(p: pathlib.Path) -> str:
    if p not in _no_string:
        _no_string[p] = sanitize(p.read_text(encoding="utf-8"), keep_strings=False)
    return _no_string[p]


def symbols_of(p: pathlib.Path) -> set[str]:
    """文件自身声明的符号 + 它的 `part` 文件

    drift 用 `part 'db.g.dart'` 生成 `ChatMessage` 等类。不把 part 算进来，
    「df_chat_session.dart 用了 db.dart 却没用它的公开符号」这种假阳性
    会一直挂在输出里 —— 而它其实是整个工程最正常的一处 import。
    """
    names = set(RE_CLASS.findall(no_comment(p)))
    for part in RE_PART.findall(no_comment(p)):
        q = p.parent / part
        if q.exists():
            names |= set(RE_CLASS.findall(no_comment(q)))
    return names


# 1+2. 建立 symbol -> defining file 索引
defined: dict[str, str] = {}
for f in files:
    for name in symbols_of(f):
        defined.setdefault(name, str(f.relative_to(LIB)))

missing_imports: list[str] = []
for f in files:
    rel = str(f.relative_to(LIB))
    with_comment = no_comment(f)   # 去注释、留字符串（提 import 路径）
    bare = no_string(f)            # 去注释、去字符串（提符号、数括号）

    imports: list[str] = RE_IMPORT.findall(with_comment)
    exports: list[str] = RE_EXPORT.findall(with_comment)
    provided: set[str] = set()

    def _resolve(imp: str) -> pathlib.Path | None:
        if imp.startswith("dart:"):
            return None
        if imp.startswith("package:%s/" % PKG):
            return LIB / imp[len("package:%s/" % PKG):]
        if imp.startswith("package:"):
            return None  # 第三方 / SDK 包，不在本次自检范围
        return (f.parent / imp).resolve()

    for imp in imports:
        target = _resolve(imp)
        if target is None:
            continue
        if not target.exists():
            problems.append(f"[IMPORT] {rel}: 目标文件不存在 -> {imp}")
            continue
        provided |= symbols_of(target)

    # `export` 的符号本文件也能用（如 df_theme.dart 转出 df_tokens.dart），
    # 但计入 provided 就够了，不算「导入了却没用」
    for imp in exports:
        target = _resolve(imp)
        if target is not None and target.exists():
            provided |= symbols_of(target)

    provided |= symbols_of(f)

    used = set(RE_SYMBOL.findall(bare))
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

    # 本脚本不检查「未使用的 import」。
    #
    # 这一项用正则做不准：模块的公开面不只有类，还有顶层变量
    # （df_soundscape.dart 给外界的是 `final dfSoundscapeController = ...`）、
    # part 文件（drift 的 db.g.dart）、以及小写开头的单例。
    # 要么漏判要么狂误报 —— 而 `flutter analyze` 本来就能算准这件事
    # （analysis_options.yaml 里已把 unused_import 设成 warning）。
    # 别用正则重造 analyzer 已经做对的事。

    # 3. 配平（在「去注释 + 去字符串」的文本上数：
    #    注释里写个 "("、prompt 里写个 "[" 都不该判结构坏了）
    for open_ch, close_ch, label in (
        ("{", "}", "花括号"),
        ("(", ")", "圆括号"),
        ("[", "]", "方括号"),
    ):
        diff = bare.count(open_ch) - bare.count(close_ch)
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
if not problems and not missing_imports:
    print("结构自检通过：导入路径全部有效，Df* 符号全部可达。")

sys.exit(1 if (problems or missing_imports) else 0)
