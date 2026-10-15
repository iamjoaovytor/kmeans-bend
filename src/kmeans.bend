# K-means em 2D: n = 2^d pontos numa arvore, k centroides.
# ./kmeans <d> <k> <modo> <max_iter> <semente> <historico>
#   modo 0 = 8 grupos, modo 1 = uniforme; historico 1 imprime a soma das distancias por iteracao
import Base
import ./args.bend as A

type Pts is Data:
  PLeaf{x: F32, y: F32}
  PNode{l: Pts, r: Pts}

# Um centroide.
type C is Data:
  C{x: F32, y: F32}

# Soma de x, soma de y e quantidade de pontos de um grupo.
type Acc is Data:
  Acc{sx: F32, sy: F32, c: U32}

# Numero pseudoaleatorio em [0, 1) a partir de um inteiro.
def rnd(+h: U32) -> F32:
  +a = (h * 2654435761 : U32)
  b = (a .^. (a >> 15n) : U32)
  +z = (b * 2246822519 : U32)
  m = ((z .^. (z >> 13n)) .&. 65535 : U32)
  (U32.to_f32(m) / 65536.0 : F32)

# Ponto i: no modo 0, em volta de um de 8 centros; no modo 1, uniforme.
# m = modo + 2 * semente; a semente desloca o gerador, e semente 0 reproduz os dados originais.
def point_x(+i: U32, +m: U32) -> F32:
  +s = (m >> 1n : U32)
  b = (i % 8 : U32)
  centro = (rnd((b * 7 + 1 + s * 7919 : U32)) * 100.0 : F32)
  +u = rnd((i * 2 + 11 + s * 1000003 : U32))
  Bool.pick(F32, U32.is_eq((m .&. 1 : U32), 0), (centro + (u - 0.5) * 12.0 : F32), (u * 100.0 : F32))

def point_y(+i: U32, +m: U32) -> F32:
  +s = (m >> 1n : U32)
  b = (i % 8 : U32)
  centro = (rnd((b * 7 + 3 + s * 7919 : U32)) * 100.0 : F32)
  +u = rnd((i * 2 + 12 + s * 1000003 : U32))
  Bool.pick(F32, U32.is_eq((m .&. 1 : U32), 0), (centro + (u - 0.5) * 12.0 : F32), (u * 100.0 : F32))

def gen(+d: Nat, +i: U32, +modo: U32) -> Pts:
  match d:
    case 0n:
      PLeaf{point_x(i, modo), point_y(i, modo)}
    case 1n+p:
      w = (1 << p : U32)
      a b = gen(p, i, modo) gen(p, (i + w : U32), modo)
      PNode{a, b}

# Centroides iniciais: os k primeiros pontos.
def init(+k: Nat, +i: U32, +modo: U32) -> List<&2, C>:
  match k:
    case 0n:
      Nil{}
    case 1n+p:
      Con{C{point_x(i, modo), point_y(i, modo)}, init(p, (i + 1 : U32), modo)}

def dist(h: C, +x: F32, +y: F32) -> F32:
  match h:
    case C{+cx, +cy}:
      ((x - cx) * (x - cx) + (y - cy) * (y - cy) : F32)

# Operacao basica: uma distancia por centroide; guarda o indice (bj) e a distancia (bd) do melhor.
def nearest(cs: List<&2, C>, +x: F32, +y: F32, +j: U32, +bj: U32, +bd: F32) -> U32:
  match cs:
    case Nil{}:
      bj
    case Con{h, t}:
      +dd = dist(h, x, y)
      +lt = (dd < bd : F32)
      nearest(t, x, y, (j + 1 : U32), Bool.pick(U32, lt, j, bj), Bool.pick(F32, lt, dd, bd))

# Somas por grupo numa arvore indexada pelo numero do grupo (b = bits de k).
# Vazio = nenhum ponto daquele lado: juntar com Vazio nao custa nada.
type Sums is Data:
  Vazio{}
  Folha{sx: F32, sy: F32, c: U32}
  No{l: Sums, r: Sums}

