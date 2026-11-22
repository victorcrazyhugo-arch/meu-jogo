#!/usr/bin/env bash
# Compilacao reproduzivel do APK Android (Godot 4.5.1, modelo de exportacao oficial).
# Requisitos: Godot 4.5.1 (GODOT=/caminho/godot), modelos de exportacao 4.5.1 instalados,
# JDK 17+ e um SDK Android com build-tools (apksigner) e platform-tools (adb) configurados
# nas Configuracoes do Editor (export/android/android_sdk_path e java_sdk_path).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
VER="$(grep -oP 'config/version="\K[^"]+' project.godot)"
OUT="builds/UltimaBruma-${VER}.apk"
# Chave de assinatura de desenvolvimento versionada no repositorio (android/debug.keystore):
# manter a mesma chave permite instalar atualizacoes por cima sem perder os saves.
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-$PWD/android/debug.keystore}"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="${GODOT_ANDROID_KEYSTORE_RELEASE_USER:-androiddebugkey}"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:-android}"
mkdir -p builds
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Android" "$OUT"
rm -f "$OUT.idsig"
ls -la "$OUT"
