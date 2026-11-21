"""lz.py - the packer for Stronkie's RC Cup (unpacked in the game by unlz in src/rc.s).

Format, a stream of tokens:
  $00-$7f n          n+1 literal bytes follow
  $80-$fe n, hi, lo  copy (n & $7f) + 3 bytes from offset hi<<8|lo (1..65535) back
  $ff lh, ll, hi, lo  copy lh<<8|ll bytes (130..65535) from offset hi<<8|lo back
"""
import numpy as np

def pack(data):
    data = bytes(data); n = len(data)
    out = bytearray(); lit = bytearray()
    head = {}
    MAXM = 65535
    def flush():
        nonlocal lit
        while lit:
            ch = lit[:128]; lit = lit[128:]
            out.append(len(ch) - 1); out.extend(ch)
    def insert(p):
        if p + 3 <= n:
            k = data[p:p + 3]
            lst = head.get(k)
            if lst is None: head[k] = [p]
            else:
                lst.append(p)
                if len(lst) > 48: del lst[:16]
    i = 0
    while i < n:
        best = 0; boff = 0
        if i + 3 <= n:
            for p in reversed(head.get(data[i:i + 3], ())):
                off = i - p
                if off > 65535: break
                l = 3
                lim = min(MAXM, n - i)
                if data[p + best:p + best + 1] != data[i + best:i + best + 1] and best: continue
                while l < lim and data[p + l] == data[i + l]: l += 1
                if l > best:
                    best = l; boff = off
                    if l == lim: break
        if best >= 3:
            flush()
            if best <= 129: out.append(0x80 | (best - 3))
            else: out += bytes([0xff, best >> 8, best & 255])
            out.append(boff >> 8); out.append(boff & 255)
            for k in range(best): insert(i + k)
            i += best
        else:
            lit.append(data[i]); insert(i); i += 1
    flush()
    return bytes(out)

def unpack(src, size):
    out = bytearray(); i = 0
    while len(out) < size:
        t = src[i]; i += 1
        if t < 128:
            out += src[i:i + t + 1]; i += t + 1
        else:
            if t == 0xff: l = (src[i] << 8) | src[i + 1]; i += 2
            else: l = (t & 127) + 3
            off = (src[i] << 8) | src[i + 1]; i += 2
            for _ in range(l): out.append(out[-off])
    return bytes(out)

if __name__ == '__main__':
    import os
    d = os.urandom(300) * 50 + bytes(5000) + b'abcabcabd' * 300
    p = pack(d); assert unpack(p, len(d)) == d; print(len(d), '->', len(p))
