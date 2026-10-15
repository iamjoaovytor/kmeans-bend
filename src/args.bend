import Base

def or_default(m: Maybe<&2, U32>, d: U32) -> U32:
  match m:
    case None{}:
      d
    case Some{x}:
      x

def first(xs: List<String>, d: U32) -> U32:
  match xs:
    case Nil{}:
      d
    case Con{h, t}:
      or_default(U32.read(h), d)

# Os dois primeiros argumentos de uma vez: a lista e consumida uma unica vez.
def pair(xs: List<String>, d1: U32, d2: U32) -> U32 & U32:
  match xs:
    case Nil{}:
      (d1, d2)
    case Con{h, t}:
      (or_default(U32.read(h), d1), first(t, d2))

# Desde a 2.0.32, IO.args() comeca pelo nome do programa, como o argv do C.
def rest(xs: List<String>) -> List<String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      t
