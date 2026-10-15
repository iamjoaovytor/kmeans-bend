# Referencia do kmeans.bend em Python, com aritmetica F32 e a mesma ordem de somas (arvore).
import struct, sys

M = 2**32
def f(x): return struct.unpack("f", struct.pack("f", x))[0]

def rnd(h):
    a = (h * 2654435761) % M
    b = a ^ (a >> 15)
    z = (b * 2246822519) % M
    return f(((z ^ (z >> 13)) & 65535) / 65536.0)

def ponto(i, modo, semente=0):
    s = semente
    ux, uy = rnd((i * 2 + 11 + s * 1000003) % M), rnd((i * 2 + 12 + s * 1000003) % M)
    if modo == 1:
        return f(ux * 100.0), f(uy * 100.0)
    b = i % 8
    cx, cy = f(rnd((b * 7 + 1 + s * 7919) % M) * 100.0), f(rnd((b * 7 + 3 + s * 7919) % M) * 100.0)
    return f(cx + f(f(ux - 0.5) * 12.0)), f(cy + f(f(uy - 0.5) * 12.0))

def mais_perto(cs, x, y):
    bj, bd = 0, 1.0e30
    for j, (cx, cy) in enumerate(cs):
        dx, dy = f(x - cx), f(y - cy)
        dd = f(f(dx * dx) + f(dy * dy))
        if dd < bd: bj, bd = j, dd
    return bj

def custo(pts, lo, hi, cs):
    # J: soma das distancias ao quadrado ao centro mais perto, na mesma ordem de somas da arvore.
    if hi - lo == 1:
        x, y = pts[lo]; bd = 1.0e30
        for cx, cy in cs:
            dx, dy = f(x - cx), f(y - cy); dd = f(f(dx * dx) + f(dy * dy))
            if dd < bd: bd = dd
        return bd
    m = (lo + hi) // 2
    return f(custo(pts, lo, m, cs) + custo(pts, m, hi, cs))

def somar(pts, lo, hi, cs):
    if hi - lo == 1:
        x, y = pts[lo]; j = mais_perto(cs, x, y)
        return [(x, y, 1) if i == j else (0.0, 0.0, 0) for i in range(len(cs))]
    m = (lo + hi) // 2
    a, b = somar(pts, lo, m, cs), somar(pts, m, hi, cs)
    return [(f(p[0] + q[0]), f(p[1] + q[1]), p[2] + q[2]) for p, q in zip(a, b)]

def kmeans(d, k, modo, maxit, semente=0, historico=None):
    n = 2**d
    pts = [ponto(i, modo, semente) for i in range(n)]
    cs = [ponto(i, modo, semente) for i in range(k)]
    it = 0
    for _ in range(maxit):
        if historico is not None: historico.append(custo(pts, 0, n, cs))
        acc = somar(pts, 0, n, cs)
        novo = [old if c == 0 else (f(sx / f(c)), f(sy / f(c))) for (sx, sy, c), old in zip(acc, cs)]
        mov = 0.0
        for (a, b), (c, e) in zip(novo, cs):
            dx, dy = f(a - c), f(b - e)
            mov = f(f(f(dx * dx) + f(dy * dy)) + mov)
        cs, it = novo, it + 1
        if mov < 0.000001: break
    return it, cs

if __name__ == "__main__":
    d, k, modo, maxit = (int(a) for a in sys.argv[1:5])
    it, cs = kmeans(d, k, modo, maxit)
    print(f"iteracoes: {it}")
    print("centroides:" + "".join(f" ({x:.4f}, {y:.4f})" for x, y in cs))
