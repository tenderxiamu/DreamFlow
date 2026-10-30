"""生成 publishableKey 的运行时拼装分片（轮换 key 后用）。

用法：
    python tool/encode_publishable_key.py
然后按提示粘贴新 key（或设环境变量 DF_WB_KEY 后直接运行），
脚本输出三段分片，粘贴覆盖 lib/data/cloud_config.dart 里的
_encPart1 / _encPart2 / _encPart3 即可。分片会自动做一致性自检。
"""
import base64
import getpass
import os
import sys

MASK = 0x37
ORDER = [2, 0, 1]  # 与 cloud_config.dart 的存储顺序一致（恢复序为其逆运算）


def encode(key: str) -> list[str]:
    b64 = base64.b64encode(bytes(b ^ MASK for b in key.encode())).decode()
    n = len(b64)
    third = n // 3
    parts = [b64[:third], b64[third:2 * third], b64[2 * third:]]
    return [parts[i] for i in ORDER]  # 存储序


def decode(stored: list[str]) -> str:
    # 恢复序 = [1, 2, 0]（与 cloud_config.dart 的 _shuffleOrder 一致）
    joined = stored[1] + stored[2] + stored[0]
    return bytes(b ^ MASK for b in base64.b64decode(joined)).decode()


def main() -> None:
    key = os.environ.get("DF_WB_KEY", "")
    if not key:
        key = getpass.getpass("粘贴新的 publishableKey（输入不回显）: ").strip()
    if not key.startswith("wbpk_"):
        sys.exit("看起来不像 publishableKey（应以 wbpk_ 开头），已中止")

    stored = encode(key)
    restored = decode(stored)
    if restored != key:
        sys.exit("自检失败：分片无法还原，请把此输出连同 key 长度反馈开发者")

    print("# 覆盖 lib/data/cloud_config.dart 中对应三个常量：")
    print(f"static const String _encPart1 = '{stored[0]}';")
    print(f"static const String _encPart2 = '{stored[1]}';")
    print(f"static const String _encPart3 = '{stored[2]}';")
    print("# 自检通过：分片可精确还原原 key。改完后运行 flutter test 确认。")


if __name__ == "__main__":
    main()
