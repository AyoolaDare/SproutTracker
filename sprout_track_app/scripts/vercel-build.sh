#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  git clone https://github.com/flutter/flutter.git --branch stable --depth 1 "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
fi

flutter config --enable-web
flutter pub get

if [ -z "${API_BASE_URL:-}" ]; then
  echo "API_BASE_URL is required. Set it in Vercel to your Render backend URL." >&2
  exit 1
fi

if [ -z "${GOOGLE_CLIENT_ID:-}" ]; then
  echo "GOOGLE_CLIENT_ID is required. Set it in Vercel to your Google Web OAuth client ID." >&2
  exit 1
fi

flutter build web \
  --release \
  --pwa-strategy=offline-first \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID"
