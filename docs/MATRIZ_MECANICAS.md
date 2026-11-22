# Matriz de mecânicas — Última Bruma 0.1.0

**Sobre a referência.** O documento de requisitos pede paridade com uma versão específica de um jogo de referência e uma auditoria das fontes listadas. **Essa auditoria não foi feita neste ciclo**: nenhuma das fontes foi consultada e nenhum valor foi copiado. As regras e os números abaixo são deste projeto, desenhados para o mesmo gênero. A coluna *Origem* indica apenas de onde vem a ideia: **G** = mecânica comum ao gênero/jogo base, **T** = câmera e apresentação em terceira pessoa (o papel do mod citado), **P** = solução própria deste projeto. A comparação item a item com a referência continua pendente.

**Estado:** **F** funcional (implementado e exercitado), **P** parcial (implementado em forma básica ou sem teste dedicado), **N** não implementado, **X** excluído pela revisão de escopo (animais).

**Teste:** `jogo`, `carro`, `graf`, `perf` são roteiros de `tools_rt/autotest.gd`; "manual" = visto em captura; "—" = sem teste dedicado.

## Câmera, controles e movimento

| Mecânica | Condições de uso | Recursos | Duração | Consequências | Dependências | Sandbox / ajustes | Implementação | Teste | Estado | Origem |
|---|---|---|---|---|---|---|---|---|---|---|
| Câmera atrás do personagem com colisão | sempre | — | contínua | não atravessa paredes; aproxima em cômodos | colisores do cenário | distância, FOV, suavização, tremor, inverter Y | `player.gd` (`_update_camera`) | graf | F | T |
| Mira sobre o ombro e troca de ombro | arma equipada ou botão MIRAR | — | enquanto ativa | aproxima, reduz FOV, limita velocidade | precisão | assistência de mira | `player.gd`, `hud.gd` | jogo | F | T |
| Percepção limitada pela visão do personagem | sempre | — | — | zumbis sem linha de visão a partir do personagem não são desenhados | raios de visão | — | `zombie.gd` (`_think`) | manual | F | T |
| Caminho do tiro pela câmera e pelo cano | arma de fogo | munição | por disparo | obstáculo junto ao cano bloqueia o tiro; mira indica "cano obstruído" | colisores | — | `player.gd` (`fire_gun`, `_check_muzzle`) | jogo | F | T |
| Controles por toque com multitoque | celular | — | — | analógico, câmera e botões simultâneos; toque curto × prolongado | — | tamanho, modo canhoto, sensibilidade | `hud.gd` | graf | P (sem teste em aparelho) | P |
| Controle físico e teclado | dispositivo conectado | — | — | mesmas ações do toque | — | — | `hud.gd` (`_poll_devices`) | — | P (não testado com controle real) | P |
| Andar, trotar, correr, agachar | no chão | fôlego ao correr | contínua | ruído por passo; correr gasta fôlego; agachar reduz ruído e visibilidade | carga, ferimentos nas pernas, sono, calçado | — | `player.gd`, `humanoid.gd` | jogo | F | G |
| Pular janelas | janela aberta, quebrada ou sem vidro, térreo | fôlego | ~0,9 s | cacos cortam mãos e pernas se não removidos | luvas reduzem o risco | gravidade dos ferimentos | `interact.gd` (`_vault_window`) | — | P | G |
| Pular cercas e obstáculos baixos | obstáculo baixo à frente; destino livre | fôlego | ~0,7 s | atravessa cercas, bancos, caixotes; mais lento com carga ou perna ferida | carga, ferimentos | — | `interact.gd` (`scan`, `_move_arc`) | — | P (zumbis não pulam cercas) | G |
| Escadas entre andares | edifícios de 2 e 3 andares | — | — | rampa com degraus; aberturas na laje | — | — | `building_plan.gd` | perf | F | G |
| Animações | — | — | — | locomoção, agachar, mira, golpes, recarga, queda, sentar, pular janela, zumbis | — | — | `humanoid.gd` (procedurais) | graf | P (procedurais, sem captura de movimento nem ajuste dos pés ao terreno) | P |

