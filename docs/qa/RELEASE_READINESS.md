# plaqa Release Readiness

Stand: 2026-08-29
Branch: `main`
Geprüfte Gate-7-Windows-Basis: `3ad20157b0930e613235e112528d21c35e1860e7`

## Gesamturteil

Der lokale Android-Release-Candidate-Gate und die vollständige, unter Windows
zuverlässig ausführbare iOS-Vorbereitung sind bestanden. Die iOS-Konfiguration
wird jetzt durch 124 automatische Prüfungen geschützt. Es wurde nichts deployt,
hochgeladen oder veröffentlicht.

plaqa ist damit noch nicht öffentlich releasebereit: Die externe Hälfte von
Gate 7 auf Mac/Xcode/iPhone/TestFlight und Gate 8 mit Vollabnahme, Store, Push,
App Check, Monitoring und Rollback stehen noch aus.

## Gate-Übersicht

| Gate | Umfang | Status | Kernergebnis |
|---|---|---|---|
| 1 | Flutter Unit/Widget und Baseline | PASS | 234/234 aktuelle Gesamtregression; Analyze sauber |
| 2 | Functions und Firebase Rules | PASS | 100/100 Functions; 109/109 Rules in der Gate-6-Abschlussregression |
| 3 | Flutter-Integration | PASS | 4/4 Integrationsdateien gegen lokale Emulatoren |
| 4 | Maestro UI-Automation | PASS | 3/3 dauerhafte AVD-Flows |
| 5 | Mehrkonten und echtes Redmi | PASS LOCAL | Kernabläufe, Kamera, GPS, Lifecycle und Offline bestanden |
| 6 | Android Release Candidate | PASS LOCAL | AAB/APK signiert, validiert und Release-Smoke auf Redmi bestanden |
| 7 | iOS Readiness und Geräteabnahme | PASS WINDOWS / MANUAL REQUIRED | 124/124 Konfigurationschecks; Mac, Signing und iPhone/TestFlight offen |
| 8 | Finaler Release Candidate | NOT STARTED | Vollregression, Store, Monitoring und Rollback folgen |

## Gate-7-Entscheidung

**GO für Gate 8 beziehungsweise die spätere Mac-Abnahme, NO-GO für eine
öffentliche Veröffentlichung.**

Begründung:

- Android Gate 6 bleibt vollständig grün
- iOS-Bundle, Firebase, Berechtigungstexte, Entitlements, Capabilities,
  Lifecycle und Icons bestehen 124 Windows-Prüfungen
- Push Notifications, Background fetch, Remote notifications und App Attest
  sind im Projekt vorbereitet
- kein offener P0-Produktfehler aus Gate 7
- frische Abschlussregression mit Flutter 234/234, Functions 100/100, Rules
  109/109, Website 30/30 und Analyze ohne Befund
- Apple-Portal-, Signing-, iPhone- und Store-Schritte wurden nicht vorgetäuscht

## Verbleibende Risiken

1. Produktive Push-Zustellung und App-Check-Metriken benötigen eine freigegebene
   Staging-/Live-Geräteprüfung.
2. Einzelne erwartete Rules-Negativpfade können weiterhin die
   1.000-Ausdruck-Grenze protokollieren; die geprüften legitimen Pfade sind grün.
3. iOS kann unter Windows nicht gebaut, signiert oder auf iPhone/TestFlight
   abgenommen werden; dafür ist die verbindliche Mac-Liste dokumentiert.
4. Store-Angaben, Rechtstexte, Data Safety, Zielgruppe und Content Rating
   benötigen eine abschließende fachliche beziehungsweise rechtliche Abnahme.
5. Gate 8 muss die vollständige Regression, Monitoring, Rollback und den
   kontrollierten internen Store-Rollout zusammenführen.

## Nachweise

- Android-Details: `docs/qa/ANDROID_RELEASE_CHECKLIST.md`
- iOS-Details: `docs/qa/IOS_RELEASE_CHECKLIST.md`
- Testfälle: `docs/qa/TEST_MATRIX.md`
- bekannte Fehler und Beobachtungen: `docs/qa/BUG_REGISTER.md`
- verbindlicher Gesamtplan: `docs/qa/MASTER_TEST_PLAN.md`
- aktueller Übergabestand: `docs/qa/SESSION_HANDOVER.md`
