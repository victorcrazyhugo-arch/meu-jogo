# Relatório de testes — Última Bruma 0.1.1

Data: 22 de novembro de 2026.

## Onde os testes rodaram

| | |
|---|---|
| Ambiente | contêiner Linux de desenvolvimento, sem GPU |
| Processador | Intel Xeon 2,10 GHz, 4 núcleos |
| Renderização | Mesa llvmpipe (OpenGL 4.5 por software), 1280 × 720 |
| Motor | Godot 4.5.1-stable, renderizador Compatibility |
| Execução | o jogo real, dirigido pelos roteiros de `tools_rt/autotest.gd` |

**Nenhum teste foi feito em celular.** Não havia aparelho físico nem emulador Android disponível. Todas as exigências da seção 27 do documento que dependem de aparelho (modelo, GPU, sessões de 30 minutos, FPS, percentis em hardware real, temperatura, bateria) continuam **pendentes**.

## Verificações automáticas de funcionamento

48 verificações, 48 aprovadas na última execução.

### Roteiro `jogo` (25 verificações)

| Verificação | Resultado | Observação |
|---|---|---|
| Vestir mochila e jaqueta | aprovado | capacidade passou a 26,0 kg |
| Comer lata com abridor | aprovado | fome 0,50 → 0,22; item consumido |
| Equipar arma | aprovado | |
| Receita disponível com ingredientes e ferramenta | aprovado | |
| Serrar tronco em tábuas (ação com duração) | aprovado | 12 → 15 tábuas |
| Partida começa dentro de casa | aprovado | |
| Vasculhar recipiente e transferir | aprovado | |
| Abrir porta | aprovado | |
| Quebrar janela | aprovado | estado "cacos" |
| Barricar janela | aprovado | janela deixa de ser passável |
| Ferimento sangra | aprovado | laceração: 4,0 pontos/h |
| Desinfetar e enfaixar | aprovado | |
| Local livre permite construir | aprovado | |
| Plantio cresce com o tempo | aprovado | 3 dias: crescimento 0,39 (estágio "broto") |
| Floresta carregada | aprovado | ~1.900 árvores em 32 regiões |
| Cortar árvore gera troncos | aprovado | 4 itens no chão |
| Zumbis ativos na cidade | aprovado | 64 (limite de simulação) |
| Combate corpo a corpo elimina zumbis | aprovado | 2 abates em 4 s de jogo |
| Recarregar pistola | aprovado | 15 cartuchos |
| Tiros acertam zumbis | aprovado | 30 disparos, 6 abates |
| Gravar save | aprovado | |
| Continuar restaura posição | aprovado | |
| Continuar restaura inventário | aprovado | |
| Continuar restaura tempo e abates | aprovado | |
| Estruturas e canteiros persistem | aprovado | 2 estruturas, 1 canteiro |

### Roteiro `carro` (7 verificações)

| Verificação | Resultado | Observação |
|---|---|---|
| Veículo encontrado no mundo | aprovado | 165 vagas previstas no mapa |
| Lista de peças | aprovado | 15 peças com condição |
| Entrar no veículo | aprovado | |
| Motor liga | aprovado | motor a 60% |
| Veículo anda | aprovado | 26 m em ~7 s, com curva e freada |
| Sair do veículo | aprovado | |
| Estado dos veículos pode ser salvo | aprovado | ~21 KB |

### Roteiro `salvar` (14 verificações, sem tela)

| Verificação | Resultado |
|---|---|
| Primeiro save existe | aprovado |
| Segundo save cria cópia de recuperação | aprovado |
| Save principal corrompido → usa a cópia de recuperação | aprovado |
| Fechamento entre remover o atual e renomear o temporário → recupera do temporário | aprovado |
| Migração de save de versão anterior preserva propriedades | aprovado |
| Regrava após a recuperação | aprovado |
| Continuar não avança o tempo do mundo | aprovado |
| Continuar preserva itens | aprovado |
| Janela quebrada continua quebrada | aprovado |
| Item largado no chão persiste sem duplicar | aprovado |
| Morte deixa cadáver com os equipamentos | aprovado |
| Save marca o sobrevivente como morto | aprovado |
| Novo sobrevivente no mesmo mundo; cadáver anterior continua | aprovado |
| Cadáver infectado se reanima como zumbi | aprovado |

### Roteiro `cerca` (2 verificações, sem tela)

| Verificação | Resultado | Observação |
|---|---|---|
| Cerca detectada como obstáculo baixo | aprovado | |
| Personagem pula a cerca | aprovado | atravessou 2 m em ~0,7 s |

Defeitos encontrados por estes testes e corrigidos: (1) morte causada por dano externo não iniciava a sequência de morte; (2) o corpo do personagem ficava invisível por um erro na lógica de câmera; (3) dupla conversão de cor deixava o cenário quase preto; (4) o HUD tinha largura zero.

