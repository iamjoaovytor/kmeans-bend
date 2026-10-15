# Caso medio empirico: iteracoes ate convergir em 200 conjuntos de dados aleatorios de cada tipo
# (n = 2^14 pontos, k = 8), e a curva do custo J numa execucao tipica.
import re, statistics, subprocess

def rodar(modo, semente, hist=0):
    out = subprocess.run(["./kmeans", "14", "8", str(modo), "1000", str(semente), str(hist), "--threads", "12"],
                         capture_output=True, text=True, check=True).stdout
    it = int(re.search(r"iteracoes: (\d+)", out).group(1))
    j = [float(v) for v in out.split("custo J por iteracao:")[1].split()]
    return it, j

with open("iteracoes.csv", "w") as f:
    f.write("modo,semente,iteracoes\n")
    for modo, nome in ((0, "com grupos"), (1, "uniformes")):
        its = []
        for s in range(1, 201):
            it, _ = rodar(modo, s)
            its.append(it); f.write(f"{modo},{s},{it}\n")
        print(f"{nome}: media {statistics.mean(its):.1f}, desvio {statistics.stdev(its):.1f}, "
              f"mediana {statistics.median(its)}, min {min(its)}, max {max(its)}, "
              f"atingiu limite 1000: {sum(i >= 1000 for i in its)}")

its1 = sorted((it, s) for s, it in ((s, rodar(1, s)[0]) for s in range(1, 21)))
it, s = its1[len(its1) // 2]
_, j = rodar(1, s, 1)
with open("custo_j.csv", "w") as f:
    f.write("iteracao,J\n")
    for i, v in enumerate(j, 1): f.write(f"{i},{v}\n")
print(f"curva J: semente {s}, {it} iteracoes, J de {j[0]:.0f} para {j[-1]:.0f}, sempre cai: {all(b <= a for a, b in zip(j, j[1:]))}")
