// Relatório do trabalho de Análise de Algoritmos (FB UNI), no estilo dos papers do Bend.
// Compilar: typst compile relatorio.typ
#let creme = rgb("#fdf6e3")
#let tinta = rgb("#073642")
#let caixa = rgb("#eee8d5")

#set document(title: "K-means em Bend", author: ("João Vitor Sousa", "Igor Targino"))
#set page(
  paper: "us-letter",
  fill: creme,
  margin: (x: 54pt, top: 62pt, bottom: 54pt),
  columns: 2,
  header: context {
    if counter(page).get().first() > 1 {
      set text(size: 8pt)
      [K-means em Bend: custo, iterações e paralelismo #h(1fr) #counter(page).display()]
    }
  },
)
#set columns(gutter: 20pt)
#set text(font: "Libertinus Serif", size: 10pt, fill: tinta, lang: "pt")
#set par(justify: true, first-line-indent: 1em, spacing: 0.65em)
#set heading(numbering: "1.1")
#show heading: set block(above: 1.3em, below: 0.7em)
#show heading.where(level: 1): set text(size: 12pt)
#show heading.where(level: 2): set text(size: 10pt)
#show raw: set text(font: "DejaVu Sans Mono", size: 7.5pt)
#show raw.where(block: true): block.with(fill: caixa, inset: 8pt, radius: 3pt, width: 100%)
#show raw.where(block: false): box.with(fill: caixa, inset: (x: 2pt), outset: (y: 2pt), radius: 2pt)
#show link: set text(fill: rgb("#2aa198"))
#show ref: set text(fill: rgb("#268bd2"))
#show cite: set text(fill: rgb("#859900"))
#show figure.caption: set text(size: 8pt)
#show figure.caption: set align(left)
#set figure(gap: 6pt)
#set table(stroke: none, inset: (x: 4pt, y: 3pt))
#show figure.where(kind: table): set figure.caption(position: bottom)

#let teorema(n, corpo) = [*#n.* #emph(corpo)]
#let prova(corpo) = [_Prova._ #corpo #h(1fr) $square$]

#place(top + center, scope: "parent", float: true)[
  #align(center)[
    #text(size: 17pt, weight: "bold")[K-means em Bend: custo por iteração,\ número de iterações e paralelismo]
    #v(4pt)
    #text(size: 11pt)[João Vitor Sousa · Igor Targino]\
    FB UNI · Análise de Algoritmos · 2026
  ]
  #v(4pt)
  #rect(width: 100%, stroke: 1pt + tinta, inset: 6pt)[
    #set text(size: 8pt)
    #set par(first-line-indent: 0em)
    #smallcaps[Reprodutibilidade.] Código e dados em #link("https://github.com/iamjoaovytor/kmeans-bend")[github.com/iamjoaovytor/kmeans-bend]: `kmeans.bend` (algoritmo), `referencia.py` e `validar.py` (referência em Python e conferência), `medir.py` e `caso_medio.py` (medições), `relatorio/figuras.py` (figuras). Todas as medições num Apple M4 Pro (8 núcleos de desempenho e 4 de eficiência) com Bend 2.0.36; no 2.0.37 a conferência passa igual e os tempos variam menos de 5%.
  ]
  #v(6pt)
]

#heading(numbering: none)[Resumo]
#set par(first-line-indent: 0em)
O k-means divide $n$ pontos em $k$ grupos repetindo dois passos: cada ponto vai para o centro mais próximo e cada centro vai para a média do seu grupo. Provamos que uma iteração custa $Theta(n k d)$ para qualquer entrada, que o algoritmo sempre termina em no máximo $k^n$ iterações e que o melhor caso é uma única iteração; o pior caso pode exigir um número exponencial de iterações @vattani2011. Como o caso médio não tem fórmula simples, medimos: em 400 conjuntos de dados, a média foi de 14 iterações para dados com grupos e 66 para dados uniformes. Implementamos o algoritmo em Bend, uma linguagem funcional que executa em paralelo na CPU e na GPU; os resultados coincidem com uma referência em Python, o tempo por iteração cresce linearmente em $n$ e em $k$, e 12 núcleos tornam cada iteração 3,9 vezes mais rápida.
#set par(first-line-indent: 1em)

