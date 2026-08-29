# plaqa Medium Security Remediation

Stand: 2026-08-29
Branch: `main`
Ausgangsbasis: `ff1246281cf32a01a245304e06895844be093861`

## Ergebnis

SEC-006 bis SEC-011 sind lokal vollständig behoben. Die App-Funktionen wurden
nicht fachlich erweitert; geändert wurden Vertrauensgrenzen, Validierung,
Quoten, Zugriffskontrollen und sichere Dateiverarbeitung. Es wurde nichts
deployt, hochgeladen oder veröffentlicht.

## Umgesetzte Kontrollen

| Bereich | Kontrolle |
|---|---|
| Kontaktanfragen | Auth und App Check, serverseitig abgeleitete Nutzer-/Fahrzeugdaten, Einmal-Grant aus einer erfolgreichen Kennzeichensuche, striktes Schema, Ablaufzeit, Sender-/Zielquote und Cooldown |
| Externe Medien | HTTPS, exakter Firebase-Host und Produktions-Bucket, erlaubte Query-Parameter, dekodierter Objektpfad und Pfadbindung an den gespeicherten Storage-Pfad |
| Android-Dateien | nicht exportierter FileProvider, ausschließlich kanonische App-Dateipfade, Redirect-Revalidierung, Timeouts, Byteobergrenzen, MIME-Allowlist und Dateisignaturen |
| Profilbilder | Storage-Lesen nur für Eigentümer oder aktive Verbindung; jede Clientprojektion an die UID und `profile_photos/{uid}/profile.png` gebunden |
| Profilaufrufe | autorisierter Callable, aktive Profilverbindung, tägliche Deduplizierung, Quote und ausschließlich servereigene Zählerfelder |
| Kontolöschung | Sender, Empfänger, Viewer, Suchender und Ziel werden innerhalb derselben Schreibtransaktion gegen Löschreservierungen geprüft; Profilfoto-Sync aktualisiert nur noch vorhandene Dokumente |

## Security-Diff-Nachprüfung

| Scan | Ergebnis |
|---|---|
| `a014673b-dab8-4086-9cc3-eb36d2837649` | vier mittlere externe Avatarpfade gefunden und anschließend UID-gebunden |
| `92b54b9a-ee50-4686-9498-8f0821689d04` | drei niedrige Zielkonto-Lösch-Races gefunden und geschlossen |
| `11f9793b-0ba0-4d9f-9330-b3e97e935c70` | fünf niedrige Aufrufer-/Trigger-Lösch-Races gefunden und geschlossen |
| `be9553ca-7f13-42fa-82d5-dbc79c9acef5` | finaler Snapshot, Digest `aaa3f54d5b346a0fccc4c933efc55c9fd28e73210ccffb9d11416184cab8ed54`, 24/24 Prüfflächen, **0 Befunde** |

Finaler Bericht:
`C:/Users/Admin/AppData/Local/Temp/codex-security-scans-Aykitv/plaqa/ff1246281cf32a01a245304e06895844be093861_20260829T205259Z_ceg8_wus/report.md`

## Vollständige Regression

- Flutter Unit/Widget: 245/245
- Flutter Analyze: keine Befunde
- Firebase Functions: 136/136; Syntaxcheck bestanden
- Firestore-/Storage-Rules: 110/110 in der Emulator Suite
- Website: 30/30
- iOS-Windows-Konfiguration: 126/126
- Git-Diff-Check: keine Whitespace-Fehler

## Android-Artefakte

| Artefakt | Bytes | SHA-256 |
|---|---:|---|
| `build/app/outputs/bundle/release/app-release.aab` | 74.141.658 | `7C2828CF8A2BCE53019F8865A46F59A98315952969974047932436E469DC6A34` |
| `build/app/outputs/flutter-apk/app-release.apk` | 86.311.712 | `56A8D8A83D6835B519D83650DCA22E9C0666B77C7FC9C7C3BAD5F7B7A88C5085` |

Bundletool, APK-/AAB-Signatur, genau ein APK-Signierer, 16-KiB-Alignment,
Paketdaten, targetSdk 36 und das nicht debugfähige Release-Manifest wurden
bestätigt.

## Echter Redmi-Release-Smoke

Die Release-APK wurde auf Redmi `2201117TY`, Android 13/API 33, installiert und
bytegenau zurückgelesen. Drei Kaltstarts, der Release-Maestro-Flow, visuelle
Login-Kontrolle, Runtime-Log und Speicherprüfung bestanden. Es gab keine
Crash-, ANR-, Null-Check- oder RenderFlex-Treffer.

Vorherige Debug-APK und App-Daten wurden vor der Installation gesichert. Nach
dem Test wurden die byteidentische Debug-APK und 34 interne Datendateien
wiederhergestellt; die App startete und das Gerät wurde gesperrt.

## Verbleibende externe Grenzen

Offen bleiben reale Mac-/Xcode-/iPhone-/TestFlight-Abnahme, produktive Push- und
App-Check-Metriken, Firebase-Betriebsfreigaben sowie Store-, Datenschutz-,
Moderations- und Rolloutprozesse. Diese Punkte wurden nicht als lokal bestanden
gewertet.
