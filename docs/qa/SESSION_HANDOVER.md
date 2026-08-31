# plaqa QA Session Handover

Stand: 2026-08-29
Repository: `C:\Projects\plaqa`
Branch: `main`

## Aktueller Stand

Gate 1 bis Gate 8 sind im jeweils lokal beziehungsweise unter Windows
ausführbaren Umfang abgeschlossen. Gate 8 trägt **COMPLETE / PUBLIC NO-GO**.
Die Prüfung ist beendet; offen ist nicht der Test, sondern die Behebung der
ermittelten Releaseblocker und deren erneute Abnahme.

Es wurde nichts deployt, in Google Play oder App Store Connect hochgeladen,
veröffentlicht oder durch App Check produktiv erzwungen.

## Gate-8-Änderungen

- iOS-Firebase-App-ID in `firebase.json` korrigiert und in den dauerhaften
  Windows-Validator aufgenommen
- Onboardingzustand für neue Konten auf `false` gesetzt, Abschluss persistent
  gemacht und Lade-/Fehlerzustand abgesichert
- drei Onboarding-Unit-/Widgettests ergänzt
- zwei hohe transitive npm-Advisories durch kompatible Lockfile-Updates behoben
- frische signierte Android-AAB/APK gebaut und validiert
- finalen Standard-Security-Scan ausgeführt und versiegelt
- Releaseentscheidung, Security-Bericht, manuelle Testliste sowie Monitoring-
  und Rollbackplan dauerhaft dokumentiert

## Frische Ergebnisse

| Prüfung | Ergebnis |
|---|---|
| Flutter Analyze | PASS, keine Befunde |
| Flutter Unit/Widget | PASS, 237/237 |
| Functions | PASS, 100/100 |
| Firestore/Storage Rules | PASS, 109/109 |
| Website | PASS, 30/30 |
| iOS-Windows-Konfiguration | PASS, 126/126 |
| Android AAB | PASS, 74.136.367 Bytes, SHA-256 `65D9F708B7E5C05099DC0034AF910DC9AAA3A0B2B2A41568935D54638533174A` |
| Android APK | PASS, 86.311.256 Bytes, SHA-256 `FF226D7DFFAC3B52076831D50599BAE526E1DA47065BA904511390F85A168DAC` |
| Security | 11 bestätigt: 5 hoch, 6 mittel |
| öffentlicher Release | NO-GO |

## Android-Gerätezustand

Das Redmi `2201117TY` enthält weiterhin die vorherige Debug-App und ihre Daten.
Die frische Release-APK wurde dort nicht überinstalliert, weil die abweichende
Signatur eine Deinstallation und damit Datenverlust erfordert hätte. Der
dedizierte, zuvor gewischte AVD blieb trotz ADB-Neustart und deaktiviertem
Auth-Dialog `unauthorized`. Gate 6 enthält weiterhin den bestandenen echten
Release-Smoke; Gate 8 behauptet für den Neubau keinen Geräte-PASS.

## Öffentliche Releaseblocker

1. SEC-001 bis SEC-005: hohe Befunde zu Standort, Kosten/Quoten, Storage und
   unvollständiger Kontolöschung
2. SEC-006 bis SEC-011: mittlere Befunde zu Kontaktanfragen, Medien-URLs,
   nativen URI-Sinks, Profilfotos und Profilaufrufen
3. App-Check-Metriken und Push auf signierten echten Builds
4. Mac/Xcode 26, iOS-Archiv, Signing, iPhone und TestFlight
5. Store Listing, Datenschutz/Data Safety/App Privacy, Altersfreigabe,
   Kinderschutz, Moderation und UGC-Prozesse
6. realer Datenexport-, Monitoring-, Incident- und Rollbackprozess
7. erforderliche interne/geschlossene Testspuren und fachliche Freigaben

## Nächste konkrete Aktion