= Introdução
Agrupar dados parecidos sem rótulos prévios é um problema comum: segmentar clientes por perfil de compra, reduzir as cores de uma imagem ou agrupar textos a partir dos vetores gerados por modelos de linguagem. O k-means, na forma de Lloyd @lloyd1982 e MacQueen @macqueen1967, é a solução mais usada para isso.

A entrada é um conjunto $P$ de $n$ pontos em $RR^d$ e o número $k$ de grupos. A saída é um centro $c_j$ por grupo e o grupo de cada ponto. O objetivo implícito é diminuir o custo
$ J = sum_(j=1)^k sum_(x in P_j) norm(x - c_j)^2, $
a soma das distâncias ao quadrado de cada ponto ao centro do seu grupo.

Com milhões de pontos, duas perguntas importam: quanto custa cada iteração e quantas iterações são necessárias. Uma terceira é prática: quanto do trabalho pode ser dividido entre núcleos. Este relatório responde às três, com provas e medições.

= O algoritmo
== Pseudocódigo
O algoritmo de Lloyd, com o custo de cada linha em comentário ($I$ é o número de iterações):

```
K-MEANS(P, k)
  C ← k pontos de P           // Θ(k·d)
  repita                      // I vezes
    para cada p em P          // n vezes
      grupo[p] ← mais perto   // k × Θ(d)
    para cada grupo j         // somas Θ(n·d)
      C[j] ← média do grupo   // Θ(k·d)
  até C não mudar
  devolve C, grupo
```

== Implementação em Bend
Em Bend, o paralelismo vem de uma única construção: `a b = f(x) g(y)` executa as duas chamadas ao mesmo tempo @bendrt2026. Por isso os pontos ficam numa árvore binária balanceada, e o passo 1 desce essa árvore dividindo o trabalho:

```python
def assign(+pts: Pts, +cs: List<&2, C>, +b: Nat) -> Sums:
  match pts:
    case PLeaf{+x, +y}:
      caminho(b, nearest(cs, x, y, 0, 0, 1.0e30), x, y)
    case PNode{l, r}:
      e d = assign(l, cs, b) assign(r, cs, b)
      juntar(e, d)
```

Em cada folha, `nearest` compara o ponto com os $k$ centros. As somas de cada grupo voltam pela árvore numa estrutura esparsa indexada pelo número do grupo: um ponto cria só o caminho até o seu grupo ($log k$ nós), e `juntar` com um lado vazio não custa nada. O passo 2 divide cada soma pela quantidade de pontos. O laço para quando os centros se movem menos que $10^(-6)$ ao todo. A implementação usa $d = 2$ e números `F32`.

= Operação básica
A operação mais repetida é a distância (ao quadrado) entre um ponto e um centro, $sum_(i=1)^d (x_i - c_i)^2$: $d$ subtrações, $d$ multiplicações e $d - 1$ somas, ou seja, custo $Theta(d)$. A raiz quadrada é dispensável, porque comparar distâncias ao quadrado dá a mesma ordem. Todas as demais operações (somar um ponto no seu grupo, dividir as somas) acontecem no máximo uma vez por ponto ou por grupo em cada iteração.

= Análise
== Custo de uma iteração
#teorema("Teorema 1")[Para $n, k >= 1$, uma iteração do k-means custa $Theta(n k d)$, para qualquer entrada.]

#prova[O passo 1 calcula, para cada um dos $n$ pontos, a distância até cada um dos $k$ centros, ao custo $Theta(d)$ cada: $c_1 n k d$ operações. O passo 2 soma cada ponto no seu grupo ($c_2 n d$) e divide $k$ somas ($c_3 k d$). Logo $T = c_1 n k d + c_2 n d + c_3 k d$. Como $n d <= n k d$ e $k d <= n k d$, vale $c_1 n k d <= T <= (c_1 + c_2 + c_3) n k d$, que é a definição de $Theta(n k d)$. Nenhum termo depende dos valores dos pontos, então não há melhor nem pior caso dentro de uma iteração.]

