# Última Bruma

Jogo original de sobrevivência zumbi em mundo aberto, em terceira pessoa, feito para celular (Android, tela horizontal, solo e offline). Todo o conteúdo — código, modelos, animações, sons, mapa e interface — é gerado por este projeto; não há arquivos de terceiros.

**Versão atual: 0.1.3** — primeira versão jogável. É um começo, não o jogo completo descrito no documento de requisitos: veja o que está pronto, parcial e pendente em [`docs/PENDENCIAS.md`](docs/PENDENCIAS.md).

## Baixar e instalar

- APK: [`builds/UltimaBruma-0.1.3-arm64.apk`](builds/UltimaBruma-0.1.3-arm64.apk) (28 MB, Android 7.0 ou mais novo, aparelhos de 64 bits).
- No celular, abra o arquivo e permita "instalar apps desconhecidos" para o aplicativo usado para abri-lo.
- O APK foi compilado e assinado, mas **ainda não foi testado em um aparelho físico**. Se algo falhar, anote o modelo do celular e o que aconteceu.

## O que existe nesta versão

- Mapa contínuo de 3,2 × 2,0 km com exatamente duas cidades (Santa Aurora e Porto Bruma), rodovia, estradas de terra, rio, fazendas de produção vegetal, florestas, cabanas e acampamentos. 483 edifícios, todos com interior. Nenhum animal.
- Câmera em terceira pessoa com colisão, mira sobre o ombro e troca de ombro; controles por toque com multitoque, controle físico e teclado.
- Zumbis com visão, audição, memória, busca de caminho, pressão sobre portas, janelas e barricadas; população persistente por região.
- Combate corpo a corpo e com armas de fogo; ferimentos por parte do corpo, sangramento, curativos, infecção; fome, sede, sono, fôlego, temperatura, pânico e outros estados.
- Inventário com peso, saque por contexto, roupas modulares, culinária, líquidos, fabricação, construção, barricadas, agricultura, coleta vegetal e corte de árvores.
- Veículos dirigíveis com combustível, peças e mecânica.
- Dia e noite, calendário, estações, chuva, tempestade, neblina; corte de água e energia; postes, geradores, coletor de chuva.
- Personagem com corpo de formas anatômicas e caminhada e corrida com ciclo de marcha (apoio, balanço, movimento da bacia e dos braços).
- Móveis detalhados (sofás com almofadas, estantes com livros, armários e portas almofadados), capim alto em manchas e copas com folhas individuais.
- Materiais gerados por shader para cada tipo de superfície (tijolos, tábuas, telhas, asfalto, grama, madeira, tecido, vidro com reflexo), com relevo e chão molhado na chuva — sem arquivos de textura.
- Salvamento local versionado com cópia de recuperação, vários mundos, sandbox com predefinições.

## Controles

| Ação | Toque | Controle físico | Teclado (testes) |
|---|---|---|---|
| Andar | arrastar o lado esquerdo | analógico esquerdo | W A S D |
| Olhar | arrastar o lado direito | analógico direito | — |
| Atacar / atirar | ATACAR | gatilho direito | Espaço |
| Mirar | MIRAR | gatilho esquerdo | F |
| Interagir (toque curto) / todas as opções (segurar) | botão de ação | A | E / Q |
| Correr, agachar | CORRER, AGACHAR | L3, B | Shift, C |
| Recarregar, trocar arma, lanterna | RECARR., TROCAR, LUZ | X, RB, LB | R, X, L |
| Mochila, saúde, fabricar, mapa, menu | barra superior | Y, ↑, ↓, Back, Start | I, H, B, M, Esc |

## Documentação

| Arquivo | Conteúdo |
|---|---|
| [`docs/PENDENCIAS.md`](docs/PENDENCIAS.md) | Funções prontas, parciais e pendentes; critérios de aceitação |
| [`docs/MATRIZ_MECANICAS.md`](docs/MATRIZ_MECANICAS.md) | Matriz de mecânicas com condições, recursos, implementação e teste |
| [`docs/CATALOGO.md`](docs/CATALOGO.md) | Contagens reais de mapa, roupas, itens, receitas e móveis |
| [`docs/RELATORIO_TESTES.md`](docs/RELATORIO_TESTES.md) | Testes executados, medições e o que falta validar em aparelho |
| [`docs/REGISTRO_DE_HORAS.md`](docs/REGISTRO_DE_HORAS.md) | Horas realizadas e estimadas |
| [`docs/COMPILACAO.md`](docs/COMPILACAO.md) | Como compilar o APK e rodar os testes |
| [`docs/prints/`](docs/prints/) | Capturas reais do jogo em execução |

## Estrutura do projeto

```
project.godot, main.tscn     projeto Godot 4.5.1 (renderizador Compatibility)
src/core/                    estado global, áudio, salvamento, catálogos de itens, roupas e receitas
src/world/                   mapa, regiões, edifícios, clima
src/actors/                  personagem articulado, jogador, zumbis, veículos
src/systems/                 sobrevivência, inventário, interações, base e agricultura
src/ui/                      HUD de toque, telas e menu
audio/                       efeitos sintetizados (gerados por tools/gen_audio.py)
tools/                       geração de ícone e áudio, script de compilação
tools_rt/                    roteiros automáticos de teste e captura
builds/                      APK
```
