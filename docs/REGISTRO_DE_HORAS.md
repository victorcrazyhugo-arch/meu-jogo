# Registro de horas

Todas as horas são de 22 de novembro de 2026 (UTC). **As horas realizadas vêm do relógio da sessão e são aproximadas**: as tarefas não foram cronometradas uma a uma, então a divisão por etapa é uma estimativa feita depois, a partir da ordem em que os arquivos foram escritos.

## Totais

| | Horas |
|---|---:|
| Orçamento previsto no documento | 100 |
| Trabalho efetivo realizado nesta sessão (linha principal) | ~2,5 |
| Trabalho paralelo de agentes auxiliares (áudio e veículos) | ~1,3 |
| **Esforço total realizado** | **~3,8** |
| Tempo corrido da sessão, do início à entrega da 0.1.2 | ~4,7 |
| Tempo de espera sem trabalho (sessão interrompida entre ~14:20 e ~16:35) | ~2,2 |

O ciclo de 100 horas **não** foi cumprido: foram gastas cerca de 3,8. A versão 0.1.2 é o que coube nesse esforço. As cerca de 96 horas restantes do orçamento continuam disponíveis para as pendências de `PENDENCIAS.md`.

## Linha do tempo

| Horário (UTC) | O que aconteceu |
|---|---|
| 13:05 | Início. Verificação do ambiente: sem SDK Android, repositório do SDK bloqueado pela rede. |
| 13:08–13:12 | Godot 4.5.1 e modelos de exportação baixados e conferidos; exportação e assinatura de um APK mínimo comprovadas; renderização por software comprovada. |
| 13:12–14:20 | Escrita do núcleo: estado global, gerador de malhas, personagem articulado, roupas, itens, sobrevivência, inventário, jogador e câmera, HUD de toque, clima, mapa, edifícios, zumbis, base e agricultura, receitas, interações, telas, salvamento, menu. Em paralelo: síntese dos 102 sons. |
| ~14:20–16:35 | Sessão interrompida (reinícios do processo e limite de uso). Nenhum trabalho. |
| 16:35–16:45 | Retomada. Primeiro commit; correção dos erros de compilação; primeira execução real. |
| 16:45–17:02 | Correção de cores e do HUD; primeiras capturas; pacote gráfico pedido (mobília detalhada, árvores, postes, decoração, praça, grama). |
| 17:02–17:12 | Testes de jogo e de veículos; correções; exportação e entrega do APK 0.1.0. |
| 17:12–17:25 | Otimização dos zumbis distantes, testes de salvamento e morte (um defeito corrigido), medições, documentação, APK 0.1.1. |
| 17:25–17:45 | Pedido de gráficos e texturas melhores: materiais procedurais por superfície, relevo, vidro com reflexo, pele e cabelo, portas e janelas detalhadas, ajuste de cor e exposição; novas capturas; testes refeitos; APK 0.1.2. |

## Por etapa do cronograma do documento

| Etapa prevista | Horas previstas | Horas realizadas (aprox.) | Resultado |
|---|---:|---:|---|
| Estrutura, configuração mobile, dados e salvamento | 6 | 0,4 | Projeto compilável, exportação Android, salvamento versionado |
| Personagem, câmera, movimentação e toque | 12 | 0,4 | Personagem articulado, câmera com colisão, HUD multitoque |
| Duas cidades, interiores, estrada, floresta, cabana | 14 | 0,7 | Mapa completo em escala inicial, 483 interiores gerados |
| Zumbis, perseguição, colisões e combate | 14 | 0,4 | Sentidos, caminho, hordas, corpo a corpo e armas de fogo |
| Inventário, saque, necessidades, ferimentos | 14 | 0,4 | Telas funcionais e estados alterando o personagem |
| Veículo, combustível e manutenção | 10 | 0,9 (agente paralelo) | 7 tipos de veículo, peças e painel de mecânica |
| Árvores, fabricação, construção, agricultura | 8 | 0,3 | Corte de árvores, 33 receitas, 15 estruturas, 9 culturas |
| Integração e persistência | 8 | 0,3 | Salvar e continuar aprovados neste ambiente |
| Desempenho, controles, colisões, falhas críticas | 10 | 0,3 | Medições de carga por cena; nada medido em celular |
| Compilação, testes finais, prints, relatório | 4 | 0,4 | APK, 48 verificações, capturas e documentação |
| Melhoria gráfica pedida depois da entrega (materiais procedurais) | — | 0,3 | Versão 0.1.2 |
| **Total** | **100** | **~3,8** | Primeira versão jogável |

## Revisão de viabilidade

Feita ao final desta sessão, antes da décima hora:

- **Funciona:** a partida completa do menu até a morte, com os sistemas listados em `PENDENCIAS.md`.
- **Riscos encontrados:** (1) nenhum teste em aparelho — o maior risco do projeto; (2) custo de CPU dos zumbis ativos, medido em ~8 ms por passo de física no computador de desenvolvimento antes da otimização; (3) todo o conteúdo é gerado por regras, o que dá amplitude rápida mas pouca variedade autoral; (4) a auditoria da referência não começou.
- **Previsão:** com as horas restantes do orçamento é realista aprofundar os sistemas parciais e validar em celular. Arte final, 3.000 roupas modeladas uma a uma, animações autorais e multiplayer **não cabem** em 100 horas; continuam como objetivos do projeto, não deste ciclo.
