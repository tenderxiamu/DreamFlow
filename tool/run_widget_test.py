#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
DreamFlow Widget 测试驱动器（绕开 Windows 命名管道 231）

背景
────
本机 WorkBuddy 宿主进程多实例耗尽了 Windows 命名管道名额，`flutter test`
的子进程编排链（pub → git → dart → flutter_tester）第一步即崩：
    ProcessException: 所有的管道实例都在使用中 (process_win.cc:742)

本驱动器把 `flutter test` 的全部工作**自行实现**，全程只 spawn 两次
（dartaotruntime 编译 + flutter_tester 运行），不经过 cmd.exe / .bat，
因此不受宿主管道配额影响。

协议依据（逐行对照 Flutter / package:test 源码实现）
──────────────────────────────────────────────────
1. bootstrap 生成  : flutter_tools/lib/src/test/flutter_platform.dart
                     ::generateTestBootstrap
2. tester 启动参数 : flutter_tools/lib/src/test/flutter_tester_device.dart
                     ::FlutterTesterTestDevice.start
3. 初始握手消息    : test_core/lib/src/runner/plugin/platform_helpers.dart
                     ::deserializeSuite
4. 帧格式          : stream_channel/lib/src/multi_channel.dart
                     → 每帧为 [virtualChannelId, payload]，主通道 id = 0
5. 事件流          : 主通道先收 {'type':'success','root':{...}}，
                     再发 {'type':'run','entries':[...]} 触发执行，
                     运行期收 testStart / testDone / error / print / done

用法
────
    python tool/run_widget_test.py                    # 跑 test/ 下全部
    python tool/run_widget_test.py test/xxx_test.dart
    python tool/run_widget_test.py -v                 # 打印原始协议帧
    python tool/run_widget_test.py --json

退出码：0 = 全部通过；1 = 有失败
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FLUTTER_ROOT = Path(r"C:\Users\29718\fvm\versions\3.19.0")
CACHE = FLUTTER_ROOT / "bin" / "cache"
ENGINE = CACHE / "artifacts" / "engine" / "windows-x64"
DART_AOT = CACHE / "dart-sdk" / "bin" / "dartaotruntime.exe"
FRONTEND_SERVER = ENGINE / "frontend_server_aot.dart.snapshot"
FLUTTER_TESTER = ENGINE / "flutter_tester.exe"
ICU = ENGINE / "icudtl.dat"
PKG_CONFIG = ROOT / ".dart_tool" / "package_config.json"
TMP = ROOT / "tool" / "_wtest"

WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"


# ═══════════════════════ 1. bootstrap 生成 ═══════════════════════

BOOTSTRAP = '''// @dart=3.10
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_api/backend.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:stack_trace/stack_trace.dart';

import '{test_url}' as test;

// DO NOT RENAME: 工具链依赖此常量名获取 package config。
const packageConfigLocation = '{pkg_config}';

/// Returns a serialized test suite.
StreamChannel<dynamic> serializeSuite(Function getMain()) {{
  return RemoteListener.start(getMain);
}}

Future<void> _testMain() async {{
  await Future(test.main);
}}

void catchIsolateErrors() {{
  final ReceivePort errorPort = ReceivePort();
  Isolate.current.setErrorsFatal(false);
  Isolate.current.addErrorListener(errorPort.sendPort);
  errorPort.listen((dynamic message) {{
    final IsolateSpawnException error = IsolateSpawnException(message[0] as String);
    final Trace stackTrace = message[1] == null
        ? Trace(const <Frame>[])
        : Trace.parse(message[1] as String);
    Zone.current.handleUncaughtError(error, stackTrace);
  }});
}}

void main() {{
  final String serverPort = Platform.environment['SERVER_PORT'] ?? '';
  final String server = 'ws://127.0.0.1:$serverPort';
  StreamChannel<dynamic> testChannel = serializeSuite(() {{
    catchIsolateErrors();
    goldenFileComparator = LocalFileComparator(Uri.parse('{test_url}'));
    autoUpdateGoldenFiles = false;
    return _testMain;
  }});

  WebSocket.connect(server).then((WebSocket socket) {{
    socket.map((dynamic message) => json.decode(message as String)).pipe(testChannel.sink);
    socket.addStream(testChannel.stream.map(json.encode));
  }});
}}
'''


