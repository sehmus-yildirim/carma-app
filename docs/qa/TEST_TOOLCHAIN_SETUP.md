# Test toolchain setup

Status: 2026-08-29

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
- Isolated Node 22 runtime at
  `C:\Users\Admin\AppData\Local\Programs\node-v22.23.2\node-v22.23.2-win-x64`

## Project entry points

- Unit and widget tests: `test/`
- Flutter integration tests: `integration_test/`
- Firebase Rules tests: `test/rules/`
- Maestro smoke flows: `.maestro/app_startup.yaml`, `.maestro/auth_error.yaml`
  und `.maestro/registration_navigation.yaml`
- Redmi Block-5 flows: `.maestro/block5_redmi_*.yaml`
- Local Redmi seed and inspector: `tools/block5_seed_emulator.js` and
  `tools/block5_inspect_emulator.js`; both abort unless the expected local
  emulator hosts are explicitly configured
- External-service guard check: `tools/block5_verify_functions_guard.js`
- iOS Windows release validator: `tools/test_ios_release_config.ps1` über
  `npm run test:ios:windows`

## Windows environment

- `JAVA_HOME`: Android Studio JDK 21
- `ANDROID_HOME` and `ANDROID_SDK_ROOT`: local Android SDK
- `PATH`: JDK, platform tools, emulator, command-line tools, and Maestro
- Firebase Functions emulation must use the isolated Node 22 directory first on
  `PATH`; global Node 24 exceeds the Functions project's declared runtime
- Maestro analytics are disabled for the local CLI.

New terminals inherit these variables automatically. Terminals that were
already open before setup must be restarted once.

## Verification status

- `flutter pub get`: passed
- `flutter analyze`: passed without findings after Block 5
- Flutter unit and widget suite: 231 of 231 passed
- Flutter coverage run: 231 of 231 passed; 19.9 percent line coverage
- Functions syntax with isolated Node 22: 23 of 23 own JavaScript files passed
- Functions tests with isolated Node 22: 100 of 100 passed across ten files
- Functions entry point: 30 exports loaded successfully
- Authenticated Functions-emulator guard: passed in 62 ms; local vehicle image
  generation cannot call the external Vertex service
- Firestore and Storage Rules: 109 of 109 passed after Block 5
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
- Redmi profile APK built and installed with local host `127.0.0.1`; SHA-256
  `B02923F94400B23B7053A95230800F4259AC0F0B8AA41F12AB7734A22AD1AC4A`
- Redmi multi-account search, contact request, acceptance, chat, reply and block:
  passed with local Auth, Functions and Firestore emulators
- Redmi permission, camera, GPS, lifecycle, session restore and offline/reconnect
  flows: passed
- Flutter regression after Block 5: 234 of 234 passed
- Push and production App Check: manual required; no live systems were changed
- Final emulator cleanup: AVD stopped and ports 9099, 8080, 9199, 5001, 4400,
  and 9150 free
- Android Gate 6: R8/Resource Shrinking enabled; signed AAB and APK built,
  validated and smoke-tested as a release build on the Redmi
- Gate-6 release APK SHA-256:
  `9B2816A541515F53D666A854ED91622B4C8ACBAB6AC29D1C30834CAD0B496DAC`
- Gate-6 release AAB SHA-256:
  `1382A293107CCD27193CD0D3FFFD01A5B11BE5E5679FCD4CE89827E730B786C6`
- Gate-6 final regression: Flutter 234/234, Functions 100/100, Rules 109/109,
  website 30/30 and Analyze without findings
- Gate-7/Gate-8 iOS Windows configuration: 126/126 checks passed for Plists,
  entitlements, capabilities, Firebase mapping, app icons and signing hygiene
- Gate-7 final regression: Flutter 234/234, Functions 100/100, Rules 109/109,
  website 30/30 and Analyze without findings
- Gate-8 final regression: Flutter 237/237, Functions 100/100, Rules 109/109,
  website 30/30, iOS Windows 126/126 and Analyze without findings
- Gate-8 security scan: 11 validated findings, 5 high and 6 medium; public
  release remains NO-GO
- Gate-7 emulator cleanup: ports 8080, 9199, 9150 and 4400 free
- Xcode, CocoaPods resolution, iOS signing, IPA, iPhone and TestFlight remain
  manual because Apple requires macOS/Xcode for the release build
- Original Redmi debug APK restored byte-for-byte and device locked after the
  release smoke test

Maestro 2.5.1 remains pinned because newer Windows releases also have a known
file-lock regression. On this 8 GB Windows host the AVD runs with constrained
memory and nonessential emulator background apps are stopped before long flows;
this affects only the virtual device.

## Safety rules

- Run destructive account and data flows only against approved test accounts.
- Target the emulator explicitly when a flow clears application state.
- Keep Firebase App Check in monitoring mode until metrics and device flows are verified.
- Do not run live tests, deploy resources, or publish store builds as part of toolchain setup.
