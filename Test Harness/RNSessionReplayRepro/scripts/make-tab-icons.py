# Generates the outline tab bar icons in src/assets (25pt template images at 1x-3x).
# Plain stdlib so it runs anywhere: python3 scripts/make-tab-icons.py
import math, os, struct, zlib

OUT = os.path.join(os.path.dirname(__file__), '..', 'src', 'assets')

def png(path, size, inside):
    rows = []
    for y in range(size):
        row = bytearray([0])
        for x in range(size):
            a = 255 if inside((x + 0.5) / size, (y + 0.5) / size, 2.2 / 25) else 0
            row += bytes([0, 0, 0, a])
        rows.append(bytes(row))
    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)
    data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
    data += chunk(b'IDAT', zlib.compress(b''.join(rows))) + chunk(b'IEND', b'')
    open(path, 'wb').write(data)

def ring(cx, cy, r):
    return lambda x, y, w: abs(math.hypot(x - cx, y - cy) - r) < w / 2

def box(x0, y0, x1, y1):
    def f(x, y, w):
        inside = x0 - w / 2 <= x <= x1 + w / 2 and y0 - w / 2 <= y <= y1 + w / 2
        core = x0 + w / 2 < x < x1 - w / 2 and y0 + w / 2 < y < y1 - w / 2
        return inside and not core
    return f

def union(*fs):
    return lambda x, y, w: any(f(x, y, w) for f in fs)

ICONS = {
    'discover': ring(0.5, 0.5, 0.38),
    'shop': union(box(0.16, 0.16, 0.84, 0.84), box(0.36, 0.36, 0.64, 0.64)),
    'favorites': union(ring(0.36, 0.4, 0.17), ring(0.64, 0.4, 0.17)),
    'bag': union(box(0.18, 0.34, 0.82, 0.86), ring(0.5, 0.34, 0.16)),
    'account': union(ring(0.5, 0.34, 0.16), box(0.22, 0.62, 0.78, 0.9)),
}

for name, shape in ICONS.items():
    for scale, suffix in ((1, ''), (2, '@2x'), (3, '@3x')):
        png(os.path.join(OUT, f'tab-{name}{suffix}.png'), 25 * scale, shape)
print('wrote', len(ICONS) * 3, 'icons to', os.path.normpath(OUT))