## Combate

| Mecânica | Condições de uso | Recursos | Duração | Consequências | Dependências | Sandbox / ajustes | Implementação | Teste | Estado | Origem |
|---|---|---|---|---|---|---|---|---|---|---|
| Golpes corpo a corpo (20 armas) | alvo no alcance e no arco | fôlego; condição da arma | 0,5–1,35 s por arma | dano, recuo, queda, desgaste, ruído | força, habilidade da arma, cansaço, dor, pânico | resistência dos zumbis | `player.gd` (`melee`, `_melee_hit`) | jogo | F | G |
| Golpe não atravessa paredes | — | — | — | raio entre o personagem e o alvo; acerta porta/parede | colisores | — | `player.gd` | — | P | T |
| Empurrão e pisão | mãos livres; zumbi caído | fôlego | 0,55 s | derruba; dano aumentado no chão | força | — | `player.gd` | — | P | G |
| Ataque furtivo | agachado, zumbi sem perceber | — | — | crítico garantido | furtividade | — | `player.gd` | — | P | G |
| Armas de fogo (pistola, revólver, espingarda, rifle, carabina) | munição carregada | munição | cadência por arma | dano por distância, tiro na cabeça ×3, ruído 55–105 m | mira, movimento, tempo de mira, luz, pânico, dor, condição | — | `player.gd` | jogo | F | G |
| Recarga por carregador, cartucho, tambor e ferrolho | munição solta na mochila | munição | 2,3 s ou 0,6 s por cartucho | conta carregador e câmara | habilidade de recarga | — | `player.gd` (`reload_pressed`) | jogo | P (sem carregadores como itens separados) | G |
| Travamento e limpeza da arma | condição baixa | kit de limpeza | 1,4 s / 9 s | arma trava; limpar recupera condição | manutenção | — | `player.gd`, `interact.gd` | — | P | G |
| Coquetel incendiário e despertador de distração | item fabricado; isqueiro | 1 item | arremesso 0,7 s | fogo temporário com dano em área; ruído de 55 m | receitas | — | `interact.gd` (`_throw`) | — | P | G |
| Explosivos | — | — | — | — | — | — | — | — | N | G |

## Zumbis

| Mecânica | Condições de uso | Recursos | Duração | Consequências | Dependências | Sandbox / ajustes | Implementação | Teste | Estado | Origem |
|---|---|---|---|---|---|---|---|---|---|---|
| Visão, audição e memória do alvo | — | — | memória 7–32 s | perseguem, investigam sons, perdem contato | luz, agachar, lanterna, traços | visão, audição, memória | `zombie.gd` | jogo | F | G |
| Busca de caminho | térreo | — | — | contornam móveis e paredes (grade de 1 m, A*) | grade de navegação | — | `world.gd` (`find_path`) | jogo | P (andares superiores usam direção direta) | P |
| Pressão sobre portas, janelas, barricadas e estruturas | obstáculo no caminho | — | golpe a cada ~1 s | quebram e atravessam; ruído atrai outros | força | força dos zumbis | `zombie.gd`, `building.gd`, `base.gd` | — | P | G |
| Ataque: arranhão, laceração, mordida | a menos de 1,3 m | — | 0,75 s | ferimento em parte do corpo; roupa protege e se desgasta | proteção das roupas, traços | transmissão, gravidade | `survivor.gd` (`zombie_hit`) | jogo | F | G |
| População persistente por região | — | — | — | zumbis distantes viram resumo com posição e dano preservados | — | população | `zombie_manager.gd` | jogo | F | P |
| Migração por ruído e reaparecimento | sons acima de 30 m | — | — | zumbis distantes se aproximam do som; regiões longe se repovoam devagar | — | reaparecimento | `zombie_manager.gd` | — | P | G |
| Perfis por local (polícia, saúde, obras, bombeiros, escritório, fazenda, civis) | — | — | — | roupas e saque do cadáver conforme o perfil | catálogo de roupas | — | `db_clothes.gd` | graf | F | G |
| Cadáver permanece, pode ser revistado, arrastado ou enterrado | — | pá para enterrar | 18 s | some após ~6 dias | — | — | `world.gd`, `interact.gd` | — | P | G |

