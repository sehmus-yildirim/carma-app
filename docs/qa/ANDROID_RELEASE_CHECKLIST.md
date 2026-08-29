# Android Release Candidate Checkliste

Stand: 2026-08-29
Gate-6-Basis: `main` / `3ea0dc6d212238c5e55ffb808415e831bc582117`
Status: `PASS LOCAL`; kein Upload und keine Veröffentlichung

## Identität und Toolchain

- [x] Package ID und Namespace: `de.plaqa.app`
- [x] App-Version: `1.0.0+1`
- [x] Android `minSdk`: 24
- [x] Android `targetSdk`: 36
- [x] Firebase-Projekt: `carma-a84e4`
- [x] Flutter 3.41.7 / Dart 3.11.5
- [x] Android Release-Signing vollständig konfiguriert
- [x] Upload-Keystore und `key.properties` bleiben außerhalb von Git
- [x] Release-SHA-1 ist im Android-Firebase-Client hinterlegt

## Release-Härtung

- [x] R8-Code-Minifizierung aktiviert
- [x] Resource Shrinking aktiviert
- [x] Optimiertes Resource Shrinking aktiviert
- [x] Release-Buildlabel lautet standardmäßig `Release`
- [x] Debug/Profile-spezifischer Emulator-Klartextzugriff gelangt nicht ins
  Release-Manifest
- [x] Release-App ist nicht `debuggable`
- [x] Kein generierter `integration_test`-Plugin-Registrant im Release-Artefakt
- [x] App Check verwendet im Release die Play-Integrity-Konfiguration

## Berechtigungen

Das zusammengeführte Release-Manifest wurde kontrolliert. Die App fordert nur
die für die implementierten Funktionen erwarteten Android-Berechtigungen an:
Netzwerk, Benachrichtigungen, Kamera, Mikrofon, Standort und ausgewählte
Medienzugriffe. Der Release-Build besitzt keine Debug- oder Klartextfreigabe.
Die endgültigen Play-Console-Erklärungen bleiben mit den Datenschutzangaben
abzugleichen.

## Erzeugte und geprüfte Artefakte

| Artefakt | Größe | SHA-256 | Ergebnis |
|---|---:|---|---|
| `build/app/outputs/bundle/release/app-release.aab` | 70,70 MiB | `1382A293107CCD27193CD0D3FFFD01A5B11BE5E5679FCD4CE89827E730B786C6` | PASS |
| `build/app/outputs/flutter-apk/app-release.apk` | 82,31 MiB | `9B2816A541515F53D666A854ED91622B4C8ACBAB6AC29D1C30834CAD0B496DAC` | PASS |

- [x] Beide Artefakte aus einem vorher bereinigten Build erzeugt
- [x] `bundletool 1.18.3 validate` für das AAB bestanden
- [x] APK-Signatur mit `apksigner` bestanden; genau ein Signierer
- [x] APK enthält eine gültige v2-Signatur
- [x] `zipalign -P 16 -c -v 4` bestanden
- [x] Unterstützte ABIs: `arm64-v8a`, `armeabi-v7a`, `x86_64`
- [x] R8-Mapping- und Usage-Ausgaben wurden erzeugt

Upload-Zertifikat:

- SHA-1: `43:E8:D9:2C:5F:12:3D:E5:ED:FA:34:04:A3:B7:2D:3A:52:15:90:47`
- SHA-256: `77:A1:A1:05:35:61:8B:1F:C6:81:E5:AF:97:82:31:7A:00:1C:7B:C2:29:DE:E7:20:F3:1A:03:76:33:63:C7:BC`
- Gültig bis: 2053-11-18

Build-Artefakte und Mapping-Dateien bleiben lokale, ignorierte Ausgaben und
werden nicht in Git eingecheckt.

## Echter Release-Smoke-Test

Gerät: Redmi `2201117TY`, Android 13 / API 33, ADB-ID `cf1d4c97`.

- [x] Signierte Release-APK installiert
- [x] Installierte APK stimmt bytegenau mit dem geprüften lokalen Artefakt überein
- [x] Paket, Version und Ziel-SDK auf dem Gerät bestätigt
- [x] Release-Paket besitzt kein `DEBUGGABLE`-Flag
- [x] Drei Kaltstarts: 2.439 ms nach Installation, danach 612 ms und 495 ms
- [x] Zusätzlicher isolierter Kaltstart: 608 ms
- [x] Stabiler Zustand: 165.052 KB Total PSS, 246.320 KB Total RSS,
  671 KB Swap PSS
- [x] Maestro-Kaltstartflow bestanden: Anmeldung und Registrierung sichtbar;
  keine Null-Check-, RenderFlex- oder ANR-Meldung
- [x] Reale Login-Ansicht visuell kontrolliert; kein Überlauf
- [x] Isolierter Runtime-Log ohne App-Crash, ANR, unbehandelte Flutter-Ausnahme
  oder Layoutüberlauf
- [x] Firebase-Initialisierung, Impeller und Messaging-Hintergrunddienst starten

## Gerätezustand nach dem Test

- [x] Release-APK deinstalliert
- [x] Vorherige Debug-APK wieder installiert
- [x] Wiederhergestellte APK stimmt per SHA-256 bytegenau mit der Sicherung
  `AEB8D6000060278513CC128129E9C8050F5379D45F1A7F219331479F36DE3329`
  überein
- [x] Debug-Version `1.0.0 (1)` und `DEBUGGABLE`-Flag bestätigt
- [x] App gestoppt und Redmi wieder gesperrt (`Dozing`)

## Noch manuell und extern erforderlich

- [ ] AAB in die interne Play-Testspur hochladen
- [ ] Play App Signing und Upload-Zertifikat in der Play Console kontrollieren
- [ ] Data Safety, Berechtigungserklärungen, Zielgruppe und Content Rating finalisieren
- [ ] Store Listing, Screenshots, Feature Graphic und Rechtstexte final abnehmen
- [ ] Push-Zustellung und App-Check-Metriken in einer ausdrücklich freigegebenen
  Staging-/Live-Prüfung kontrollieren
- [ ] Interne Testergruppe ausrollen und Feedbackrunde durchführen

Diese Punkte sind keine fehlgeschlagenen lokalen Gate-6-Prüfungen. Sie verändern
externe Systeme und benötigen deshalb eine gesonderte Freigabe. In Gate 6 wurde
nichts deployt, in die Play Console hochgeladen oder veröffentlicht.
