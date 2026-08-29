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

Die fünf hohen Sicherheitsbefunde sind lokal behoben und regressionsgetestet.
Die öffentliche Veröffentlichung bleibt gesperrt, weil sechs mittlere Befunde
und externe Nachweise für iOS, Push, App Check, Stores sowie rechtliche und
betriebliche Prozesse offen sind.

## Gate-Übersicht

| Gate | Umfang | Status | Kernergebnis |
|---|---|---|---|
| 1 | Flutter Unit/Widget und Baseline | PASS | Baseline aufgebaut; Analyze sauber |
| 2 | Functions und Firebase Rules | PASS | 111/111 Functions; 111/111 Rules nach High-Security-Remediation |
| 3 | Flutter-Integration | PASS | 4/4 Integrationsdateien gegen lokale Emulatoren |
| 4 | Maestro UI-Automation | PASS | 3/3 dauerhafte AVD-Flows |
| 5 | Mehrkonten und echtes Redmi | PASS LOCAL | Kernabläufe, Kamera, GPS, Lifecycle und Offline bestanden |
| 6 | Android Release Candidate | PASS LOCAL | signierter Geräte-Smoke und Artefaktprüfung bestanden |
| 7 | iOS Readiness | PASS WINDOWS / MANUAL REQUIRED | jetzt 126/126 Konfigurationschecks; Mac/iPhone offen |
| 8 | Finale technische und Release-Abnahme | COMPLETE / PUBLIC NO-GO | 237/237 Flutter; 5 hohe Befunde lokal behoben, 6 mittlere offen; externe Freigaben offen |

## Frische Gate-8-Nachweise

- Flutter Analyze: keine Befunde
- Flutter Unit-/Widget-Tests: 237/237
- Functions: 111/111
- Firestore-/Storage-Rules: 111/111
- Website: 30/30
- iOS-Windows-Konfiguration: 126/126
- Android AAB: 74.136.367 Bytes, SHA-256
  `65D9F708B7E5C05099DC0034AF910DC9AAA3A0B2B2A41568935D54638533174A`
- Android APK: 86.311.256 Bytes, SHA-256
  `FF226D7DFFAC3B52076831D50599BAE526E1DA47065BA904511390F85A168DAC`
- AAB validiert; APK signiert, 16-KiB-ausgerichtet, nicht debuggable,
  `targetSdk 36`
- Ausgangsscan: 11 bestätigt, 5 `HIGH`, 6 `MEDIUM`
- High-Security-Remediation: 5/5 lokal behoben und regressionsgetestet
- Security-Diff-Scan: `0f935310-dca6-4856-ba34-a4d8c9591041`; zwei erkannte
  Zwischenstands-Umgehungen anschließend geschlossen

## Gate-8-Entscheidung

**GO für gezielte Fehlerbehebung und erneute interne Validierung. NO-GO für
Store-Upload, TestFlight, öffentlichen Rollout oder App-Check-Erzwingung.**

Die Sperre wird erst aufgehoben, wenn:

1. die sechs mittleren Befunde behoben oder formal mit Frist akzeptiert sind,
2. nach diesen Änderungen ein neuer Security-Diff-Scan und die vollständige
   Regression grün sind,
3. iOS/Mac/iPhone/TestFlight real bestanden sind,
4. Push und App Check auf signierten Builds mit echten Metriken geprüft sind,
5. Store-, Datenschutz-, Kinderschutz-, Moderations-, Export-, Monitoring- und
   Rollbackprozesse verantwortet und nachgewiesen sind.

## Nachweise

- Gate-8-Entscheidung: `docs/qa/GATE_8_RELEASE_DECISION.md`
- Sicherheitsbericht: `docs/qa/SECURITY_REVIEW.md`
- High-Security-Remediation: `docs/qa/HIGH_SECURITY_REMEDIATION.md`
- Android: `docs/qa/ANDROID_RELEASE_CHECKLIST.md`
- iOS: `docs/qa/IOS_RELEASE_CHECKLIST.md`
- manuelle Abnahme: `docs/qa/MANUAL_TEST_CHECKLIST.md`
- Monitoring/Rollback: `docs/qa/MONITORING_ROLLBACK_PLAN.md`
- Testmatrix: `docs/qa/TEST_MATRIX.md`
- Fehlerregister: `docs/qa/BUG_REGISTER.md`