## Sobrevivência e saúde

| Mecânica | Condições de uso | Recursos | Duração | Consequências | Dependências | Sandbox / ajustes | Implementação | Teste | Estado | Origem |
|---|---|---|---|---|---|---|---|---|---|---|
| Fome, sede, calorias, proteínas, peso corporal | sempre | comida e água | contínua | dano em níveis extremos; peso muda com as calorias | atividade, frio/calor, traços | — | `survivor.gd` (`tick`) | jogo | P (sem teste de longa duração) | G |
| Sono e qualidade da cama | cansado; sem perigo por perto | cama, colchão, saco de dormir | tempo acelerado ×60 | acorda com perigo, fome, sede ou ataque | dor, sonífero, traços | — | `player.gd` (`sleep_start`) | — | P | G |
| Fôlego e exaustão | correr, golpear | — | recupera parado | menos velocidade e dano | condicionamento, carga | — | `survivor.gd` | jogo | F | G |
| Temperatura, umidade, roupa molhada | sempre | roupas, fogo, abrigo | contínua | frio/calor alteram fome e sede; resfriado; dano extremo | clima, isolamento, chuva | — | `survivor.gd` | — | P (valor único para o corpo todo) | G |
| Ferimentos por parte do corpo (17 partes) | — | — | horas a dias | dor e sangramento localizados afetam pernas e braços | — | gravidade | `survivor.gd` | jogo | F | G |
| Curativo, desinfecção, sutura, tala, remoção de vidro, cataplasma | material na mochila | atadura, álcool, agulha, tala, pinça | 3–8 s | contém sangramento, acelera a cura; curativo suja | primeiros socorros | — | `interact.gd` (`wound_run`) | jogo (curativo e desinfecção) | P | G |
| Infecção comum de ferida × infecção zumbi | ferida aberta / ataque | antibiótico só para a comum | dias | zumbi: sem cura, leva à morte e reanimação | — | transmissão, duração | `survivor.gd` | — | P | G |
| Intoxicação alimentar, água contaminada, resfriado | comida crua/estragada; água suja; frio | — | horas | dano e mal-estar | traços | deterioração | `survivor.gd` | — | P | G |
| Pânico, estresse, tédio, tristeza, embriaguez | zumbis perto, ficar parado, traços | leitura, remédios, comida | contínua | pânico piora mira e dano | traços, dias sobrevividos | — | `survivor.gd` | — | P | G |
| Profissões (17) e traços (44) com custo e incompatibilidade | criação do personagem | pontos | permanente | habilidades iniciais, multiplicadores, efeitos nos sistemas | — | — | `survivor.gd`, `menu.gd` | manual | P (nem todo traço tem efeito em todos os sistemas) | G |
| Habilidades (26) por prática, livros e TV | praticar; ler | livros | por ação | níveis 0–10; livros multiplicam o ganho | — | ganho de experiência | `survivor.gd` | jogo | P | G |
| Exercícios | fôlego acima de 30% | — | 12 s | força ou condicionamento; dor muscular | — | — | `ui.gd` (`_exercise`) | — | P | G |

## Inventário, comida e fabricação

