# Gera as figuras SVG do relatorio a partir dos CSVs medidos em dados/.
import csv, math, os, statistics

AQUI = os.path.dirname(os.path.abspath(__file__))
DADOS = os.path.join(os.path.dirname(AQUI), "dados")
TINTA, FRACA, GRADE = "#073642", "#586e75", "#e4dcc3"
AZUL, VIOLETA, LARANJA = "#268bd2", "#6c71c4", "#cb4b16"
FONTE = 'font-family="Libertinus Serif" font-size="9"'
W, H = 300, 190
X0, X1, Y0, Y1 = 34, 288, 160, 12  # area do grafico

def blocos(nome):
    # Le um CSV com varios blocos "# titulo" separados por linha em branco.
    out, atual = {}, None
    for linha in open(os.path.join(DADOS, nome)):
        linha = linha.strip()
        if linha.startswith("#"): atual = linha[1:].strip(); out[atual] = []
        elif linha and atual: out[atual].append(linha.split(","))
    return {k: (v[0], v[1:]) for k, v in out.items()}

def svg(corpo):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">{corpo}</svg>'

def texto(x, y, s, anc="start", cor=FRACA, extra=""):
    return f'<text x="{x:.1f}" y="{y:.1f}" {FONTE} fill="{cor}" text-anchor="{anc}" {extra}>{s}</text>'

XL = 226  # fim da area dos graficos de linha; o resto fica para os rotulos

def eixos_log(xs, ymin, ymax, ylabels, xlabels, ytitulo):
    lx = lambda v: X0 + (math.log2(v) - math.log2(xs[0])) / (math.log2(xs[-1]) - math.log2(xs[0])) * (XL - X0)
    ly = lambda v: Y0 - (math.log10(v) - math.log10(ymin)) / (math.log10(ymax) - math.log10(ymin)) * (Y0 - Y1)
    c = ""
    for v, s in ylabels:
        c += f'<line x1="{X0}" y1="{ly(v):.1f}" x2="{XL}" y2="{ly(v):.1f}" stroke="{GRADE}" stroke-width="0.6"/>'
        c += texto(X0 - 4, ly(v) + 3, s, "end")
    for v, s in xlabels:
        c += texto(lx(v), Y0 + 12, s, "middle")
    c += f'<line x1="{X0}" y1="{Y0}" x2="{XL}" y2="{Y0}" stroke="{FRACA}" stroke-width="0.8"/>'
    c += texto(X0, Y1 - 3, ytitulo, "start", TINTA)
    return c, lx, ly

def serie(pts, lx, ly, cor, rotulo, tracejado=""):
    d = " ".join(f"{lx(x):.1f},{ly(y):.1f}" for x, y in pts)
    c = f'<polyline points="{d}" fill="none" stroke="{cor}" stroke-width="1.6" {tracejado}/>'
    for x, y in pts: c += f'<circle cx="{lx(x):.1f}" cy="{ly(y):.1f}" r="2" fill="{cor}"/>'
    x, y = pts[-1]
    return c, (lx(x), ly(y), rotulo, cor)

def rotulos(lista):
    # Rotulos diretos a esquerda do ultimo ponto, afastados para nao se sobrepor.
    lista = sorted(lista, key=lambda t: t[1]); c = ""; ultimo = -99
    for x, y, s, cor in lista:
        y = max(y + 3, ultimo + 11); ultimo = y
        c += texto(x + 6, y, s, "start", cor, 'font-weight="bold"')
    return c

def fig_n():
    v2, gpu, v1 = blocos("resultados.csv"), blocos("resultados_gpu.csv"), blocos("resultados_v1.csv")
    _, a = v2["custo por iteracao, k = 8"]; _, g = gpu["custo por iteracao na GPU, k = 8"]
    xs = [int(r[0]) for r in a]
    c, lx, ly = eixos_log(xs, 0.2, 120, [(0.3, "0,3"), (1, "1"), (3, "3"), (10, "10"), (30, "30"), (100, "100")],
                          [(16384, "16 mil"), (65536, "65 mil"), (262144, "262 mil"), (1048576, "1 mi")], "ms por iteração (escala log)")
    s1, r1 = serie([(int(r[0]), float(r[1])) for r in a], lx, ly, AZUL, "1 núcleo")
    s2, r2 = serie([(int(r[0]), float(r[2])) for r in a], lx, ly, VIOLETA, "12 núcleos")
    s3, r3 = serie([(int(r[0]), float(r[1])) for r in g], lx, ly, LARANJA, "GPU", 'stroke-dasharray="3 2"')
    return svg(c + s1 + s2 + s3 + rotulos([r1, r2, r3]) + texto((X0 + XL) / 2, H - 4, "n pontos (k = 8, escala log)", "middle"))

