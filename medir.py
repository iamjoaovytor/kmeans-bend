# Mede o kmeans: custo por iteracao (variando n, k e threads) e numero de iteracoes por tipo de dado.
import re, subprocess, time

def tempo(args, reps=3):
    melhor, out = None, ""
    for _ in range(reps):
        t0 = time.perf_counter()
        out = subprocess.run(["./kmeans", *map(str, args)], capture_output=True, text=True, check=True).stdout
        dt = time.perf_counter() - t0
        melhor = dt if melhor is None else min(melhor, dt)
    return melhor, out

def por_iteracao(d, k, threads):
    # (tempo com 20 iteracoes - tempo com 10) / 10: tira o custo de gerar os pontos.
    extra = ["--gpu", "off", "--threads", threads]
    t10, _ = tempo([d, k, 1, 10, *extra])
    t20, _ = tempo([d, k, 1, 20, *extra])
    return (t20 - t10) / 10

print("# custo por iteracao, k = 8")
print("n,ms_1_thread,ms_12_threads,ganho")
for d in range(14, 21):
    a, b = por_iteracao(d, 8, 1), por_iteracao(d, 8, 12)
    print(f"{2**d},{a*1000:.2f},{b*1000:.2f},{a/b:.1f}", flush=True)

print("\n# custo por iteracao, n = 2^17, 1 thread")
print("k,ms")
for k in [2, 4, 8, 16, 32]:
    print(f"{k},{por_iteracao(17, k, 1)*1000:.2f}", flush=True)

print("\n# iteracoes ate convergir, k = 8")
print("n,agrupados,uniformes")
for d in range(10, 19, 2):
    its = []
    for modo in (0, 1):
        _, out = tempo([d, 8, modo, 1000, "--threads", 12], reps=1)
        its.append(re.search(r"iteracoes: (\d+)", out).group(1))
    print(f"{2**d},{its[0]},{its[1]}", flush=True)
