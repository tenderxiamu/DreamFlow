# -*- coding: utf-8 -*-
"""不依赖第三方库：解析 MP3 帧头统计时长 / 码率 / 采样率。"""
import os, struct, sys

BITRATES = {  # (version, layer) -> kbps table
    ("mpeg1", 3): [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0],
    ("mpeg2", 3): [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0],
}
RATES = {"mpeg1": [44100, 48000, 32000], "mpeg2": [22050, 24000, 16000],
         "mpeg25": [11025, 12000, 8000]}


def skip_id3(d):
    if d[:3] == b"ID3":
        size = ((d[6] & 0x7F) << 21) | ((d[7] & 0x7F) << 14) | ((d[8] & 0x7F) << 7) | (d[9] & 0x7F)
        return 10 + size
    return 0


def analyze(path):
    d = open(path, "rb").read()
    off = skip_id3(d)
    n = len(d)
    frames = 0
    dur = 0.0
    first = None
    while off + 4 <= n:
        if d[off] != 0xFF or (d[off + 1] & 0xE0) != 0xE0:
            off += 1
            continue
        h = struct.unpack(">I", d[off:off + 4])[0]
        ver_bits = (h >> 19) & 0x3
        layer_bits = (h >> 17) & 0x3
        br_idx = (h >> 12) & 0xF
        sr_idx = (h >> 10) & 0x3
        pad = (h >> 9) & 0x1
        if ver_bits == 1 or layer_bits != 1 or br_idx in (0, 15) or sr_idx == 3:
            off += 1
            continue
        ver = {3: "mpeg1", 2: "mpeg2", 0: "mpeg25"}[ver_bits]
        sr = RATES[ver][sr_idx]
        if ver == "mpeg1":
            br = BITRATES[("mpeg1", 3)][br_idx]
            samples = 1152
        else:
            br = BITRATES[("mpeg2", 3)][br_idx]
            samples = 576
        flen = int(samples / 8 * br * 1000 / sr) + pad
        if flen <= 4:
            off += 1
            continue
        if first is None:
            first = (br, sr)
            ch = "mono" if ((h >> 6) & 0x3) == 3 else "stereo"
            first = (br, sr, ch)
        dur += samples / sr
        frames += 1
        off += flen
    return dur, frames, first


for f in sys.argv[1:]:
    dur, frames, info = analyze(f)
    print("%-44s %6.2fs  frames=%-6d  %dkbps %dHz %s  meta=%s"
          % (os.path.basename(f), dur, frames, info[0], info[1], info[2], "yes" if b"TAG" in open(f,'rb').read()[-128:] else "no"))
