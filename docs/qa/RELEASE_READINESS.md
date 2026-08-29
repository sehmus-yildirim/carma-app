# plaqa Release Readiness

Stand: 2026-08-29
Branch: `main`
Geprüfte Gate-6-Basis: `3ea0dc6d212238c5e55ffb808415e831bc582117`

## Gesamturteil

Der lokal ausführbare Android-Release-Candidate-Gate ist bestanden. Ein
signiertes und gehärtetes AAB sowie eine signierte APK wurden erzeugt,
unabhängig validiert und als echter Release-Build auf dem Redmi geprüft. Es
wurde nichts deployt, hochgeladen oder veröffentlicht.

plaqa ist damit noch nicht öffentlich releasebereit: Gate 7 (iOS/Mac) und Gate
8 (finale Vollabnahme einschließlich externer Store-, Push-, App-Check-,
Monitoring- und Rollback-Schritte) stehen noch aus.

## Gate-Übersicht

| Gate | Umfang | Status | Kernergebnis |
|---|---|---|---|
| 1 | Flutter Unit/Widget und Baseline | PASS | 234/234 aktuelle Gesamtregression; Analyze sauber |
| 2 | Functions und Firebase Rules | PASS | 100/100 Functions; 109/109 Rules in der Gate-6-Abschlussregression |
| 3 | Flutter-Integration | PASS | 4/4 Integrationsdateien gegen lokale Emulatoren |
| 4 | Maestro UI-Automation | PASS | 3/3 dauerhafte AVD-Flows |
| 5 | Mehrkonten und echtes Redmi | PASS LOCAL | Kernabläufe, Kamera, GPS, Lifecycle und Offline bestanden |
| 6 | Android Release Candidate | PASS LOCAL | AAB/APK signiert, validiert und Release-Smoke auf Redmi bestanden |
| 7 | iOS Readiness und Geräteabnahme | BLOCKED EXTERNAL | Mac, Xcode, Signing und iPhone/TestFlight erforderlich |
| 8 | Finaler Release Candidate | NOT STARTED | Vollregression, Store, Monitoring und Rollback folgen |

## Gate-6-Entscheidung

**GO für den nächsten Testblock, NO-GO für eine öffentliche Veröffentlichung.**

Begründung:

- keine offenen Gate-6-Build-, Signatur-, Installations- oder Startfehler
- kein offener P0-Produktfehler aus dem lokalen Android-Gate
- signierter Release-Build läuft auf dem echten Redmi ohne Crash oder ANR
- R8 und Resource Shrinking sind aktiv und validiert
- externe Play-, Push- und App-Check-Schritte wurden absichtlich nicht vorgezogen

## Verbleibende Risiken

1. Produktive Push-Zustellung und App-Check-Metriken benötigen eine freigegebene
   Staging-/Live-Geräteprüfung.
2. Einzelne erwartete Rules-Negativpfade können weiterhin die
   1.000-Ausdruck-Grenze protokollieren; die geprüften legitimen Pfade sind grün.
3. iOS kann unter Windows nicht abschließend gebaut, signiert oder auf einem
   iPhone/TestFlight abgenommen werden.
4. Store-Angaben, Rechtstexte, Data Safety, Zielgruppe und Content Rating
   benötigen eine abschließende fachliche beziehungsweise rechtliche Abnahme.
5. Gate 8 muss die vollständige Regression, Monitoring, Rollback und den
   kontrollierten internen Store-Rollout zusammenführen.

## Nachweise

- Android-Details: `docs/qa/ANDROID_RELEASE_CHECKLIST.md`
- Testfälle: `docs/qa/TEST_MATRIX.md`
- bekannte Fehler und Beobachtungen: `docs/qa/BUG_REGISTER.md`
- verbindlicher Gesamtplan: `docs/qa/MASTER_TEST_PLAN.md`
- aktueller Übergabestand: `docs/qa/SESSION_HANDOVER.md`
