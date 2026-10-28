#!/usr/bin/env python3
"""极简 MP4 探测：分辨率 / 时长 / 码率。

本机没有 ffprobe（pip 镜像也拉不到 imageio-ffmpeg），
所以直接读 MP4 的 box：moov/mvhd 拿时长，moov/trak/tkhd 拿显示宽高。

用法：
    python tool/mp4_probe.py assets/scene/*.mp4
"""
from __future__ import annotations

import struct
import sys
from pathlib import Path

CONTAINERS = {b'moov', b'trak', b'mdia', b'minf', b'stbl', b'edts', b'udta'}


def boxes(buf: bytes, start: int, end: int):
    pos = start
    while pos + 8 <= end:
        size = struct.unpack('>I', buf[pos:pos + 4])[0]
        kind = buf[pos + 4:pos + 8]
        header = 8
        if size == 1:
            if pos + 16 > end:
                return
            size = struct.unpack('>Q', buf[pos + 8:pos + 16])[0]
            header = 16
        elif size == 0:
            size = end - pos
        if size < header or pos + size > end:
            return
        yield kind, pos + header, pos + size
        pos += size


def find(buf: bytes, start: int, end: int, path: list[bytes]):
    """按 box 路径向下找第一个匹配，返回 (body_start, body_end)。"""
    want = path[0]
    for kind, s, e in boxes(buf, start, end):
        if kind != want:
            continue
        if len(path) == 1:
            return s, e
        found = find(buf, s, e, path[1:])
        if found:
            return found
    return None


def mvhd_duration(buf: bytes, s: int, e: int):
    version = buf[s]
    if version == 1:
        timescale = struct.unpack('>I', buf[s + 20:s + 24])[0]
        duration = struct.unpack('>Q', buf[s + 24:s + 32])[0]
    else:
        timescale = struct.unpack('>I', buf[s + 12:s + 16])[0]
        duration = struct.unpack('>I', buf[s + 16:s + 20])[0]
    return (duration / timescale) if timescale else 0.0


def tkhd_size(buf: bytes, s: int, e: int):
    """tkhd 末尾 8 字节是 16.16 定点显示宽高。"""
    w = struct.unpack('>I', buf[e - 8:e - 4])[0] / 65536
    h = struct.unpack('>I', buf[e - 4:e])[0] / 65536
    return w, h


def probe(path: Path):
    buf = path.read_bytes()
    dur, w, h = 0.0, 0, 0
    mv = find(buf, 0, len(buf), [b'moov', b'mvhd'])
    if mv:
        dur = mvhd_duration(buf, *mv)
    tk = find(buf, 0, len(buf), [b'moov', b'trak', b'tkhd'])
    if tk:
        w, h = tkhd_size(buf, *tk)

    size = len(buf)
    mb = size / 1024 / 1024
    kbps = (size * 8 / 1000 / dur) if dur else 0
    print(f'{path.name:24} {int(w)}x{int(h):<5} {dur:6.2f}s  '
          f'{mb:5.2f} MiB  {kbps:6.0f} kbps')


if __name__ == '__main__':
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(1)
    for a in args:
        p = Path(a)
        if p.exists():
            probe(p)
        else:
            print(f'{a}: not found')
