"""M12 危机干预配置的运营工具。

用法：
  python tool/check_crisis_config.py validate            # 校验仓库种子文件
  python tool/check_crisis_config.py fetch               # 拉线上配置并与种子对比
  python tool/check_crisis_config.py sql                 # 打印更新线上的 SQL

环境变量：
  DF_WB_KEY   publishableKey（fetch 模式必需；不要写进任何文件）

校验规则与客户端 lib/data/df_crisis_config.dart 逐条对齐：
  - words：2-12 个字符、无空白、最多 200 条、去重、非空
  - hotlines：1-20 条；号码 ^[0-9][0-9\\- ]{2,19}$；name ≤ 20 字；note ≤ 30 字
  - 底线词（df_mood.dart 的 crisisWords）不允许从 words 里消失
"""
from __future__ import annotations

import base64
import json
import os
import re
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEED_PATH = os.path.join(ROOT, "config", "crisis_words.json")

ENDPOINT = "https://dreamflow-sleep.app.workbuddy.host"
REST_PATH = "/.cloud/database/rest/v1/crisis_config?select=*&limit=1"

# 与 df_mood.dart 同步维护（check 脚本会比对两边是否一致）
FLOOR_WORDS = [
    "不想活", "活不下去", "活着没意思", "活着没意义", "不如死了",
    "想死", "自杀", "自残", "自伤", "伤害自己",
    "结束自己", "结束生命", "跳楼", "跳下去", "割腕",
    "不想醒来", "想消失",
]
FLOOR_HOTLINE = "12356"

NUMBER_RE = re.compile(r"^[0-9][0-9\- ]{2,19}$")
WS_RE = re.compile(r"[\s\u3000]")


def err(msg: str) -> None:
    print(f"  ❌ {msg}")


def ok(msg: str) -> None:
    print(f"  ✅ {msg}")


def validate_payload(payload: dict, label: str) -> list[str]:
    """返回清洗后的词表；发现问题会打印并抛 ValueError。"""
    problems: list[str] = []

    words = payload.get("words")
    if not isinstance(words, list) or not words:
        problems.append("words 必须是非空数组")
        words = []
    elif len(words) > 200:
        problems.append(f"words 超过 200 条（{len(words)}）")

    seen: set[str] = set()
    clean: list[str] = []
    for w in words:
        if not isinstance(w, str):
            problems.append(f"words 里有非字符串项：{w!r}")
            continue
        s = w.strip()
        if not (2 <= len(s) <= 12):
            problems.append(f"词长度越界（2-12）：「{s}」")
            continue
        if WS_RE.search(s):
            problems.append(f"词含空白：「{s}」")
            continue
        if s in seen:
            continue
        seen.add(s)
        clean.append(s)

    missing_floor = [w for w in FLOOR_WORDS if w not in clean]
    if missing_floor:
        problems.append(f"底线词被删（不允许）：{missing_floor}")

    hotlines = payload.get("hotlines")
    if not isinstance(hotlines, list) or not hotlines:
        problems.append("hotlines 必须是非空数组")
    elif len(hotlines) > 20:
        problems.append(f"hotlines 超过 20 条（{len(hotlines)}）")
    else:
        numbers: set[str] = set()
        for h in hotlines:
            if not isinstance(h, dict):
                problems.append(f"hotlines 项不是对象：{h!r}")
                continue
            name = str(h.get("name", "")).strip()
            number = str(h.get("number", "")).strip()
            note = str(h.get("note", ""))
            if not name or len(name) > 20:
                problems.append(f"热线 name 为空或超 20 字：{h!r}")
            if not NUMBER_RE.match(number):
                problems.append(f"热线号码格式不对（3-20 位数字/-/空格）：{number!r}")
            if len(note) > 30:
                problems.append(f"热线 note 超 30 字：{note!r}")
            if number in numbers:
                problems.append(f"热线号码重复：{number}")
            numbers.add(number)
        if FLOOR_HOTLINE not in numbers:
            problems.append(f"底线热线 {FLOOR_HOTLINE} 不在列表里（不允许删）")

    for p in problems:
        err(f"[{label}] {p}")
    if not problems:
        ok(f"[{label}] 校验通过：{len(clean)} 词 / {len(hotlines)} 条热线")
    else:
        raise ValueError(f"{label} 校验失败")
    return clean


def load_seed() -> tuple[int, dict, list[str]]:
    with open(SEED_PATH, encoding="utf-8") as f:
        doc = json.load(f)
    version = int(doc["version"])
    words = validate_payload(doc["payload"], "种子文件")
    return version, doc["payload"], words


def cmd_validate() -> int:
    load_seed()
    print("\n下一步：python tool/check_crisis_config.py sql 生成更新 SQL")
    return 0


def cmd_fetch() -> int:
    key = os.environ.get("DF_WB_KEY", "")
    if not key:
        err("缺环境变量 DF_WB_KEY（publishableKey）")
        return 2
    req = urllib.request.Request(
        ENDPOINT + REST_PATH, headers={"x-wb-webapp-access-key": key}
    )
    with urllib.request.urlopen(req, timeout=12) as resp:
        rows = json.loads(resp.read().decode("utf-8"))
    if not rows:
        err("线上表为空（客户端会退回内置词表）")
        return 1
    row = max(rows, key=lambda r: r.get("version", -1))
    print(f"线上 version={row['version']}  updated_at={row['updated_at']}")
    remote_words = validate_payload(row["payload"], "线上配置")

    seed_version, seed_payload, seed_words = load_seed()
    added = [w for w in seed_words if w not in remote_words]
    removed = [w for w in remote_words if w not in seed_words]
    if not added and not removed and row["version"] >= seed_version:
        print("线上与种子一致，无需更新")
        return 0
    if added:
        print(f"种子新增（待发布）：{added}")
    if removed:
        print(f"种子移除（待发布）：{removed}")
    if row["version"] >= seed_version:
        err("线上 version 不低于种子，请先在种子文件里递增 version")
        return 1
    print("\n执行 python tool/check_crisis_config.py sql 获取更新 SQL")
    return 0


def cmd_sql() -> int:
    version, payload, _ = load_seed()
    body = json.dumps(payload, ensure_ascii=False)
    sql = (
        "UPDATE public.crisis_config SET "
        f"version = {version}, payload = '{body}'::jsonb, "
        "updated_at = now() WHERE id = 1"
    )
    b64 = base64.b64encode(sql.encode()).decode()
    print("── SQL（可贴进控制台，或让 AI 通过管理通道执行）──")
    print(sql)
    print("\n── base64（管理通道 sqlBase64 参数用）──")
    print(b64)
    return 0


def main() -> int:
    cmd = sys.argv[1] if len(sys.argv) > 1 else "validate"
    try:
        if cmd == "validate":
            return cmd_validate()
        if cmd == "fetch":
            return cmd_fetch()
        if cmd == "sql":
            return cmd_sql()
        err(f"未知命令：{cmd}（validate / fetch / sql）")
        return 2
    except ValueError as e:
        print(f"\n{e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