O custo total é, portanto, $Theta(I dot n k d)$, e toda a variação entre entradas está em $I$.

== O algoritmo sempre termina
#teorema("Lema 1")[Nenhum dos dois passos aumenta $J$.]

#prova[No passo 1, os centros estão fixos e cada ponto passa a usar o centro mais próximo, então a sua parcela em $J$ não aumenta. No passo 2, os grupos estão fixos. Para um grupo $P_j$ com média $mu$ e qualquer ponto $c$, vale a identidade
$ sum_(x in P_j) norm(x - c)^2 = sum_(x in P_j) norm(x - mu)^2 + |P_j| dot norm(mu - c)^2, $
porque o termo cruzado $2 sum_x (x - mu) dot (mu - c)$ é zero. Então a média minimiza a soma, e trocar $c_j$ por $mu$ não aumenta $J$.]

#teorema("Teorema 2")[O k-means termina em no máximo $k^n$ iterações.]

#prova[Suponha que, em caso de empate, o ponto continue no grupo atual. Então, enquanto o algoritmo não para, o passo 1 move pelo menos um ponto para um centro estritamente mais próximo, e $J$ cai estritamente; pelo Lema 1, o passo 2 não o faz subir. Depois do passo 2, os centros são as médias dos grupos, então o valor de $J$ ao fim de cada iteração depende só do agrupamento. Como esse valor cai estritamente a cada iteração, nenhum agrupamento se repete. Existem no máximo $k^n$ formas de atribuir $n$ pontos a $k$ grupos, então há no máximo $k^n$ iterações.]

Nossa implementação desfaz empates escolhendo o centro de menor índice, e não o grupo atual; empates exatos de distância em `F32` não ocorreram nos testes. A @fig-j mostra $J$ medido numa execução: ele cai em todas as 61 iterações, 47% logo na primeira.

#figure(image("fig_j.svg", width: 100%), caption: [Custo $J$ por iteração numa execução com 16 mil pontos uniformes e $k = 8$, medido no programa em Bend.]) <fig-j>

== Melhor, pior e caso médio
*Melhor caso.* Se os centros iniciais já são as médias dos seus grupos, a primeira iteração não muda nada e o algoritmo para: $I = 1$ e custo $Omega(n k d)$.

*Pior caso.* O Teorema 2 dá $O(k^n dot n k d)$. O limite não é só folga da prova: Vattani @vattani2011 construiu entradas no plano ($d = 2$) que exigem $2^(Omega(n))$ iterações.

*Caso médio.* Não há fórmula simples. Arthur, Manthey e Röglin @arthur2011 mostram que, com uma pequena perturbação aleatória nos dados, o número esperado de iterações é polinomial, o que explica por que na prática são poucas. Medimos esse comportamento na @experimentos.

== Trabalho e profundidade
Com o algoritmo em paralelo, interessa também a profundidade $D$: o tempo com núcleos ilimitados @cormen2009. Numa iteração, o trabalho é $W = Theta(n k d + n log k)$: as distâncias mais a montagem das somas esparsas. A árvore de pontos tem altura $log n$; cada folha faz $O(k d)$ e cada junção de somas custa no máximo $O(k)$, então $D = O(k d + k log n)$. Pelo teorema de Brent @brent1974, com $p$ núcleos o tempo é no máximo $W slash p + D$. Para $n$ grande, $D$ é desprezível diante de $W slash p$, e o ganho ideal seria próximo de $p$.

= Experimentos <experimentos>
== Validação
Uma referência em Python reproduz a mesma aritmética `F32` e a mesma ordem de somas. Em 10 configurações (variando $n$, $k$, tipo de dado e semente), o programa em Bend e a referência terminaram com o mesmo número de iterações, os mesmos centros (diferença máxima $4 dot 10^(-6)$) e o mesmo $J$ a cada iteração (diferença relativa abaixo de $10^(-7)$), e $J$ nunca aumentou.

== Custo por iteração
Medimos o tempo de uma iteração rodando 10 e 20 iterações e dividindo a diferença por 10, o que exclui a geração dos pontos (melhor de 3 execuções). A @fig-n mostra que o tempo cresce linearmente com $n$: a cada $4 times$ mais pontos, cerca de $4 times$ mais tempo. Com $n approx 10^6$ e $k = 8$, são cerca de 8 ns por distância, já incluindo as somas.