Mit SEC-001 beginnen und jeden Security-Befund in einer getrennten Änderung
beheben. Für jede Änderung zuerst einen fehlgeschlagenen Regressionstest
ergänzen, dann minimal korrigieren, die vollständigen betroffenen Suiten laufen
lassen und anschließend einen Security-Diff-Scan ausführen. Neue Artefakte erst
nach Abschluss aller hohen Befunde bauen.

## Verbindliche Dokumente

- `docs/qa/GATE_8_RELEASE_DECISION.md`
- `docs/qa/SECURITY_REVIEW.md`
- `docs/qa/RELEASE_READINESS.md`
- `docs/qa/TEST_MATRIX.md`
- `docs/qa/MANUAL_TEST_CHECKLIST.md`
- `docs/qa/MONITORING_ROLLBACK_PLAN.md`
- `docs/qa/ANDROID_RELEASE_CHECKLIST.md`
- `docs/qa/IOS_RELEASE_CHECKLIST.md`

Store-Upload, Deployment, App-Check-Erzwingung und Veröffentlichung bleiben
gesondert freigabepflichtig.

## Live-Test-Zwischenstand 2026-08-31

Der aktuelle signierte Release-Build wurde auf dem Redmi `cf1d4c97` mit zwei
synthetischen Produktionskonten geprüft. Bestätigt sind Anmeldung/Onboarding,
Fahrzeuganlage, Kennzeichensuche mit echtem Standort, Kontaktanfrage und
Annahme, Zwei-Wege-Chat inklusive Lesestatus, Blockieren/Entblocken,
Beitragserstellung sowie das Anfordern eines Datenexports.

Noch nicht abgeschlossen sind Follow-Annahme, Feed-Like/-Kommentar, MFA mit
echtem SMS-Code, Kontolöschung, der finale Regressionlauf, Security-Diff-Scan,
neue APK/AAB und der abschließende Redmi-Smoke-Test.

Aktive, gesicherte Test-Fixtures:

- Konto A: `Mg7IaWEnHxZ8pvyY8UnG91RRXr22`
- Konto B: `fVKPjd9JgzYj6OnqsVX2gX9A33B2`
- lokale Sicherung: `C:\Users\Admin\Documents\New project\plaqa_live_test_backup.json`
- Testhelfer: `C:\Users\Admin\Documents\New project\live_test_admin.cjs`

Die Fixtures dürfen erst nach den verbleibenden Produktionsprüfungen mit
`node live_test_admin.cjs cleanup` zurückgespielt werden. Das muss vor der
Kontolöschung von Konto B erfolgen, da die Wiederherstellung sonst Dokumente
des gelöschten Kontos neu anlegen würde.

Gefundene Live-Befunde:

1. Standortermittlung konnte auf Xiaomi unbegrenzt warten; lokaler Fix nutzt
   Timeout und den letzten bekannten Standort als Fallback.
2. Die Profilverbindung aus einem akzeptierten Chat wird im Live-Backend
   abgewiesen. Eine temporäre, gesicherte Verbindung hält die restlichen Tests
   ausführbar; Regeln und Deploymentstand müssen abgeglichen werden.
3. Nach einem Profilaufruf blockierte der geschützte `profileViewCount` die
   erneute Anmeldung, weil öffentliche Profilprojektionen ohne Merge
   geschrieben wurden. Der lokale Fix bewahrt servergeschützte Felder.
4. Die Liste blockierter Nutzer enthält korrekte Semantik, Text und Aktion,
   rendert diese auf dem Redmi aber unsichtbar und reagiert nur per
   Tastaturfokus. Dieser UI-Befund ist noch offen.
5. Ein Follow-Request wird korrekt als `requested` gespeichert, der sichtbare
   Buttonstatus aktualisiert sich im aktuellen Release jedoch nicht.

Zusätzlich ist lokal der fehlende kombinierte Firestore-Index für aktive
`chat_stories` ergänzt. Es wurde in diesem Zwischenstand nichts deployt oder
veröffentlicht.
