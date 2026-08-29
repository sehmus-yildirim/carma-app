# plaqa Release Readiness

Stand: 2026-08-29
Branch: `main`
Gate-8-Ausgangsbasis: `a8ebd42a9a039f70ff17a50e85adce43f4fdf077`

## Gesamturteil

**Gate 8 ist vollständig abgeschlossen. Öffentlicher Release: NO-GO.**

Der lokale Android-Release-Candidate wurde frisch gebaut, signiert und als
Artefakt validiert. Die Flutter-, Functions-, Rules-, Website- und
iOS-Windows-Regressionssuiten sind grün. Zwei reale Releasefehler wurden
korrigiert und durch Tests abgesichert. Es wurde nichts deployt, hochgeladen,
veröffentlicht oder produktiv erzwungen.

Alle fünf hohen und sechs mittleren Sicherheitsbefunde sind lokal behoben,
regressionsgetestet und durch einen finalen Security-Diff-Scan ohne Befund
nachgeprüft. Die öffentliche Veröffentlichung bleibt gesperrt, weil externe
Nachweise für iOS, Push, App Check, Stores sowie rechtliche und betriebliche
Prozesse offen sind.

## Gate-Übersicht

| Gate | Umfang | Status | Kernergebnis |
|---|---|---|---|
| 1 | Flutter Unit/Widget und Baseline | PASS | Baseline aufgebaut; Analyze sauber |
| 2 | Functions und Firebase Rules | PASS | 136/136 Functions; 110/110 Rules nach vollständiger Security-Remediation |
| 3 | Flutter-Integration | PASS | 4/4 Integrationsdateien gegen lokale Emulatoren |
| 4 | Maestro UI-Automation | PASS | 3/3 dauerhafte AVD-Flows |
| 5 | Mehrkonten und echtes Redmi | PASS LOCAL | Kernabläufe, Kamera, GPS, Lifecycle und Offline bestanden |
| 6 | Android Release Candidate | PASS LOCAL | signierter Geräte-Smoke und Artefaktprüfung bestanden |
| 7 | iOS Readiness | PASS WINDOWS / MANUAL REQUIRED | jetzt 126/126 Konfigurationschecks; Mac/iPhone offen |
| 8 | Finale technische und Release-Abnahme | COMPLETE LOCAL / PUBLIC NO-GO | 245/245 Flutter; 11/11 Sicherheitsbefunde lokal behoben; externe Freigaben offen |

## Frische Gate-8-Nachweise

- Flutter Analyze: keine Befunde
- Flutter Unit-/Widget-Tests: 245/245
- Functions: 136/136
- Firestore-/Storage-Rules: 110/110
- Website: 30/30
- iOS-Windows-Konfiguration: 126/126
- Android AAB: 74.141.658 Bytes, SHA-256
  `7C2828CF8A2BCE53019F8865A46F59A98315952969974047932436E469DC6A34`
- Android APK: 86.311.712 Bytes, SHA-256
  `56A8D8A83D6835B519D83650DCA22E9C0666B77C7FC9C7C3BAD5F7B7A88C5085`
- AAB validiert; APK signiert, 16-KiB-ausgerichtet, nicht debuggable,
  `targetSdk 36`
- Ausgangsscan: 11 bestätigt, 5 `HIGH`, 6 `MEDIUM`
- High-Security-Remediation: 5/5 lokal behoben und regressionsgetestet
- Medium-Security-Remediation: 6/6 lokal behoben und regressionsgetestet
- Finaler Security-Diff-Scan: `be9553ca-7f13-42fa-82d5-dbc79c9acef5`,
  `24/24` Prüfflächen, 0 Befunde
- Echter Redmi-Release-Smoke: byteidentische APK, drei erfolgreiche Kaltstarts,
  Maestro grün, keine Crash-/ANR-/Flutter-Fehler; Debug-App und Daten danach
  wiederhergestellt

## Gate-8-Entscheidung

**GO für gezielte Fehlerbehebung und erneute interne Validierung. NO-GO für
Store-Upload, TestFlight, öffentlichen Rollout oder App-Check-Erzwingung.**

Die Sperre wird erst aufgehoben, wenn:

1. iOS/Mac/iPhone/TestFlight real bestanden sind,
2. Push und App Check auf signierten Builds mit echten Metriken geprüft sind,
3. Store-, Datenschutz-, Kinderschutz-, Moderations-, Export-, Monitoring- und
   Rollbackprozesse verantwortet und nachgewiesen sind.

## Nachweise

- Gate-8-Entscheidung: `docs/qa/GATE_8_RELEASE_DECISION.md`
- Sicherheitsbericht: `docs/qa/SECURITY_REVIEW.md`
- High-Security-Remediation: `docs/qa/HIGH_SECURITY_REMEDIATION.md`
- Medium-Security-Remediation: `docs/qa/MEDIUM_SECURITY_REMEDIATION.md`
- Android: `docs/qa/ANDROID_RELEASE_CHECKLIST.md`
- iOS: `docs/qa/IOS_RELEASE_CHECKLIST.md`
- manuelle Abnahme: `docs/qa/MANUAL_TEST_CHECKLIST.md`
- Monitoring/Rollback: `docs/qa/MONITORING_ROLLBACK_PLAN.md`
- Testmatrix: `docs/qa/TEST_MATRIX.md`
- Fehlerregister: `docs/qa/BUG_REGISTER.md`