#figure(image("fig_n.svg", width: 100%), caption: [Tempo por iteração em função de $n$, com $k = 8$: 1 núcleo, 12 núcleos e GPU.]) <fig-n>

#figure(
  table(
    columns: (auto, 1fr, 1fr, 1fr),
    align: (left, right, right, right),
    table.hline(stroke: 0.8pt + tinta),
    table.header([$n$], [1 núcleo], [12 núcleos], [GPU]),
    table.hline(stroke: 0.5pt + tinta),
    [16 mil], [0,90 ms], [0,34 ms], [0,45 ms],
    [65 mil], [4,25 ms], [1,17 ms], [1,28 ms],
    [262 mil], [16,5 ms], [4,48 ms], [5,01 ms],
    [1 milhão], [67,1 ms], [17,2 ms], [19,9 ms],
    table.hline(stroke: 0.8pt + tinta),
  ),
  caption: [Tempo por iteração, $k = 8$.],
) <tab-n>

== Caso médio
Rodamos o algoritmo em 400 conjuntos de dados diferentes, com 16 mil pontos e $k = 8$: 200 com 8 grupos de verdade e 200 uniformes (@fig-hist). Com grupos, a média foi de 14,4 iterações (desvio 11,1, de 2 a 91); uniformes, 66,1 (desvio 30,1, de 24 a 159). Nenhuma execução se aproximou do limite teórico: na prática o k-means é rápido, e mais rápido justamente quando os dados têm a estrutura que ele procura.

#figure(image("fig_hist.svg", width: 100%), caption: [Iterações até parar em 400 execuções ($n = 16 space 384$, $k = 8$). Linha tracejada: média.]) <fig-hist>

== Otimização
A primeira versão criava, em cada ponto, uma lista com as $k$ somas, quase toda de zeros, e juntava listas inteiras em cada nó: um custo extra de $Theta(n k)$ em alocação. A versão com somas esparsas reduz esse custo para $Theta(n log k)$ sem mudar a operação básica. Com $n approx 10^6$ e $k = 8$, o tempo por iteração caiu de 190 para 67 ms em 1 núcleo, de 55 para 17 ms em 12 núcleos e de 70 para 20 ms na GPU. A @fig-k mostra o efeito ao variar $k$: antes o tempo dobrava a cada $k$ dobrado; depois segue $a n k + b n log k$, e o termo $n k$ ainda domina quando $k$ cresce.

#figure(image("fig_k.svg", width: 100%), caption: [Tempo por iteração em função de $k$ ($n = 131 space 072$, 1 núcleo), antes e depois das somas esparsas.]) <fig-k>

== Paralelismo
Com 12 núcleos, cada iteração ficou 3,9 vezes mais rápida e, na GPU, 3,4 vezes (@tab-n). O ganho fica longe dos 12 que o teorema de Brent permitiria e para de crescer a partir de 8 núcleos. Um perfil de execução mostra o tempo concentrado na criação dos nós das somas, não nas distâncias, o que sugere que o limite é a alocação de memória; não verificamos essa hipótese além do perfil.

= Conclusão
O custo de uma iteração do k-means é previsível, $Theta(n k d)$, e os testes confirmaram o crescimento linear em $n$ e em $k$. O número de iterações não é: vai de 1 a $k^n$ em teoria, mas nas medições ficou em média entre 14 e 66, e o custo $J$ caiu em todas as iterações, como o Lema 1 garante. Em Bend, uma única linha de código distribui o passo 1 entre núcleos, e somas esparsas tornaram cada iteração três vezes mais rápida.

Duas extensões ficaram de fora: testar dimensões $d > 2$ (a análise vale para qualquer $d$, mas só medimos $d = 2$) e comparar a inicialização aleatória com a do k-means++ @arthur2007, que escolhe centros iniciais espalhados e costuma reduzir o número de iterações.

#set text(size: 8pt)
#bibliography("refs.yml", title: "Referências", style: "association-for-computing-machinery")
