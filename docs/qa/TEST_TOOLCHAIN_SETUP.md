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
- Maestro smoke flows: `.maestro/app_startup.yaml`, `.maestro/auth_error.yaml`
  und `.maestro/registration_navigation.yaml`

## Windows environment

- `JAVA_HOME`: Android Studio JDK 21
- `ANDROID_HOME` and `ANDROID_SDK_ROOT`: local Android SDK
- `PATH`: JDK, platform tools, emulator, command-line tools, and Maestro
- Maestro analytics are disabled for the local CLI.

New terminals inherit these variables automatically. Terminals that were
already open before setup must be restarted once.

## Verification status

- `flutter pub get`: passed
- `flutter analyze`: passed without findings after Block 4
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
- Android profile APK with local Firebase emulator defines: built and installed
- Profile-only cleartext access for the emulator host `10.0.2.2`: passed;
  release manifest unchanged
- Maestro startup, login-error, registration, plate entry, and core navigation:
  3 of 3 flows passed in one 4 minute 12 second final run
- Flutter regression after Block 4: 234 of 234 passed
- Final emulator cleanup: AVD stopped and ports 9099, 8080, 9199, 5001, 4400,
  and 9150 free

Maestro 2.5.1 remains pinned because newer Windows releases also have a known
file-lock regression. On this 8 GB Windows host the AVD runs with constrained
memory and nonessential emulator background apps are stopped before long flows;
this affects only the virtual device.

## Safety rules

- Run destructive account and data flows only against approved test accounts.
- Target the emulator explicitly when a flow clears application state.
- Keep Firebase App Check in monitoring mode until metrics and device flows are verified.
- Do not run live tests, deploy resources, or publish store builds as part of toolchain setup.