def gen_bootstrap(test_dart: Path, out: Path) -> None:
    url = "file:///" + str(test_dart).replace("\\", "/")
    pkg = "file:///" + str(PKG_CONFIG).replace("\\", "/")
    out.write_text(BOOTSTRAP.format(test_url=url, pkg_config=pkg), encoding="utf-8")


# ═══════════════════════ 2. CFE 编译 ═══════════════════════

def sdk_root() -> Path:
    c = CACHE / "artifacts" / "engine" / "common" / "flutter_patched_sdk"
    if (c / "platform_strong.dill").exists():
        return c
    raise FileNotFoundError("找不到 flutter_patched_sdk")


def compile_dill(entry: Path, out: Path) -> tuple[int, str]:
    cmd = [
        str(DART_AOT), str(FRONTEND_SERVER),
        "--incremental",
        "--sdk-root", str(sdk_root()) + os.sep,
        "--target=flutter",
        "--packages", str(PKG_CONFIG),
        "--output-dill", str(out),
        "--no-print-incremental-dependencies",
        str(entry),
    ]
    env = dict(os.environ, FLUTTER_ROOT=str(FLUTTER_ROOT), DART_SUPPRESS_ANALYTICS="true")
    p = subprocess.run(cmd, cwd=str(ROOT), env=env, stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
    return p.returncode, p.stdout or ""


# ═══════════════════════ 3. 极简 WebSocket ═══════════════════════

class WsConn:
    """只处理 text/binary/ping/pong/close；不分片（test 协议消息始终为单片）。"""

    def __init__(self, sock: socket.socket):
        self.sock = sock
        self._buf = b""
        self._lock = threading.Lock()
        self.closed = False

    def handshake(self) -> None:
        data = b""
        while b"\r\n\r\n" not in data:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise ConnectionError("握手期间连接关闭")
            data += chunk
        head, _, rest = data.partition(b"\r\n\r\n")
        self._buf = rest                      # 握手可能附带 payload，必须保留
        key = ""
        for line in head.decode("latin-1").split("\r\n"):
            if line.lower().startswith("sec-websocket-key:"):
                key = line.split(":", 1)[1].strip()
        if not key:
            raise ConnectionError("握手请求缺少 Sec-WebSocket-Key")
        accept = base64.b64encode(
            hashlib.sha1((key + WS_GUID).encode()).digest()
        ).decode()
        self.sock.sendall((
            "HTTP/1.1 101 Switching Protocols\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Accept: {accept}\r\n\r\n"
        ).encode())

    def send_text(self, text: str) -> None:
        payload = text.encode("utf-8")
        n = len(payload)
        hdr = bytearray([0x81])
        if n < 126:
            hdr.append(n)
        elif n < 65536:
            hdr.append(126)
            hdr += n.to_bytes(2, "big")
        else:
            hdr.append(127)
            hdr += n.to_bytes(8, "big")
        with self._lock:
            self.sock.sendall(bytes(hdr) + payload)

    def close(self) -> None:
        if self.closed:
            return
        self.closed = True
        try:
            with self._lock:
                self.sock.sendall(bytes([0x88, 0x00]))
        except OSError:
            pass

    def _recv_exact(self, n: int) -> bytes:
        while len(self._buf) < n:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise ConnectionError("EOF")
            self._buf += chunk
        out, self._buf = self._buf[:n], self._buf[n:]
        return out

    def recv_text(self) -> str | None:
        """返回一帧文本；控制帧就地处理；对端关闭返回 None。"""
        while True:
            b0, b1 = self._recv_exact(2)
            opcode = b0 & 0x0F
            masked = bool(b1 & 0x80)
            ln = b1 & 0x7F
            if ln == 126:
                ln = int.from_bytes(self._recv_exact(2), "big")
            elif ln == 127:
                ln = int.from_bytes(self._recv_exact(8), "big")
            mask = self._recv_exact(4) if masked else None
            data = self._recv_exact(ln) if ln else b""
            if mask:
                data = bytes(c ^ mask[i % 4] for i, c in enumerate(data))
            if opcode == 0x8:
                return None
            if opcode == 0x9:
                with self._lock:
                    self.sock.sendall(bytes([0x8A, len(data)]) + data)
                continue
            if opcode == 0xA:
                continue
            return data.decode("utf-8", errors="replace")


# ═══════════════════════ 4. MultiChannel 帧编解码 ═══════════════════════

class MultiChannel:
    """复刻 stream_channel MultiChannel 帧格式：每帧 [id, payload]，主通道 id = 0。

    id 语义（见 multi_channel.dart）：
      · 本端 `virtualChannel()` 无参 → inputId=_nextId+1(偶), outputId=_nextId(奇)，
        对外暴露的 `.id` 是 **outputId**；本端**发送**用 outputId，**接收**用 inputId。
      · 远端 `virtualChannel(remoteId)` 有参 → inputId=remoteId, outputId=remoteId+1，
        即远端发来的帧 id = remoteId，本端回复的帧 id = remoteId+1。

    因此：
      · tester 报出的 test.channel = tester 的 outputId（奇数）
      · 本端要 POST 给该通道 → 帧 id = tester 的 inputId = channel + 1
      · 本端告知 tester 新通道用 id = N（偶数），tester 回帧 id = N + 1
    """

    def __init__(self, ws: WsConn, on_frame):
        self.ws = ws
        self.on_frame = on_frame           # (channel_id, payload) -> None
        # 本端分配的通道 id 必须避开 tester 自己的编号段
        # （tester 为 N 个 test 各分配 inputId = 2,4,...,2N）。
        # 从 1000 起，纯偶数，空间充裕且不会与 tester 冲突。
        self._next_local_id = 1000

    def new_local_channel(self) -> tuple[int, int]:
        """本端发起一个虚拟通道。

        返回 (send_to_remote_id, listen_reply_id)：
          · 把这个 send_to_remote_id 通过消息告知 tester
          · tester 的回帧 id = send_to_remote_id + 1
        """
        remote_id = self._next_local_id
        self._next_local_id += 2
        return remote_id, remote_id + 1

    def send(self, channel_id: int, payload) -> None:
        self.ws.send_text(json.dumps([channel_id, payload]))

    def feed(self, raw: str) -> bool:
        try:
            frame = json.loads(raw)
        except json.JSONDecodeError:
            return False
        if not isinstance(frame, list) or not frame:
            return False
        cid = int(frame[0])
        payload = frame[1] if len(frame) > 1 else None
        self.on_frame(cid, payload)
        return True


# ═══════════════════════ 5. 事件收集 ═══════════════════════

class SuiteEvents:
    """解析 tester 送回的事件流（主通道 + 各 test 虚拟通道）。"""

    def __init__(self, verbose: bool = False, quiet_channels: bool = False):
        self.verbose = verbose
        self.quiet_channels = quiet_channels
        self.tests: dict[int, str] = {}
        self.channel_owner: dict[int, str] = {}   # 虚拟通道 id -> test 名
        self.passed = 0
        self.failed = 0
        self.skipped = 0
        self.errors: list[str] = []
        self.prints: list[str] = []
        self.done = False
        self._finished: set[str] = set()

    def handle(self, cid: int, payload) -> None:
        if self.verbose and not (self.quiet_channels and cid != 0):
            s = json.dumps(payload, ensure_ascii=False)[:300]
            print(f"    << [{cid}] {s}", flush=True)
        if not isinstance(payload, dict):
            return
        t = payload.get("type")

        # ── 主通道事件 ──
        if t == "print":
            self.prints.append(str(payload.get("line", "")))
        elif t == "testStart":
            test = payload.get("test") or {}
            if isinstance(test, dict):
                self.tests[int(test.get("id", -1))] = str(test.get("name", "?"))
        elif t == "testDone":
            tid = payload.get("testID")
            name = self.tests.get(int(tid) if tid is not None else -1, "?")
            if payload.get("hidden"):
                return
            if payload.get("skipped"):
                self.skipped += 1
            elif payload.get("result") == "success":
                self.passed += 1
            else:
                self.failed += 1
                self.errors.append(f"{name}  [{payload.get('result')}]")
            self._finished.add(name)
        elif t == "error":
            tid = payload.get("testID")
            name = self.tests.get(int(tid) if tid is not None else -1, "load")
            err = payload.get("error")
            msg = str(err.get("error", "")) if isinstance(err, dict) else str(err or "")
            if msg and "not a subtype" in msg and "Map" in msg:
                pass  # 结构探测期的噪音
            self.errors.append(f"{name}: {msg[:400]}")
        elif t == "loadException":
            self.errors.append(f"loadException: {payload.get('message')}")
        elif t == "done":
            self.done = True

        # ── test 虚拟通道事件（RunnerTest 协议）──
        elif t == "complete":
            owner = self.channel_owner.get(cid, f"ch{cid}")
            if owner not in self._finished and not self.failed:
                pass
        elif t == "state-change":
            owner = self.channel_owner.get(cid, "")
            status = payload.get("status")
            result = payload.get("result")
            if status == "complete" and owner and owner not in self._finished:
                self._finished.add(owner)
                if result == "success":
                    self.passed += 1
                elif result == "error":
                    self.failed += 1
                    self.errors.append(f"{owner}  [{result}]")
        elif t == "message":
            self.prints.append(str(payload.get("text", "")))


# ═══════════════════════ 6. 单文件运行 ═══════════════════════

def initial_message(path: Path) -> dict:
    """复刻 platform_helpers.deserializeSuite 的 initial 帧。

    字段结构严格对应 test_api 的序列化实现：
      - platform : suite_platform.dart::serialize → runtime/compiler 用 identifier 字符串
      - metadata : metadata.dart::serialize       → 各字段缺一不可
    """
    url = "file:///" + str(path).replace("\\", "/")
    return {
        "type": "initial",
        "platform": {
            "runtime": "vm",
            "compiler": "kernel",
            "os": "windows",
            "inGoogle": False,
        },
        "metadata": {
            "testOn": None,
            "timeout": {"duration": 30_000_000, "scaleFactor": None},
            "skip": False,
            "skipReason": None,
            "verboseTrace": False,
            "chainStackTraces": False,
            "retry": None,
            "tags": [],
            "onPlatform": [],
            "forTag": {},
            "languageVersionComment": None,
        },
        "asciiGlyphs": True,
        "path": url,
        "collectTraces": False,
        "noRetry": False,
        "foldTraceExcept": [],
        "foldTraceOnly": [],
        "allowDuplicateTestNames": False,
        "ignoreTimeouts": False,
        "platformVariables": [],
    }


def _collect_test_channels(root: dict) -> list[tuple[str, int]]:
    """遍历 suite 结构，收集 (用例名, testerChannelId)。

    注意：`_serializeTest` 序列化出的条目**只有 channel 字段，没有 id**
    （见 test_api/src/backend/remote_listener.dart:_serializeTest）。
    runner 必须在这个虚拟通道上发 {'command':'run','channel': <newId>}。
    """
    out: list[tuple[str, int]] = []

    def walk(group: dict, prefix: str) -> None:
        for entry in group.get("entries") or []:
            if not isinstance(entry, dict):
                continue
            if entry.get("type") == "group":
                walk(entry, prefix + str(entry.get("name", "")) + " ")
            else:
                ch = entry.get("channel")
                if ch is not None:
                    out.append((prefix + str(entry.get("name", "?")), int(ch)))

    if isinstance(root, dict):
        walk(root, "")
    return out


def run_one(test_dart: Path, verbose: bool = False) -> dict:
    TMP.mkdir(parents=True, exist_ok=True)
    stem = test_dart.stem
    boot = TMP / f"{stem}.bootstrap.dart"
    dill = TMP / f"{stem}.dill"

    gen_bootstrap(test_dart, boot)
    print("  · 生成 bootstrap", flush=True)

    rc, log = compile_dill(boot, dill)
    errs = [l for l in log.splitlines() if ": Error:" in l]
    size = dill.stat().st_size if dill.exists() else 0
    print(f"  · CFE 编译 rc={rc} kernel={size:,}B", flush=True)
    if rc != 0 or errs:
        return {"file": test_dart.relative_to(ROOT).as_posix(), "ok": False,
                "phase": "compile", "passed": 0, "failed": 0, "skipped": 0,
                "errors": errs or [log[-2000:]], "shell": []}

    # 测试服务端：tester 会主动连过来
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", 0))
    srv.listen(1)
    srv.settimeout(90.0)
    port = srv.getsockname()[1]

    cmd = [
        str(FLUTTER_TESTER),
        "--disable-vm-service",
        "--verbose-logging",
        f"--icu-data-file-path={ICU}",
        "--enable-checked-mode",
        "--verify-entry-points",
        "--enable-software-rendering",
        "--skia-deterministic-rendering",
        "--non-interactive",
        "--use-test-fonts",
        "--disable-asset-fonts",
        f"--packages={PKG_CONFIG}",
        str(dill),
    ]
    env = dict(os.environ)
    env.update({
        "FLUTTER_TEST": "true",
        "SERVER_PORT": str(port),
        "APP_NAME": "dreamflow",
        "FLUTTER_ROOT": str(FLUTTER_ROOT),
        # 本机设了 HTTP_PROXY，回环 WebSocket 会被代理拦成 502，必须绕过
        "NO_PROXY": "127.0.0.1,localhost,::1",
        "no_proxy": "127.0.0.1,localhost,::1",
    })
    for k in ("HTTP_PROXY", "HTTPS_PROXY", "http_proxy", "https_proxy",
              "ALL_PROXY", "all_proxy"):
        env.pop(k, None)

    proc = subprocess.Popen(
        cmd, cwd=str(ROOT), env=env,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, encoding="utf-8", errors="replace", bufsize=1,
    )
    shell_lines: list[str] = []

    def pump() -> None:
        assert proc.stdout is not None
        for line in proc.stdout:
            shell_lines.append(line.rstrip())

    threading.Thread(target=pump, daemon=True).start()

    ev = SuiteEvents(verbose=verbose)
    conn: WsConn | None = None
    mc: MultiChannel | None = None
    state = {"loaded": False}

    def on_frame(cid: int, payload) -> None:
        # 主通道首先回 {'type':'success','root':...}，里面带每个 test 的 channel id
        if (cid == 0 and isinstance(payload, dict)
                and payload.get("type") == "success" and not state["loaded"]):
            state["loaded"] = True
            root = payload.get("root") or {}
            pairs = _collect_test_channels(root)
            print(f"  · suite 已加载，声明用例 {len(pairs)} 个 → 逐个下发 run", flush=True)
            # test.channel 是 tester 的 outputId；发 run 要到它的 inputId = channel + 1
            # 新通道用本端分配的偶数 id，tester 回帧到 id + 1
            for name, tester_out_id in pairs:
                reply_id, listen_id = mc.new_local_channel()
                mc.send(tester_out_id + 1, {"command": "run", "channel": reply_id})
                ev.channel_owner[listen_id] = name
            state["expected"] = len(pairs)
            if not pairs:
                ev.errors.append("suite 中未发现任何 test（声明阶段可能失败）")
                ev.done = True
            return
        ev.handle(cid, payload)
        # 全部用例均已结束 → 收尾
        if state.get("expected") and (
            ev.passed + ev.failed + ev.skipped >= state["expected"]
        ):
            ev.done = True

    try:
        raw, _ = srv.accept()
        conn = WsConn(raw)
        conn.handshake()
        print("  · tester 已连接", flush=True)

        mc = MultiChannel(conn, on_frame)
        mc.send(0, initial_message(test_dart))     # 第一步：发 initial 帧
        print("  · 已发送 initial 帧", flush=True)

        srv.settimeout(5.0)
        deadline = time.time() + 240
        while time.time() < deadline:
            try:
                msg = conn.recv_text()
            except socket.timeout:
                if ev.done:
                    break
                continue
            if msg is None:
                print("  · tester 关闭连接", flush=True)
                break
            mc.feed(msg)
            if ev.done:
                time.sleep(0.3)
                break
    except (ConnectionError, OSError) as e:
        shell_lines.append(f"[harness] {type(e).__name__}: {e}")
    finally:
        if conn:
            conn.close()
        srv.close()
        try:
            proc.wait(timeout=8)
            shell_lines.append(f"[harness] tester exit={proc.returncode}")
        except subprocess.TimeoutExpired:
            proc.kill()
            shell_lines.append("[harness] tester 超时，已 kill")

    ok = (ev.failed == 0 and ev.passed > 0
          and not any(": Error:" in l for l in shell_lines))

    return {
        "file": test_dart.relative_to(ROOT).as_posix(),
        "ok": ok,
        "phase": "run",
        "passed": ev.passed,
        "failed": ev.failed,
        "skipped": ev.skipped,
        "errors": ev.errors,
        "prints": ev.prints[-20:],
        "shell": shell_lines[-20:] if not ok else [],
    }


# ═══════════════════════ 7. CLI ═══════════════════════

def discover(arg: str | None) -> list[Path]:
    if arg:
        p = Path(arg)
        return [p if p.is_absolute() else ROOT / p]
    return sorted((ROOT / "test").glob("*_test.dart"))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("path", nargs="?", help="单个测试文件")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("-v", "--verbose", action="store_true")
    a = ap.parse_args()

    files = discover(a.path)
    if not files:
        print("没有找到测试文件。", file=sys.stderr)
        return 2

    results = []
    for f in files:
        print(f"\n▶ {f.relative_to(ROOT).as_posix()}", flush=True)
        r = run_one(f, verbose=a.verbose)
        results.append(r)
        mark = "PASS" if r["ok"] else "FAIL"
        print(f"  [{mark}] passed={r['passed']} failed={r['failed']} "
              f"skipped={r['skipped']} (phase={r['phase']})", flush=True)
        if not r["ok"]:
            for m in (r.get("errors") or [])[:12]:
                print(f"      ✗ {m}")
            for l in (r.get("shell") or [])[:12]:
                print(f"      | {l}")
        sys.stdout.flush()

    tp = sum(r["passed"] for r in results)
    tf = sum(r["failed"] for r in results)
    ts = sum(r["skipped"] for r in results)
    all_ok = all(r["ok"] for r in results)

    if a.json:
        print(json.dumps({"results": results, "passed": tp, "failed": tf,
                          "skipped": ts, "ok": all_ok},
                         ensure_ascii=False, indent=2))
        return 0 if all_ok else 1

    print("\n" + "=" * 68)
    print(f"合计: {tp} passed / {tf} failed / {ts} skipped   文件 {len(results)} 个")
    print("结果:", "✅ 全部通过" if all_ok else "❌ 存在失败")
    print("=" * 68)
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
