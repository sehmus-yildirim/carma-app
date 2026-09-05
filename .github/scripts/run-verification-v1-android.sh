#!/usr/bin/env bash

set -uo pipefail

run_android_test() {
  local target="$1"
  local log_file="${RUNNER_TEMP:-/tmp}/$(basename "$target").log"
  local test_status
  set +e
  flutter test "$target" -d emulator-5554 2>&1 | tee "$log_file"
  test_status=${PIPESTATUS[0]}
  set -e

  if [[ $test_status -eq 0 ]]; then
    return 0
  fi
  if grep -Fq "1 test passed." "$log_file" && \
     grep -Fq "adb uninstall failed" "$log_file" && \
     grep -Fq "device offline" "$log_file"; then
    echo "::warning::Android tests passed; ignoring the known emulator-offline teardown failure."
    return 0
  fi
  return "$test_status"
}

run_android_test integration_test/verification_v1_flow_test.dart || exit $?
run_android_test integration_test/verification_native_ocr_smoke_test.dart || exit $?
