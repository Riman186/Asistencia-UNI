#!/usr/bin/env bash
#
# Compila la app para web en un entorno de CI/hosting (Netlify, Vercel, etc.).
#
# Ni Netlify ni Vercel traen Flutter preinstalado, así que el script descarga el
# SDK antes de compilar. El resultado queda en build/web, que es lo que ambas
# plataformas publican.
#
# Uso local:  bash scripts/build_web.sh
# Variables:
#   FLUTTER_VERSION   versión estable a usar (por defecto la fijada abajo)
#   FLUTTER_SDK_DIR   dónde instalar/buscar el SDK (por defecto .flutter-sdk)

set -euo pipefail

# Se fija la versión para que un cambio en el canal stable no rompa el deploy
# sin avisar. Debe traer Dart >= 3.10, que es lo que exige pubspec.yaml.
FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.2}"
FLUTTER_SDK_DIR="${FLUTTER_SDK_DIR:-$PWD/.flutter-sdk}"
FLUTTER_BIN="$FLUTTER_SDK_DIR/flutter/bin/flutter"

# Evita que las herramientas pidan datos de analítica en un entorno sin consola.
export FLUTTER_SUPPRESS_ANALYTICS=true
export CI=true

if [ ! -x "$FLUTTER_BIN" ]; then
  echo "==> Descargando Flutter $FLUTTER_VERSION"
  mkdir -p "$FLUTTER_SDK_DIR"
  curl -fsSL --retry 3 --retry-delay 5 \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar -xJ -C "$FLUTTER_SDK_DIR"
else
  echo "==> Reutilizando el Flutter ya presente en $FLUTTER_SDK_DIR"
fi

# El SDK es un repositorio git y la herramienta lo consulta. Si el usuario que
# ejecuta el build no coincide con el dueño de los archivos (habitual en un
# contenedor de CI), git aborta con "detected dubious ownership".
git config --global --add safe.directory "$FLUTTER_SDK_DIR/flutter" 2>/dev/null || true

export PATH="$FLUTTER_SDK_DIR/flutter/bin:$PATH"

echo "==> Versión del SDK"
flutter --version

echo "==> Resolviendo dependencias"
flutter pub get

echo "==> Compilando para web"
flutter build web --release

echo "==> Listo: build/web"
