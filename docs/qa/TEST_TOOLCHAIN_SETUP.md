# Test toolchain setup

Status: 2026-08-28

## Installed and configured

- Flutter SDK with `flutter_test`
- Flutter SDK `integration_test` dependency
- Firebase CLI and local Emulator Suite cache
- Android Studio, Android SDK, platform tools, emulator, and profiler
- Android Studio JDK 21 via `JAVA_HOME`
- Maestro CLI 2.5.1 on the Windows user `PATH`
- Flutter DevTools from the Flutter SDK
- Android virtual device `plaqa_pixel_6_api_35`
- Physical Redmi test device available through ADB when connected and unlocked

## Project entry points

- Unit and widget tests: `test/`
- Flutter integration tests: `integration_test/`
- Firebase Rules tests: `test/rules/`
- Maestro smoke flow: `.maestro/app_startup.yaml`

## Windows environment

- `JAVA_HOME`: Android Studio JDK 21
- `ANDROID_HOME` and `ANDROID_SDK_ROOT`: local Android SDK
- `PATH`: JDK, platform tools, emulator, command-line tools, and Maestro
- Maestro analytics are disabled for the local CLI.

New terminals inherit these variables automatically. Terminals that were
already open before setup must be restarted once.

## Verification status

- `flutter pub get`: passed
- `flutter analyze`: passed without findings after Block 3
- Flutter unit and widget suite: 231 of 231 passed
- Flutter coverage run: 231 of 231 passed; 19.9 percent line coverage
- Functions syntax with isolated Node 22: 21 of 21 own JavaScript files passed
- Functions tests with isolated Node 22: 98 of 98 passed across nine files
- Functions entry point: 30 exports loaded successfully
- Firestore and Storage Rules: 104 of 104 passed across eleven emulator runs
- Emulator shutdown: passed; ports 8080, 9199, and 9150 were free afterward
- Android AVD creation and boot: passed
- ADB connection: passed for the emulator and the connected Redmi
- Maestro hierarchy access on the emulator: passed
- Debug APK build and emulator installation through the integration runner:
  passed
- Flutter integration runner: 4 of 4 files passed on the dedicated Android AVD
  against local Authentication, Firestore, and Storage emulators
- Flutter regression after the integration fixes: 234 of 234 passed
- Maestro launch flow: open because Maestro's internal DADB connection can
  intermittently report an online emulator as `device offline` on Windows

The remaining Maestro item belongs to Block 4 and does not indicate a plaqa
compile, analysis, or integration failure. Maestro 2.5.1 is pinned because newer
Windows releases also have a known file-lock regression.

## Safety rules

- Run destructive account and data flows only against approved test accounts.
- Target the emulator explicitly when a flow clears application state.
- Keep Firebase App Check in monitoring mode until metrics and device flows are verified.
- Do not run live tests, deploy resources, or publish store builds as part of toolchain setup.
