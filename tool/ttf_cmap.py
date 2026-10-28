import struct, sys, io, os

def read_tables(path):
    f = open(path, 'rb')
    data = f.read()
    f.close()
    if data[:4] not in (b'\x00\x01\x00\x00', b'true', b'OTTO'):
        return data, {}
    num = struct.unpack('>H', data[4:6])[0]
    tables = {}
    off = 12
    for _ in range(num):
        tag = data[off:off+4].decode('latin1')
        toff, tlen = struct.unpack('>II', data[off+8:off+16])
        tables[tag] = (toff, tlen)
        off += 16
    return data, tables

def cmap_codepoints(data, tables):
    if 'cmap' not in tables:
        return set()
    base = tables['cmap'][0]
    version, n = struct.unpack('>HH', data[base:base+4])
    cps = set()
    for i in range(n):
        p = base + 4 + i*8
        pid, eid, sub = struct.unpack('>HHI', data[p:p+8])
        s = base + sub
        fmt = struct.unpack('>H', data[s:s+2])[0]
        if fmt == 4:
            segX2 = struct.unpack('>H', data[s+6:s+8])[0]
            seg = segX2 // 2
            ends = struct.unpack('>%dH' % seg, data[s+14:s+14+segX2])
            starts_off = s + 16 + segX2
            starts = struct.unpack('>%dH' % seg, data[starts_off:starts_off+segX2])
            for a, b in zip(starts, ends):
                if a == 0xFFFF:
                    continue
                cps.update(range(a, b+1))
        elif fmt == 12:
            ngroups = struct.unpack('>I', data[s+12:s+16])[0]
            for g in range(ngroups):
                gp = s + 16 + g*12
                a, b, _ = struct.unpack('>III', data[gp:gp+12])
                if b - a > 60000:
                    continue
                cps.update(range(a, b+1))
    return cps

for path in sys.argv[1:]:
    data, tables = read_tables(path)
    cps = cmap_codepoints(data, tables)
    han = [c for c in cps if 0x4E00 <= c <= 0x9FFF]
    ascii_ = [c for c in cps if 32 <= c <= 126]
    print('%-46s size=%7d  glyphs=%6d  CJK=%5d  ASCII=%3d  tables=%d'
          % (os.path.basename(path), len(data), len(cps), len(han), len(ascii_), len(tables)))
    if '-v' in os.environ.get('CMAP_VERBOSE', ''):
        print('   ', ''.join(chr(c) for c in sorted(han))[:400])
