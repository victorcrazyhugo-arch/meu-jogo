# Estado da versão 0.1 — pronto, parcial e pendente

Este arquivo responde ao pedido de registrar o que cabe no ciclo, o que ficou provisório e o que falta. Ele descreve o estado real: nada aqui é dado como concluído sem ter sido executado.

## Resumo honesto

- O documento de requisitos descreve um projeto de **100 horas** e, além dele, o jogo completo. **Este ciclo durou cerca de 3 horas de trabalho efetivo** (mais trabalho paralelo de dois agentes auxiliares; ver `REGISTRO_DE_HORAS.md`). O que existe é uma primeira versão jogável e ampla, mas rasa em vários pontos.
- O APK **não foi testado em celular**. Tudo foi executado neste ambiente (Linux, renderização por software). Desempenho em aparelho, toque real, aquecimento e bateria são desconhecidos.
- A **auditoria do jogo de referência não foi feita**. As regras são próprias deste projeto, do mesmo gênero.
- O visual é um estilo próprio de baixo polígono. **Não reproduz a aparência dos personagens do jogo de referência**: o pedido de deixá-los "quase idênticos" não foi atendido de propósito, porque copiar a aparência de outro jogo não é algo que este projeto faz. Mecânicas do gênero, sim; arte copiada, não.

## Critérios de aceitação do ciclo (seção 29 do documento)

| # | Critério | Situação |
|---|---|---|
| 1 | Exatamente duas cidades e as regiões naturais | **Atendido.** Santa Aurora e Porto Bruma; rodovia, rio, fazendas, florestas, cabanas. Ver `CATALOGO.md`. |
| 2 | Sem animais e sem caça, pesca, pecuária ou captura | **Atendido.** Não existe entidade, som, item de manejo, receita ou habilidade de fauna. |
| 3 | Controle por toque e terceira pessoa | **Atendido no código e nas capturas; não validado em aparelho.** |
| 4 | Sistemas demonstráveis em execução, com limitações identificadas | **Atendido.** Capturas em `docs/prints/`, 48 verificações automáticas em `RELATORIO_TESTES.md`. |
| 5 | Matriz distingue funcional, parcial, não implementado e excluído | **Atendido.** `MATRIZ_MECANICAS.md`. A coluna de fonte registra que a referência não foi auditada. |
| 6 | Prints de versões reais mostrando a evolução | **Atendido em parte.** Duas séries de capturas reais no mesmo dia; não há gravações de vídeo. |
| 7 | Horas realizadas separadas das estimativas | **Atendido.** `REGISTRO_DE_HORAS.md`. |
| 8 | Salvamento e continuidade testados nas condições disponíveis | **Atendido neste ambiente** (corrupção, gravação interrompida, migração, continuar). Suspensão real do aplicativo no Android não testada. |
| 9 | Medições de desempenho com cena, configuração e hardware | **Atendido só para o ambiente de desenvolvimento.** Sem aparelho físico: pendência registrada. |
| 10 | Compilação, instruções, arquivos editáveis e relatório | **Atendido.** APK em `builds/`, `COMPILACAO.md`, todo o código-fonte e os geradores. |

## Por seção do documento