def fig_k():
    v2, v1 = blocos("resultados.csv"), blocos("resultados_v1.csv")
    _, a = v2["custo por iteracao, n = 2^17, 1 thread"]; _, b = v1["custo por iteracao, n = 2^17, 1 thread"]
    ks = [int(r[0]) for r in a]
    c, lx, ly = eixos_log(ks, 1.5, 150, [(2, "2"), (5, "5"), (10, "10"), (20, "20"), (50, "50"), (100, "100")],
                          [(k, str(k)) for k in ks], "ms por iteração (escala log)")
    s1, r1 = serie([(int(r[0]), float(r[1])) for r in b], lx, ly, LARANJA, "antes", 'stroke-dasharray="3 2"')
    s2, r2 = serie([(int(r[0]), float(r[1])) for r in a], lx, ly, AZUL, "depois")
    return svg(c + s1 + s2 + rotulos([r1, r2]) + texto((X0 + XL) / 2, H - 4, "k grupos (n = 131 mil, 1 núcleo)", "middle"))

def fig_hist():
    rows = list(csv.DictReader(open(os.path.join(DADOS, "iteracoes.csv"))))
    c = ""; bw = (X1 - X0) / 16
    for i, (modo, cor, base, nome) in enumerate((("0", VIOLETA, 82, "com grupos"), ("1", LARANJA, 160, "uniformes"))):
        its = [int(r["iteracoes"]) for r in rows if r["modo"] == modo]
        caixas = [0] * 16
        for v in its: caixas[min(v // 10, 15)] += 1
        c += f'<line x1="{X0}" y1="{base}" x2="{X1}" y2="{base}" stroke="{FRACA}" stroke-width="0.8"/>'
        for j, n in enumerate(caixas):
            if n: h = n * 62 / 102; c += f'<rect x="{X0 + j * bw + 1:.1f}" y="{base - h:.1f}" width="{bw - 2:.1f}" height="{h:.1f}" fill="{cor}"/>'
        m = statistics.mean(its); xm = X0 + m / 10 * bw
        c += f'<line x1="{xm:.1f}" y1="{base - 66}" x2="{xm:.1f}" y2="{base}" stroke="{TINTA}" stroke-width="0.8" stroke-dasharray="2 2"/>'
        c += texto(X1, base - 56, f"{nome}: média {m:.0f}, desvio {statistics.stdev(its):.0f}", "end", TINTA)
    for v in (0, 50, 100, 150): c += texto(X0 + v / 10 * bw, 172, str(v) + ("+" if v == 150 else ""), "middle")
    c += texto((X0 + X1) / 2, H - 4, "iterações até parar (200 conjuntos de cada tipo)", "middle")
    return svg(c)

def fig_j():
    j = [float(r["J"]) for r in csv.DictReader(open(os.path.join(DADOS, "custo_j.csv")))]
    lx = lambda i: X0 + i / (len(j) - 1) * (X1 - X0)
    ly = lambda v: Y0 - v / 8e6 * (Y0 - Y1)
    c = ""
    for v in (0, 2e6, 4e6, 6e6, 8e6):
        c += f'<line x1="{X0}" y1="{ly(v):.1f}" x2="{X1}" y2="{ly(v):.1f}" stroke="{GRADE}" stroke-width="0.6"/>'
        c += texto(X0 - 4, ly(v) + 3, f"{v / 1e6:.0f} mi", "end")
    c += f'<polyline points="{" ".join(f"{lx(i):.1f},{ly(v):.1f}" for i, v in enumerate(j))}" fill="none" stroke="{AZUL}" stroke-width="1.6"/>'
    c += f'<circle cx="{lx(0):.1f}" cy="{ly(j[0]):.1f}" r="2.2" fill="{AZUL}"/><circle cx="{lx(len(j) - 1):.1f}" cy="{ly(j[-1]):.1f}" r="2.2" fill="{AZUL}"/>'
    c += texto(lx(8), ly(j[1]) - 10, f"−{100 * (1 - j[1] / j[0]):.0f}% na 1ª iteração", "start", TINTA)
    c += texto(X0, Y1 - 3, "custo J", "start", TINTA)
    c += texto((X0 + X1) / 2, H - 4, f"iteração (1 a {len(j)}); 16 mil pontos uniformes, k = 8", "middle")
    return svg(c)

for nome, f in (("fig_n.svg", fig_n), ("fig_k.svg", fig_k), ("fig_hist.svg", fig_hist), ("fig_j.svg", fig_j)):
    open(os.path.join(AQUI, nome), "w").write(f())
    print("gerado", nome)
