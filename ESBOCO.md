# Esboço — entrega de 15/10

**Autores:** João Vitor Sousa e Igor Targino
**Tema:** inteligência artificial e dados (agrupamento / clustering)
**Algoritmo:** k-means (algoritmo de Lloyd), implementado em Bend com paralelismo em CPU e GPU

## Tópicos a provar

1. **Contextualização** — dividir n pontos em k grupos parecidos: segmentação de clientes, compressão de cores de imagem, agrupamento de documentos e embeddings em IA.
2. **Descrição do algoritmo** — repetir dois passos até os centros pararem: (1) cada ponto vai para o centro mais próximo; (2) cada centro vai para a média do seu grupo. Pseudocódigo e código em Bend (`kmeans.bend`).
3. **Mapeamento de operações** — operação básica: distância entre um ponto e um centro (d subtrações e multiplicações, d = dimensões).
4. **Análise e prova**
   - Custo de uma iteração: n·k distâncias de custo d → **Θ(n·k·d)**; recalcular as médias custa Θ(n·d)
   - Custo total: **O(I·n·k·d)**, com I = número de iterações
   - Melhor caso: os centros já estão no lugar → 1 iteração → Ω(n·k·d)
   - Pior caso: existem entradas que exigem um número exponencial de iterações (Vattani, 2011)
   - Terminação: o custo J (soma das distâncias²) nunca aumenta, então nenhum agrupamento se repete → no máximo kⁿ iterações
   - Caso médio / na prática: medido em 400 conjuntos de dados (média 14 iterações com grupos, 66 uniformes)
   - Paralelismo: os n pontos são independentes; as somas sobem por uma árvore de profundidade lg n
5. **Otimização e validação empírica (diferencial)**
   - Somas por grupo em árvore esparsa: o custo extra cai de n·k para n·log k; 3× mais rápido
   - Tempo por iteração cresce linearmente em n e em k; 1 núcleo × 12 núcleos × GPU
   - Resultados idênticos a uma referência em Python (`validar.py`)
