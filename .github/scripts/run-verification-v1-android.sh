#!/usr/bin/env bash

set -uo pipefail

log_file="${RUNNER_TEMP:-/tmp}/verification-v1-android.log"

set +e
flutter test integration_test/verification_v1_flow_test.dart \
  -d emulator-5554 2>&1 | tee "$log_file"
test_status=${PIPESTATUS[0]}
set -e

if [[ $test_status -eq 0 ]]; then
  exit 0
fi

if grep -Fq "1 test passed." "$log_file" && \
   grep -Fq "adb uninstall failed" "$log_file" && \
   grep -Fq "device offline" "$log_file"; then
  echo "::warning::Android tests passed; ignoring the known emulator-offline teardown failure."
  exit 0
fi

exit "$test_status"
