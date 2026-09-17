#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_build_dir=$(mktemp -d "${TMPDIR:-/tmp}/tagpin-tests.XXXXXX")
trap 'rm -rf "$test_build_dir"' EXIT
xcrun clang -c Sources/uECC/uECC.c -I Sources/uECC -o "$test_build_dir/uECC.o"
xcrun swiftc -parse-as-library -module-cache-path "$test_build_dir/modules" \
  -import-objc-header Sources/uECC/Bridging.h -I Sources/uECC \
  Sources/AccountProfile.swift Sources/CallbackWaiter.swift Sources/LocationResponse.swift Sources/LocationPresentation.swift Sources/MapViewport.swift Sources/MapClusters.swift \
  Sources/AesEax.swift Sources/ForeignTrackerCryptor.swift \
  Tests/RegressionTests.swift "$test_build_dir/uECC.o" -o "$test_build_dir/regressions"
"$test_build_dir/regressions"
