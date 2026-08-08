#!/usr/bin/env bash
# Magic packaging helper
# Usage:
#   ./scripts/package.sh macos [arm64|amd64]
#   ./scripts/package.sh android [arm64|arm|amd64|universal]
#   ./scripts/package.sh windows [amd64|arm64]   # must run on Windows
#   ./scripts/package.sh linux [amd64|arm64]     # must run on Linux
set -euo pipefail
cd "$(dirname "$0")/.."

export PATH="/opt/homebrew/bin:/opt/homebrew/opt/ruby/bin:${HOME}/.pub-cache/bin:${PATH:-}"

PLATFORM="${1:-}"
ARCH="${2:-}"
ENV_NAME="${3:-stable}"

if [[ -z "$PLATFORM" ]]; then
  echo "Usage: $0 <macos|android|windows|linux> [arch] [stable|pre]"
  exit 1
fi

case "$PLATFORM" in
  macos) ARCH="${ARCH:-arm64}" ;;
  android)
    ARCH="${ARCH:-arm64}"
    export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
    export ANDROID_SDK_ROOT="$ANDROID_HOME"
    export ANDROID_NDK="${ANDROID_NDK:-$ANDROID_HOME/ndk/28.2.13676358}"
    ;;
  windows) ARCH="${ARCH:-amd64}" ;;
  linux) ARCH="${ARCH:-amd64}" ;;
  *) echo "Unknown platform: $PLATFORM"; exit 1 ;;
esac

echo "==> flutter pub get"
flutter pub get
echo "==> build_runner"
dart run build_runner build -d
echo "==> dart setup.dart $PLATFORM --arch $ARCH --env $ENV_NAME"
dart setup.dart "$PLATFORM" --arch "$ARCH" --env "$ENV_NAME"
echo "==> done. Artifacts under dist/"
ls -lah dist/ || true