| Seção | Pronto | Parcial ou provisório | Falta |
|---|---|---|---|
| 1 Objetivo e referência | matriz de mecânicas; exceções (2 cidades, sem animais) registradas | — | auditoria da referência; paridade comprovada |
| 2 Plataforma | APK Android, horizontal, offline; versão do motor fixada; toque, controle e teclado no código | perfis gráficos sem base em aparelhos | iOS; aparelhos mínimo/intermediário/avançado definidos por teste real |
| 3 Câmera | órbita livre, colisão, mira no ombro, troca de ombro, ajustes, regra de percepção, checagem do cano | enquadramento em cômodos apertados ainda aproxima muito | ajuste específico para escadas, telhados e interior de veículos |
| 4 Arte e modelos | personagens articulados com variedade de pele, cabelo, barba e porte; materiais com ruído procedural; sombras; céu com nuvens; dia, noite, chuva, neblina | estilo de baixo polígono, sem texturas pintadas; mãos e rostos simples | modelos finais; sujeira, ferrugem e desgaste detalhados; proximidade visual com a referência (não será buscada por cópia) |
| 5 Roupas | 65 peças base e 3.074 variantes; camadas; peso, condição, isolamento, água, proteção; sujar, sangrar, lavar, remendar, rasgar | variantes são combinações paramétricas de corte, cor e estampa; ocultação de geometria por camada é simplificada | 3.000 variantes com modelagem individual; rasgos por região; validação de cada combinação em todas as animações |
| 6 Mapa | 3,2 × 2,0 km; 2 cidades; 483 edifícios com interior; distância de 1,3 km entre as cidades | terreno plano; plantas dos edifícios geradas por regras (repetem padrões) | relevo; interiores desenhados à mão; mais variedade de fachadas |
| 7 Interiores | cômodos por função; 33 modelos de móveis; portas (abrir, trancar, arrombar, quebrar, barricar); janelas (abrir, quebrar, limpar cacos, barricar, pular); escadas; desmontar móveis; corda de lençóis para descer | cortinas só visuais; trancas simples | mover e girar móveis; grades e portões de garagem; propagação de som e luz por portas abertas |
| 8 Florestas e cabanas | florestas extensas, 12 cabanas, postos florestais, acampamentos; corte de árvores com queda, troncos, tábuas, tocos e rebrota | queda da árvore não verifica colisões; troncos são itens | transporte de troncos no ombro; serraria; trilhas e áreas de difícil acesso |
| 9 Movimento e animação | andar, trotar, correr, agachar, mirar, golpear, recarregar, cair, sentar, dormir, pular janela e cerca baixa; variações por cansaço e ferimento | tudo procedural | animações autorais; ajuste dos pés ao terreno; cercas altas; contato de mãos em apoios |
| 10 Combate corpo a corpo | 20 armas com alcance, velocidade, dano, desgaste e fôlego; empurrão, pisão, golpe furtivo; fio de corte | reações do alvo simples | cabo e cabeça separados; finalizações; verificação fina do percurso do golpe |
| 11 Armas de fogo | 5 armas, 4 tipos de recarga, carregador e câmara, precisão por 8 fatores, ruído, travamento, limpeza | sem carregadores como itens; sem cápsulas no chão | explosivos; mais categorias de armas |
| 12 Zumbis | sentidos, memória, investigação, busca de caminho, pressão em obstáculos, hordas persistentes, perfis por local, 7 parâmetros de sandbox | navegação só no térreo; rastejadores não existem | escalada de cercas; migração ambiente; mais animações |
| 13 Necessidades | fome, sede, calorias, proteínas, peso, sono, fôlego, dor, esforço muscular, temperatura, umidade | temperatura única para o corpo | nutrição por macronutrientes completa; indicadores com descrição na tela principal |
| 14 Saúde | 17 partes do corpo; 8 tipos de ferimento; curativo, desinfecção, sutura, tala, vidro; infecção comum × zumbi; intoxicação, resfriado | queimaduras e fraturas existem mas quase nada as causa | projéteis alojados; doença por cadáveres |
| 15 Psicologia e habilidades | pânico, estresse, tédio, tristeza, álcool, fumo; 17 profissões; 44 traços; 26 habilidades; livros, revistas, TV | parte dos traços tem efeito limitado | gravações; equilíbrio dos custos |
| 16 Inventário | peso, capacidade, categorias, favoritos, busca, empilhamento, transferência com duração, slots, saque por contexto | um único espaço de carga (a mochila soma capacidade) | recipientes aninhados; colocar objetos no mundo com posição livre |
| 17 Comida e líquidos | calorias, frescor, cozinhar, queimar, estragar, latas; geladeira com energia; líquidos com volume e contaminação; ferver; coletor de chuva | sem congelador nem temperatura do alimento | combinação livre de ingredientes e porções |
| 18 Fabricação e bases | 33 receitas; fabricação em lote; 15 estruturas; barricadas; desmontar; geradores | sem validação de suporte; qualidade só pela vida da estrutura | ferraria, alvenaria e entalhe aprofundados; reconhecer interior fechado; encanamento |
| 19 Agricultura e coleta | 9 culturas; canteiro, semear, regar, adubar, doença, colher, sementes; compostagem; secagem; coleta por ambiente e estação | — | fertilidade do solo; pragas |
| 20 Veículos | 7 tipos; direção com massa e aderência; chave, trancas, ligação direta; painel; faróis, buzina; 15 peças com condição; abastecer e retirar combustível | um ocupante; serviços de mecânica sem teste dedicado | reboque; rádio e climatização; animações de entrar, sair e manutenção |
| 21 Água, energia, clima | dia e noite, calendário, estações, 5 climas, temperatura; cortes de água e energia; postes; gerador; coletor | fogo local (fogueira, lareira, coquetel) | propagação de fogo; degradação e vegetação tomando o mundo; transmissões de rádio |
| 22 Som | 102 efeitos sintetizados; passos por superfície; áudio espacial; reverberação interna; ruído compartilhado com os zumbis; música adaptativa | sons não avaliados por ouvido humano | obstrução por paredes; mais variações |
| 23 Interface | HUD ajustável, canhoto, área segura; inventário, saúde, habilidades, traços, receitas, construção, mecânica, mapa, configurações; português | posição dos botões não é arrastável | ícones desenhados (hoje há siglas e textos) |
| 24 Salvamento e morte | versionado, gravação segura, cópia de recuperação, migração, vários mundos, automático; cadáver, reanimação, novo sobrevivente | — | testes de suspensão e fechamento forçado no Android |
| 25 Modos | sobrevivência padrão, tutorial por dicas, sandbox com 5 predefinições e 22 parâmetros | tutorial curto | cooperativo e PvP (etapa posterior, não iniciada) |
| 26 Otimização | regiões com antecipação, geração em threads, níveis de detalhe de vegetação e interiores, instanciamento, um material para o cenário, resolução adaptativa, zumbis distantes em frequência menor | — | orçamentos a partir de medições em aparelho; níveis de detalhe de personagens |
| 27 Testes | roteiros automáticos de sistemas, veículos, salvamento, capturas e carga por cena | medições só no ambiente de desenvolvimento | sessões de 30 minutos em aparelhos; FPS, temperatura e bateria |
| 28 Execução | APK, código, geradores, instruções, matriz, catálogo, horas, prints, relatório | acompanhamento por prints dentro desta sessão | revisões de viabilidade em marcos futuros; gravações |

## Próximos passos sugeridos (em ordem)

1. Instalar o APK em um ou dois celulares e registrar FPS, toque e travamentos. Sem isso não dá para ajustar desempenho com segurança.
2. Fazer a auditoria da referência e ajustar valores e regras na matriz.
3. Aprofundar os itens marcados como parciais que mais pesam na experiência: câmera em interiores, navegação de zumbis em andares superiores, cercas, propagação de fogo.
4. Substituir os recursos provisórios (animações procedurais, modelos de baixo polígono) por arte final.
5. Multiplayer, somente depois de os fundamentos estarem validados em aparelho.