| Mecânica | Condições de uso | Recursos | Duração | Consequências | Dependências | Sandbox / ajustes | Implementação | Teste | Estado | Origem |
|---|---|---|---|---|---|---|---|---|---|---|
| Inventário com peso, capacidade, categorias, favoritos e busca | — | — | — | sobrecarga reduz velocidade e fôlego | força, mochila | — | `inv.gd`, `ui.gd` | jogo | F | G |
| Transferência com duração e recipientes com capacidade | recipiente ao alcance | — | 0,2–1 s por item | — | traços organizado/desorganizado | — | `ui.gd` | jogo | F | G |
| Saque por contexto (38 tabelas) | abrir recipiente | — | 1,2 s na primeira vez | conteúdo fixo por mundo; permanece após descarregar a região | — | quantidade de saque | `db_items.gd`, `building.gd` | jogo | F | G |
| Roupas: 65 peças base, 3.074 variantes, camadas, condição, sujeira, sangue | — | — | — | isolamento, proteção, resistência à água | — | — | `db_clothes.gd`, `humanoid.gd` | graf | P (variantes paramétricas; sem furos por região) | G |
| Lavar e remendar roupas, rasgar em panos | água; agulha, linha e pano | — | 2,5–9 s | recupera condição, limpa | costura | — | `interact.gd` | — | P | G |
| Comida: frescor, cozimento, latas, metade | — | abridor, fogo | 2,6 s | cru ou estragado intoxica; cozido rende mais | culinária | deterioração | `survivor.gd` (`eat`) | jogo | F | G |
| Geladeira conserva enquanto há energia | energia da rede ou gerador | — | — | envelhecimento 5× mais lento | energia | corte de energia | `interact.gd` (`_fridge_update`) | — | P (sem congelador) | G |
| Líquidos em recipientes: encher, beber, esvaziar, ferver | recipiente; fonte de água | — | 2–10 s | água suja contamina até ferver | fogo | corte de água | `interact.gd`, `db_recipes.gd` | — | P | G |
| Fabricação (33 receitas, em lote) | ingredientes, ferramentas, habilidade, estação | materiais | 2–22 s | item novo; experiência | conhecimento por revistas | — | `db_recipes.gd`, `ui.gd` | jogo | F | G |
| Construção (15 estruturas) com pré-visualização | materiais e ferramenta | tábuas, pregos etc. | ~6 s | paredes, portas, cercas, pisos, móveis; entram na navegação dos zumbis | carpintaria, alvenaria, metal | — | `base.gd`, `ui.gd` | jogo | P (sem checagem de suporte para telhados e andares) | G |
| Barricadas em portas e janelas (até 4 tábuas) | martelo, tábua, 2 pregos | — | ~4,5 s | zumbis precisam quebrar tábua por tábua | carpintaria | — | `building.gd`, `interact.gd` | jogo | F | G |
| Portas: trancar, arrombar, quebrar; alarmes | chave por dentro; pé de cabra | — | 5 s | alarme atrai zumbis por 150 s | energia para o alarme | — | `building.gd` | jogo | P | G |
| Desmontar móveis | martelo ou chave de fenda | — | 7 s | devolve materiais | carpintaria | — | `building.gd`, `interact.gd` | — | P (mover e girar móveis: N) | G |

## Mundo, agricultura e veículos

