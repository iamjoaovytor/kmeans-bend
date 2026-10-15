# Confere o kmeans compilado contra referencia.py: iteracoes e centroides.
import os, re, subprocess, sys
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BIN = os.path.join(RAIZ, "kmeans")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from referencia import kmeans

casos = [(10, 8, 0, 0), (12, 4, 0, 0), (12, 8, 1, 0), (13, 16, 0, 0), (14, 8, 1, 0), (14, 3, 0, 0),
         (10, 8, 1, 3), (12, 8, 0, 7), (13, 5, 1, 42), (12, 16, 1, 99)]
ok = True
for d, k, modo, sem in casos:
    out = subprocess.run([BIN, str(d), str(k), str(modo), "200", str(sem), "1"], capture_output=True, text=True, check=True).stdout
    it = int(re.search(r"iteracoes: (\d+)", out).group(1))
    cs = [tuple(map(float, p)) for p in re.findall(r"\(([-\d.e]+), ([-\d.e]+)\)", out)]
    hist_ref = []
    it_ref, cs_ref = kmeans(d, k, modo, 200, sem, hist_ref)
    hist = [float(v) for v in out.split("custo J por iteracao:")[1].split()]
    erro_j = max(abs(a - b) / b for a, b in zip(hist, hist_ref)) if hist else 1.0
    cai = all(b <= a for a, b in zip(hist, hist[1:]))
    erro = max(max(abs(a - c), abs(b - e)) for (a, b), (c, e) in zip(cs, cs_ref))
    certo = it == it_ref and erro < 1e-3 and len(hist) == len(hist_ref) and erro_j < 1e-4 and cai
    ok &= certo
    print(f"n=2^{d} k={k} modo={modo} semente={sem}: bend {it} iter, python {it_ref} iter, erro {erro:.1e}, J erro rel {erro_j:.1e}, J so cai: {cai}  {'OK' if certo else 'DIFERENTE'}")
print("tudo certo" if ok else "FALHOU")
