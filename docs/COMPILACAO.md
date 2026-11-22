# Compilação e testes

## Motor escolhido

**Godot 4.5.1-stable**, renderizador **Compatibility** (OpenGL ES 3.0).

Por que este motor:

- Exporta APK Android nativo com os modelos de exportação oficiais, sem depender de serviços externos.
- O renderizador Compatibility roda na maior parte dos aparelhos Android, inclusive modestos.
- Permite gerar toda a geometria por código (cenário, personagens, veículos), o que mantém o conteúdo 100% próprio e o APK pequeno (28 MB).
- Suporta multitoque, controle físico, threads para carregar o mapa em segundo plano e arquivos locais.

Cena de teste usada para validar a escolha: a própria partida inicial — personagem, interior mobiliado, vegetação, iluminação com sombras, veículos e zumbis — capturada em `docs/prints/`. Limite desta validação: foi feita com renderização por software neste ambiente, não em celular.

A versão do motor está fixada em `project.godot` (`config/features` 4.5). Atualizar o motor exige reabrir o projeto na nova versão e repetir os testes abaixo.

## Compilar o APK

Requisitos:

1. Godot 4.5.1-stable (editor) e os modelos de exportação da mesma versão.
2. JDK 17 ou mais novo.
3. SDK Android com `build-tools` (apksigner) e `platform-tools` (adb), apontado em *Configurações do Editor → Exportar → Android*.

Depois:

```bash
GODOT=/caminho/para/godot tools/build_apk.sh
```

O script importa os recursos e exporta `builds/UltimaBruma-<versão>.apk` com a predefinição "Android" (arm64 + armv7). A predefinição "Android arm64" gera o arquivo menor, só de 64 bits:

```bash
godot --headless --path . --export-release "Android arm64" builds/UltimaBruma-0.1.2-arm64.apk
```

### Assinatura

O repositório inclui `android/debug.keystore`, uma chave de **desenvolvimento** (usuário `androiddebugkey`, senha `android`). Ela existe para que versões futuras instalem por cima das anteriores sem apagar os saves. Não serve para publicar em loja: para isso, gere uma chave própria e informe-a pelas variáveis `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER` e `_PASSWORD`.

### Como os APKs 0.1.x foram gerados

Neste ambiente o repositório oficial do SDK Android não era acessível. O Godot só precisa do `apksigner` para o tipo de exportação usado (APK pré-compilado, sem Gradle), então foram usados os pacotes `apksigner`, `zipalign` e `adb` da distribuição Linux, organizados em uma pasta com o formato de SDK. O resultado é assinado com os esquemas v2 e v3 e verificado com `apksigner verify`.

## Regenerar recursos

```bash
python3 tools/make_icon.py     # ícones
python3 tools/gen_audio.py     # 102 efeitos sonoros sintetizados (numpy)
```

## Testes automáticos

Os roteiros ficam em `tools_rt/autotest.gd` e rodam o jogo de verdade:

```bash
# verificação de sistemas (inventário, fabricação, combate, salvar e continuar)
godot --path . -- --autotest --scn=jogo --out=/tmp/saida
# veículos
godot --path . -- --autotest --scn=carro --out=/tmp/saida
# capturas de tela (interiores, ruas, floresta, noite)
godot --path . -- --autotest --scn=graf --out=/tmp/saida
# medições de carga por cena
godot --path . -- --autotest --scn=perf --out=/tmp/saida
# catálogo de conteúdo
godot --headless --path . -- --autotest --scn=catalogo --out=docs
```

Em servidor sem tela, use `xvfb-run -a -s "-screen 0 1280x720x24"` antes do comando e `--rendering-driver opengl3`.
