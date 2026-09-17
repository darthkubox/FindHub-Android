#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
journal_test_dir=$(mktemp -d "${TMPDIR:-/tmp}/tagpin-journal-tests.XXXXXX")
trap 'rm -rf "$journal_test_dir"' EXIT
xcrun swiftc -parse-as-library -module-cache-path "$journal_test_dir/modules" \
  Sources/LocationResponse.swift Sources/TrackerJournalData.swift Sources/TrackerJournal.swift \
  Tests/JournalRegressionTests.swift -o "$journal_test_dir/journal-tests"
"$journal_test_dir/journal-tests"