def lado(esq: Bool, filho: Sums) -> Sums:
  match esq:
    case True{}:
      No{filho, Vazio{}}
    case False{}:
      No{Vazio{}, filho}

# So o caminho ate o grupo j: b nos em vez de k.
def caminho(+b: Nat, +j: U32, +x: F32, +y: F32) -> Sums:
  match b:
    case 0n:
      Folha{x, y, 1}
    case 1n+p:
      lado(U32.is_eq(((j >> p) .&. 1 : U32), 0), caminho(p, j, x, y))

def juntar(a: Sums, b: Sums) -> Sums:
  match a b:
    case Vazio{} t:
      t
    case t Vazio{}:
      t
    case Folha{x1, y1, c1} Folha{x2, y2, c2}:
      Folha{(x1 + x2 : F32), (y1 + y2 : F32), (c1 + c2 : U32)}
    case No{l1, r1} No{l2, r2}:
      No{juntar(l1, l2), juntar(r1, r2)}
    case _ _:
      Vazio{}

# Achata a arvore de somas numa lista, na ordem dos grupos.
def zeros(+b: Nat, rest: List<Acc>) -> List<Acc>:
  match b:
    case 0n:
      Con{Acc{0.0, 0.0, 0}, rest}
    case 1n+p:
      zeros(p, zeros(p, rest))

def achatar(+b: Nat, t: Sums, rest: List<Acc>) -> List<Acc>:
  match b t:
    case _ Vazio{}:
      zeros(b, rest)
    case _ Folha{x, y, c}:
      Con{Acc{x, y, c}, rest}
    case 1n+p No{l, r}:
      achatar(p, l, achatar(p, r, rest))
    case _ _:
      rest

# Uma iteracao: cada ponto acha o centroide mais perto; somas sobem pela arvore.
def assign(+pts: Pts, +cs: List<&2, C>, +b: Nat) -> Sums:
  match pts:
    case PLeaf{+x, +y}:
      caminho(b, nearest(cs, x, y, 0, 0, 1.0e30), x, y)
    case PNode{l, r}:
      e d = assign(l, cs, b) assign(r, cs, b)
      juntar(e, d)

# Novo centroide = media do grupo; grupo vazio mantem o antigo.
def mean(a: Acc, old: C) -> C:
  match a:
    case Acc{sx, sy, +c}:
      +n = U32.to_f32(c)
      Bool.pick(C, U32.is_eq(c, 0), old, C{(sx / n : F32), (sy / n : F32)})

def update(acc: List<Acc>, old: List<&2, C>) -> List<&2, C>:
  match acc old:
    case Con{a, t} Con{o, u}:
      Con{mean(a, o), update(t, u)}
    case _ _:
      Nil{}

# Soma das distancias ao quadrado de cada ponto ao centro mais perto (o custo J que o k-means reduz).
def menor(cs: List<&2, C>, +x: F32, +y: F32, +bd: F32) -> F32:
  match cs:
    case Nil{}:
      bd
    case Con{h, t}:
      +dd = dist(h, x, y)
      menor(t, x, y, Bool.pick(F32, (dd < bd : F32), dd, bd))

def sse(+pts: Pts, +cs: List<&2, C>) -> F32:
  match pts:
    case PLeaf{+x, +y}:
      menor(cs, x, y, 1.0e30)
    case PNode{l, r}:
      a b = sse(l, cs) sse(r, cs)
      (a + b : F32)

def registra(hist: Bool, +pts: Pts, +cs: List<&2, C>, xs: List<&2, F32>) -> List<&2, F32>:
  match hist:
    case False{}:
      xs
    case True{}:
      Con{sse(pts, cs), xs}

