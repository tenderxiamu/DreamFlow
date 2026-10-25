# -*- coding: utf-8 -*-
"""分段并行下载 Flutter 引擎产物到本地 Maven 仓库，供 Gradle 离线解析。
经 HTTP 代理走 urllib（自动 CONNECT 隧道）。
用法: python tool/fetch_engine_artifacts.py [proxy_port]
"""
import concurrent.futures as cf
import os
import sys
import time
import urllib.request
from pathlib import Path

PROXY_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 59717
VERSION = "1.0.0-a10d8ac38de835021c8d2f920dbf50a920ccc030"
ARTIFACTS = {
    "arm64_v8a_debug": 179848942,
    "armeabi_v7a_debug": 113951320,
    "x86_64_debug": 119176330,
}
BASE = "https://storage.googleapis.com/download.flutter.io/io/flutter"
REPO = Path(__file__).resolve().parent.parent / "tool" / "_m2local"
SEGMENTS = 6
MAX_RETRY = 5

OPENER = urllib.request.build_opener(
    urllib.request.ProxyHandler({
        "http": f"http://127.0.0.1:{PROXY_PORT}",
        "https": f"http://127.0.0.1:{PROXY_PORT}",
    }))


def fetch_range(artifact, start, end, dest: Path) -> int:
    """带重试的分段下载，写入 dest 对应偏移，返回字节数。"""
    url = f"{BASE}/{artifact}/{VERSION}/{artifact}-{VERSION}.jar"
    last_err = None
    for attempt in range(MAX_RETRY):
        try:
            req = urllib.request.Request(url, headers={
                "Range": f"bytes={start}-{end}",
                "User-Agent": "Mozilla/5.0",
            })
            with OPENER.open(req, timeout=90) as resp:
                with open(dest, "r+b") as f:
                    f.seek(start)
                    got = 0
                    while True:
                        chunk = resp.read(1 << 20)
                        if not chunk:
                            break
                        f.write(chunk)
                        got += len(chunk)
            expected = end - start + 1
            if got == expected:
                return got
            last_err = RuntimeError(f"短读 {got}/{expected}")
        except Exception as e:  # noqa: BLE001
            last_err = e
            time.sleep(2 * (attempt + 1))
    raise last_err


def download(artifact, size):
    dest_dir = REPO / "io" / "flutter" / artifact / VERSION
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / f"{artifact}-{VERSION}.jar"
    if dest.exists() and dest.stat().st_size == size:
        print(f"[SKIP] {artifact} 已存在", flush=True)
        return
    if not dest.exists() or dest.stat().st_size != size:
        with open(dest, "wb") as f:
            f.truncate(size)
    step = size // SEGMENTS
    bounds = []
    for i in range(SEGMENTS):
        s = i * step
        e = (i + 1) * step - 1 if i < SEGMENTS - 1 else size - 1
        bounds.append((s, e))
    t0 = time.time()
    with cf.ThreadPoolExecutor(SEGMENTS) as ex:
        futs = [ex.submit(fetch_range, artifact, s, e, dest) for s, e in bounds]
        total = sum(f.result() for f in futs)
    print(f"[OK] {artifact}: {total/1048576:.1f} MiB / {time.time()-t0:.0f}s", flush=True)


def main():
    t0 = time.time()
    for artifact in ARTIFACTS:
        d = REPO / "io" / "flutter" / artifact / VERSION
        d.mkdir(parents=True, exist_ok=True)
        pom = d / f"{artifact}-{VERSION}.pom"
        if not pom.exists():
            url = f"{BASE}/{artifact}/{VERSION}/{artifact}-{VERSION}.pom"
            for attempt in range(MAX_RETRY):
                try:
                    with OPENER.open(url, timeout=60) as r:
                        pom.write_bytes(r.read())
                    break
                except Exception:  # noqa: BLE001
                    time.sleep(2 * (attempt + 1))
            else:
                raise RuntimeError(f"POM 下载失败: {artifact}")
    print("POM 全部就绪", flush=True)
    with cf.ThreadPoolExecutor(len(ARTIFACTS)) as ex:
        futs = {ex.submit(download, a, s): a for a, s in ARTIFACTS.items()}
        for f in cf.as_completed(futs):
            f.result()
    print(f"全部完成，总耗时 {time.time()-t0:.0f}s", flush=True)


if __name__ == "__main__":
    main()