| Mecânica | Condições de uso | Recursos | Duração | Consequências | Dependências | Sandbox / ajustes | Implementação | Teste | Estado | Origem |
|---|---|---|---|---|---|---|---|---|---|---|
| Duas cidades, rodovia, rio, fazendas, florestas, cabanas | — | — | — | 483 edifícios com interior | — | — | `worldgen.gd`, `building_plan.gd` | graf, perf | F | P |
| Carregamento do mapa por regiões com antecipação | — | — | — | geração em threads; estado preservado ao descarregar | — | distância por perfil gráfico | `world.gd` | perf | F | P |
| Corte de árvores, troncos, tábuas, tocos, rebrota | machado | fôlego, condição do machado | golpes de ~1,2 s | queda animada, troncos e galhos; rebrota em 40 dias | habilidade com machado | — | `world.gd`, `interact.gd` | jogo | F | G |
| Agricultura: canteiro, semear, regar, adubar, doença, colher, sementes | pá/enxada; sementes | água, adubo | 4–9 dias por cultura | cresce com o relógio do mundo mesmo longe | estação, chuva, agricultura | velocidade das culturas | `base.gd` | jogo | P (colheita e doença sem teste dedicado) | G |
| Coleta vegetal | ao ar livre | — | 4,5–6 s | resultado por ambiente, estação, luz, clima e habilidade | coleta | — | `interact.gd` (`forage`) | — | P | G |
| Compostagem e secagem de alimentos | estrutura construída | restos vegetais; legumes | 2–3 dias | adubo; legumes secos | — | — | `base.gd` | — | P | G |
| Animais, caça, pesca, armadilhas, criação | — | — | — | — | — | — | — | — | X | — |
| Dia e noite, calendário, estações, chuva, tempestade, neblina | — | — | dia de 30 min a 4 h | visibilidade, temperatura, umidade, sons | — | duração do dia, chuva, mês inicial | `env.gd` | graf | F | G |
| Corte de água e energia; reservas nas torneiras | — | — | dia configurável | fogões, geladeiras, bombas e postes param | — | dias de corte | `game.gd`, `interact.gd` | — | P | G |
| Gerador, coletor de chuva, fogueira, lareira | item ou estrutura | gasolina, lenha | consumo por tempo | energia em 22 m, água a ferver, calor, cozinhar | conhecimento para o gerador | — | `base.gd` | — | P | G |
| Propagação de fogo | — | — | — | — | — | — | — | — | N | G |
| Rádio, TV e transmissões | TV com energia | — | 12 s | TV dá experiência nos primeiros dias | — | — | `interact.gd` | — | P (sem transmissões de emergência) | G |
| Veículos (7 tipos): dirigir, combustível, bateria, chave, ligação direta | chave ou ligação direta | gasolina | — | massa, aderência, frenagem, colisões, atropelamento | estado das peças | veículos, combustível | `vehicle.gd` | carro | F | G |
| Mecânica: 15 peças com condição individual | ferramentas, habilidade | peças | por serviço | pneus, freios, suspensão, escapamento e motor mudam a condução e o ruído | mecânica | — | `vehicle.gd`, `ui.gd` | carro (lista de peças) | P (serviços sem teste dedicado) | G |
| Abastecer em bomba ou galão; retirar combustível | energia para a bomba; mangueira e galão | — | 4–7 s | — | — | — | `interact.gd` | — | P | G |
| Reboque e carretas | — | — | — | — | — | — | — | — | N | G |
| Mapa com áreas exploradas, marcadores e anotações | — | mapas de cidade | — | mapas revelam estabelecimentos | — | — | `ui.gd` | — | P | G |

## Sistema

| Mecânica | Condições de uso | Recursos | Duração | Consequências | Dependências | Sandbox / ajustes | Implementação | Teste | Estado | Origem |
|---|---|---|---|---|---|---|---|---|---|---|
| Salvamento local versionado, gravação segura e cópia de recuperação | manual, automático, ao suspender | — | — | grava em temporário, confere e só então substitui | — | intervalo do automático | `save.gd`, `main.gd` | jogo, salvar | F | P |
| Vários mundos, continuar, apagar | menu | — | — | — | — | — | `menu.gd` | manual | F | G |
| Morte: cadáver com equipamentos, reanimação, novo sobrevivente no mesmo mundo | saúde zero | — | reanima em 30–180 min se infectado | — | — | — | `main.gd`, `zombie_manager.gd` | salvar | P | G |
| Tempo só avança durante a partida | — | — | — | suspender ou fechar não avança o mundo | — | — | `game.gd` | — | F | G |
| Sandbox: 5 predefinições e 22 parâmetros gravados no mundo | novo mundo | — | — | — | — | — | `game.gd`, `menu.gd` | manual | F | G |
| Tutorial por dicas | primeiros minutos | — | — | — | — | liga/desliga | `main.gd` | — | P | P |
| Perfis gráficos e resolução adaptativa | — | — | — | não alteram regras nem a simulação de zumbis | — | 3 perfis | `env.gd`, `world.gd`, `main.gd` | perf | P (sem validação em aparelho) | P |
| Áudio espacial com 102 efeitos, ambientes sem fauna, música, volumes separados | — | — | — | ruídos alimentam a percepção dos zumbis mesmo sem tocar | — | volumes | `audio.gd`, `tools/gen_audio.py` | — | P (não avaliado por ouvido humano) | P |
| Cooperativo e PvP | — | — | — | — | — | — | — | — | N (etapa posterior) | G |
| iOS | — | — | — | — | — | — | — | — | N | — |
