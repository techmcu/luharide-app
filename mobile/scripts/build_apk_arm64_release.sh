#!/usr/bin/env bash
# Smaller APK: arm64-v8a only. Run from repo: mobile/
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build apk --release \
  --split-per-abi \
  --target-platform android-arm64 \
  --dart-define=STABLE_RELEASE=true
echo ""
echo "APK: $(pwd)/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
