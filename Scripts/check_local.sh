#!/bin/bash
# Local engineering checks only: no signing, uploads, installation or credentials.
set -euo pipefail
release_root="$(cd "$(dirname "$0")/.." && pwd)"
case "${1:-}" in
  "") build_release=0 ;;
  --build) build_release=1 ;;
  --help) echo 'Usage: bash Scripts/check_local.sh [--build]'; exit 0 ;;
  *) echo 'Unknown argument. Use --help.' >&2; exit 2 ;;
esac
cd "$release_root"
bash App/Scripts/test_regressions.sh
bash App/Scripts/test_journal.sh
plutil -lint App/Resources/Info.plist
if [[ "$build_release" == 1 ]]; then
  xcodebuild -project "App/FindHub Android.xcodeproj" -scheme "FindHub Android" \
    -configuration Release -destination 'generic/platform=iOS' \
    -derivedDataPath /tmp/findhub-android-appstore-build build CODE_SIGNING_ALLOWED=NO
fi
echo 'Local checks completed. This does not establish App Store, Google or license approval.'