# Quanto os centroides andaram (soma das distancias ao quadrado).
def moved(a: List<&2, C>, b: List<&2, C>) -> F32:
  match a b:
    case Con{C{+x1, +y1}, t} Con{C{+x2, +y2}, u}:
      ((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2) + moved(t, u) : F32)
    case _ _:
      0.0

# Repete ate os centroides pararem ou acabar o limite de iteracoes.
def run(+fuel: Nat, stop: Bool, +pts: Pts, +b: Nat, +cs: List<&2, C>, +it: U32, +hist: Bool, xs: List<&2, F32>) -> List<&2, C> & (U32 & List<&2, F32>):
  match fuel stop:
    case _ True{}:
      (cs, (it, xs))
    case 0n _:
      (cs, (it, xs))
    case 1n+p False{}:
      +novo = update(achatar(b, assign(pts, cs, b), Nil{}), cs)
      run(p, (moved(novo, cs) < 0.000001 : F32), pts, b, novo, (it + 1 : U32), hist, registra(hist, pts, cs, xs))

def show_cs(cs: List<&2, C>) -> String:
  match cs:
    case Nil{}:
      ""
    case Con{C{x, y}, t}:
      " (" ++ F32.show(x) ++ ", " ++ F32.show(y) ++ ")" ++ show_cs(t)

def show_fs(xs: List<&2, F32>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{x, t}:
      " " ++ F32.show(x) ++ show_fs(t)

def rev(xs: List<&2, F32>, acc: List<&2, F32>) -> List<&2, F32>:
  match xs:
    case Nil{}:
      acc
    case Con{x, t}:
      rev(t, Con{x, acc})

def report(r: List<&2, C> & (U32 & List<&2, F32>), +n: U32, +k: U32) -> IO(Unit):
  (cs, r2) = r
  (+it, xs) = r2
  do IO<Unit>:
    IO.print("iteracoes: " ++ U32.show(it) ++ "  distancias: " ++ U32.show((it * n * k : U32)))
    IO.print("centroides:" ++ show_cs(cs))
    IO.print("custo J por iteracao:" ++ show_fs(rev(xs, Nil{})))

# Quantidade de bits de v (para indexar k grupos).
def bits(+f: Nat, +v: U32) -> U32:
  match f:
    case 0n:
      0
    case 1n+p:
      (Bool.to_u32((v > 0 : U32)) + bits(p, (v >> 1n : U32)) : U32)

def go(+d: U32, +k: U32, +modo: U32, +maxit: U32, +seed: U32, +hist: U32) -> IO(Unit):
  +dn = U32.to_nat(d)
  +kn = U32.to_nat(k)
  +m = (modo + seed * 2 : U32)
  +pts = gen(dn, 0, m)
  +b = U32.to_nat(bits(32n, (k - 1 : U32)))
  report(run(U32.to_nat(maxit), False{}, pts, b, init(kn, 0, m), 0, U32.is_eq(hist, 1), Nil{}), (1 << dn : U32), k)

# Argumentos numericos; o que nao for numero vira o valor padrao.
def num(h: String) -> U32:
  A.or_default(U32.read(h), 4294967295)

def nums(xs: List<String>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{num(h), nums(t)}

def nth(xs: List<&2, U32>, +i: Nat, +dflt: U32) -> U32:
  match xs i:
    case Con{+v, _} 0n:
      Bool.pick(U32, U32.is_eq(v, 4294967295), dflt, v)
    case Con{_, t} 1n+p:
      nth(t, p, dflt)
    case _ _:
      dflt

def start(+ns: List<&2, U32>) -> IO(Unit):
  go(nth(ns, 0n, 16), nth(ns, 1n, 8), nth(ns, 2n, 0), nth(ns, 3n, 100), nth(ns, 4n, 0), nth(ns, 5n, 0))

def main() -> IO(Unit):
  do IO<Unit>:
    all : List<String> <- IO.args()
    start(nums(A.rest(all)))