Limites dos testes: são verificações de "funciona neste caso", não de equilíbrio. Itens sem teste dedicado estão marcados como parciais na matriz. O teste de interrupção de gravação simula os estados em disco; não mata o processo de verdade.

## Carga por cena (ambiente de desenvolvimento)

Perfil gráfico "Equilibrado", resolução adaptativa desligada. Os tempos de quadro abaixo são de **renderização por software** e não dizem nada sobre um celular com GPU; servem só para comparar cenas entre si. Os números que independem de hardware são desenhos, primitivas, objetos e memória. O tempo de física é CPU real deste computador.

| Cena | Quadro médio (software) | p95 | p99 | Pico | Física (CPU) | Desenhos | Primitivas | Objetos | Memória | Zumbis simulados | Regiões | Edifícios |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Interior da casa inicial | 197 ms | 232 ms | 249 ms | 249 ms | 2.4 ms | 297 | 92.358 | 462 | 99 MB | 64 | 69 | 71 |
| Avenida de Santa Aurora, dia | 164 ms | 189 ms | 196 ms | 196 ms | 2.1 ms | 331 | 117.267 | 480 | 113 MB | 64 | 94 | 176 |
| Cabana cercada de vegetação densa | 187 ms | 228 ms | 236 ms | 236 ms | 0.7 ms | 242 | 208.442 | 391 | 86 MB | 5 | 62 | 1 |
| Centro de Porto Bruma com horda atraída por som | 252 ms | 310 ms | 323 ms | 323 ms | 4.9 ms | 313 | 267.370 | 477 | 126 MB | 64 | 81 | 97 |
| Hospital, térreo | 226 ms | 272 ms | 276 ms | 276 ms | 3.3 ms | 233 | 196.477 | 413 | 125 MB | 64 | 96 | 110 |
| Hospital, terceiro andar | 254 ms | 306 ms | 319 ms | 319 ms | 3.0 ms | 221 | 206.534 | 401 | 125 MB | 64 | 96 | 110 |
| Noite, tempestade, horda e disparos | 277 ms | 359 ms | 361 ms | 361 ms | 5.1 ms | 302 | 242.366 | 532 | 138 MB | 64 | 96 | 112 |
| Dirigindo pela rodovia entre as cidades (25 s, até 109 km/h) | 115 ms | 188 ms | 200 ms | 643 ms | 3.9 ms | 185 | 32.886 | 414 | 91 MB | 6 | 87 | 3 |

Outras medições: gravar o save após essas mudanças levou 65 ms e gerou um arquivo de 963 KB. Na rodovia, o pico de 643 ms foi um engasgo ao carregar regiões novas com renderização por software; precisa ser medido em aparelho. Antes de reduzir a frequência de atualização dos zumbis distantes, a física custava de 4,5 a 9,7 ms nas cenas com 64 zumbis; depois, de 2,1 a 5,1 ms.

Leitura:

- Os orçamentos de referência do documento são 33,3 ms por quadro (30 FPS) e 16,7 ms (60 FPS). **Não é possível afirmar que são atingidos** sem medir em aparelho.
- A carga de desenho é moderada para celular intermediário (algumas centenas de chamadas de desenho por quadro). O ponto de atenção é a CPU com 64 zumbis ativos.
- Zumbis renderizados × simulados: os 64 ativos são sempre simulados; são desenhados apenas os que o personagem pode ver (linha de visão) e que estão dentro da névoa. O número de zumbis simulados não muda com o perfil gráfico.

## Cenários exigidos pelo documento

| Cenário | Situação |
|---|---|
| Dirigir rapidamente entre cidades e entrar em regiões novas | medido no ambiente de desenvolvimento (tabela acima) |
| Explorar um hospital com vários andares | medido (térreo e terceiro andar) |
| Hordas com chuva, noite, faróis e disparos | medido com chuva, noite e disparos; faróis não incluídos |
| Alarmes com muitos zumbis procurando caminhos | medido com evento sonoro de 90 m no centro de Porto Bruma |
| Cabanas cercadas de vegetação densa | medido |
| Base com muitos objetos e construções | **não medido** (não há uma base grande construída nos roteiros) |
| Salvar, fechar, reabrir e continuar após mudanças extensas | aprovado no roteiro `salvar`; tempo de gravação na tabela |
| Jogar depois do aquecimento do aparelho | **pendente** (exige aparelho) |
| Roupas e animações, toque, colisão, inventário, consumo, migração | inventário, consumo e migração cobertos; toque real e validação de roupas em todas as animações pendentes |

## O que validar primeiro em um celular

1. O aplicativo abre, mostra o menu e inicia um mundo.
2. FPS no perfil "Equilibrado" na casa inicial, na avenida e no centro de Porto Bruma (ative "Mostrar FPS" nas configurações).
3. Analógico, câmera e botões usados ao mesmo tempo.
4. Sair com o botão de início do celular e voltar: a partida deve continuar no mesmo ponto.
