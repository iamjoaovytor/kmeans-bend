# K-means em 2D: n = 2^d pontos numa arvore, k centroides.
# ./kmeans <d> <k> <modo> <max_iter>   modo 0 = 8 grupos, modo 1 = uniforme
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
def point_x(+i: U32, +modo: U32) -> F32:
  b = (i % 8 : U32)
  centro = (rnd((b * 7 + 1 : U32)) * 100.0 : F32)
  ruido = (rnd((i * 2 + 11 : U32)) - 0.5 : F32)
  Bool.pick(F32, U32.is_eq(modo, 0), (centro + ruido * 12.0 : F32), (rnd((i * 2 + 11 : U32)) * 100.0 : F32))

def point_y(+i: U32, +modo: U32) -> F32:
  b = (i % 8 : U32)
  centro = (rnd((b * 7 + 3 : U32)) * 100.0 : F32)
  ruido = (rnd((i * 2 + 12 : U32)) - 0.5 : F32)
  Bool.pick(F32, U32.is_eq(modo, 0), (centro + ruido * 12.0 : F32), (rnd((i * 2 + 12 : U32)) * 100.0 : F32))

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

# Escolhe o mais perto entre o melhor ate agora e o centroide j.
def pick(h: C, +x: F32, +y: F32, +j: U32, best: U32 & F32) -> U32 & F32:
  match h:
    case C{+cx, +cy}:
      (bj, +bd) = best
      +dd = ((x - cx) * (x - cx) + (y - cy) * (y - cy) : F32)
      Bool.pick((U32 & F32), (dd < bd : F32), (j, dd), (bj, bd))

def fst(p: U32 & F32) -> U32:
  (a, b) = p
  a

# Operacao basica: uma distancia por centroide.
def nearest(cs: List<&2, C>, +x: F32, +y: F32, +j: U32, best: U32 & F32) -> U32:
  match cs:
    case Nil{}:
      fst(best)
    case Con{h, t}:
      nearest(t, x, y, (j + 1 : U32), pick(h, x, y, j, best))

# Acumulador com o ponto so na posicao j.
def onehot(+k: Nat, +i: U32, +j: U32, +x: F32, +y: F32) -> List<Acc>:
  match k:
    case 0n:
      Nil{}
    case 1n+p:
      a = Bool.pick(Acc, U32.is_eq(i, j), Acc{x, y, 1}, Acc{0.0, 0.0, 0})
      Con{a, onehot(p, (i + 1 : U32), j, x, y)}

def add1(a: Acc, b: Acc) -> Acc:
  match a b:
    case Acc{x1, y1, c1} Acc{x2, y2, c2}:
      Acc{(x1 + x2 : F32), (y1 + y2 : F32), (c1 + c2 : U32)}

def add(a: List<Acc>, b: List<Acc>) -> List<Acc>:
  match a b:
    case Con{h1, t1} Con{h2, t2}:
      Con{add1(h1, h2), add(t1, t2)}
    case _ _:
      Nil{}

# Uma iteracao: cada ponto acha o centroide mais perto; somas sobem pela arvore.
def assign(+pts: Pts, +cs: List<&2, C>, +k: Nat) -> List<Acc>:
  match pts:
    case PLeaf{+x, +y}:
      onehot(k, 0, nearest(cs, x, y, 0, (0, 1.0e30)), x, y)
    case PNode{l, r}:
      a b = assign(l, cs, k) assign(r, cs, k)
      add(a, b)

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

# Quanto os centroides andaram (soma das distancias ao quadrado).
def moved(a: List<&2, C>, b: List<&2, C>) -> F32:
  match a b:
    case Con{C{+x1, +y1}, t} Con{C{+x2, +y2}, u}:
      ((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2) + moved(t, u) : F32)
    case _ _:
      0.0

# Repete ate os centroides pararem ou acabar o limite de iteracoes.
def run(+fuel: Nat, stop: Bool, +pts: Pts, +k: Nat, +cs: List<&2, C>, +it: U32) -> List<&2, C> & U32:
  match fuel stop:
    case _ True{}:
      (cs, it)
    case 0n _:
      (cs, it)
    case 1n+p False{}:
      +novo = update(assign(pts, cs, k), cs)
      run(p, (moved(novo, cs) < 0.000001 : F32), pts, k, novo, (it + 1 : U32))

def show_cs(cs: List<&2, C>) -> String:
  match cs:
    case Nil{}:
      ""
    case Con{C{x, y}, t}:
      " (" ++ F32.show(x) ++ ", " ++ F32.show(y) ++ ")" ++ show_cs(t)

def report(r: List<&2, C> & U32, +n: U32, +k: U32) -> IO(Unit):
  (cs, +it) = r
  do IO<Unit>:
    IO.print("iteracoes: " ++ U32.show(it) ++ "  distancias: " ++ U32.show((it * n * k : U32)))
    IO.print("centroides:" ++ show_cs(cs))

def go(+d: U32, +k: U32, +modo: U32, +maxit: U32) -> IO(Unit):
  +dn = U32.to_nat(d)
  +kn = U32.to_nat(k)
  +pts = gen(dn, 0, modo)
  report(run(U32.to_nat(maxit), False{}, pts, kn, init(kn, 0, modo), 0), (1 << dn : U32), k)

def args3(xs: List<String>) -> U32 & (U32 & U32):
  match xs:
    case Nil{}:
      (8, (0, 100))
    case Con{h, t}:
      (A.or_default(U32.read(h), 8), A.pair(t, 0, 100))

def args4(xs: List<String>) -> U32 & (U32 & (U32 & U32)):
  match xs:
    case Nil{}:
      (16, (8, (0, 100)))
    case Con{h, t}:
      (A.or_default(U32.read(h), 16), args3(t))

def start(a: U32 & (U32 & (U32 & U32))) -> IO(Unit):
  (d, r1) = a
  (k, r2) = r1
  (modo, maxit) = r2
  go(d, k, modo, maxit)

def main() -> IO(Unit):
  do IO<Unit>:
    all : List<String> <- IO.args()
    start(args4(A.rest(all)))
