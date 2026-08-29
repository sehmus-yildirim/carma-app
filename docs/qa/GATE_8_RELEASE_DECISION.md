# plaqa Gate 8 Release Decision

Stand: 2026-08-29
Branch: `main`
Status: **GATE 8 COMPLETE / PUBLIC RELEASE NO-GO**

## Entscheidung

Gate 8 ist im lokal und unter Windows ausführbaren Umfang vollständig beendet.
Der Android-Release-Candidate ist technisch gebaut, signiert und validiert. Die
Gesamtregression ist grün. Es wurde nichts deployt, in einen Store hochgeladen,
veröffentlicht oder in Firebase produktiv erzwungen.

Eine öffentliche Veröffentlichung ist noch nicht freigegeben. Die fünf hohen
Sicherheitsbefunde sind lokal behoben und regressionsgetestet; sechs mittlere
Befunde bleiben offen. Zusätzlich fehlen reale iOS-, Push-, App-Check-, Store-
und betriebliche Nachweise.

## Bestandene technische Nachweise

- Flutter Analyze: keine Befunde
- Flutter Unit-/Widget-Regression: 237/237
- Functions: 111/111
- Firestore-/Storage-Rules: 111/111
- Website: 30/30
- iOS-Windows-Konfiguration: 126/126
- Android AAB: 74.136.367 Bytes, SHA-256
  `65D9F708B7E5C05099DC0034AF910DC9AAA3A0B2B2A41568935D54638533174A`
- Android APK: 86.311.256 Bytes, SHA-256
  `FF226D7DFFAC3B52076831D50599BAE526E1DA47065BA904511390F85A168DAC`
- AAB mit bundletool 1.18.3 validiert
- APK-Signatur, ein Signierer, v2-Signatur und 16-KiB-Alignment bestätigt
- Paket `de.plaqa.app`, Version `1.0.0+1`, minSdk 24, targetSdk 36

## In Gate 8 korrigiert

1. Die iOS-Firebase-App-ID in `firebase.json` verwies auf die macOS-App. Sie ist
   jetzt korrekt der iOS-App zugeordnet und wird automatisch gegen
   `GoogleService-Info.plist` geprüft.
2. Das Onboarding war nicht dauerhaft an den Profilzustand gebunden. Neue
   Profile starten jetzt mit `onboardingCompleted: false`; erfolgreicher
   Abschluss wird gespeichert und durch drei neue Tests abgesichert.
3. Verwundbare transitive npm-Versionen für `brace-expansion` und
   `fast-xml-parser` wurden innerhalb kompatibler Paketbereiche aktualisiert.

## Öffentliche Releaseblocker

### Sicherheit

- SEC-001 bis SEC-005 sind lokal behoben; vollständige technische Nachweise
  stehen in `docs/qa/HIGH_SECURITY_REMEDIATION.md`
- sechs mittlere Befunde betreffen Kontaktanfragen, Mediensicherheit,
  Profilfotos und missbrauchbare Zähler

Vollständige technische Details stehen in `docs/qa/SECURITY_REVIEW.md` und im
versiegelten Codex-Security-Scan
`d316c0fd-3693-447f-badf-1864041b52df`. Die Änderungen wurden zusätzlich mit
dem Security-Diff-Scan `0f935310-dca6-4856-ba34-a4d8c9591041` geprüft; zwei im
Zwischenstand erkannte Umgehungen wurden danach geschlossen und regressions-
getestet.

### Extern und manuell

- App-Check-Metriken auf echten signierten Builds prüfen; Erzwingung erst nach
  gesonderter Freigabe
- Push foreground/background/terminated mit echtem Backend prüfen
- Mac/Xcode-26-Build, Signierung, IPA, iPhone und TestFlight abschließen
- Play-/App-Store-Texte, Data Safety, Datenschutz, Zielgruppe, Content Rating,
  Kinderschutz und Moderationsprozesse fachlich/rechtlich freigeben
- Datenexport-, Lösch-, Incident-, Monitoring- und Rollbackverantwortliche
  benennen und reale Übungen protokollieren
- erforderliche Testspuren und Store-Review vollständig durchführen

## Android-Gerätehinweis

Der frische Gate-8-Release-Smoke auf einem neu aufgesetzten AVD konnte wegen
einer lokalen ADB-Autorisierungsstörung des Emulators nicht wiederholt werden.
Das Redmi wurde bewusst nicht deinstalliert oder überschrieben, weil dies seine
vorhandenen App-Daten gelöscht hätte. Der echte Release-Smoke aus Gate 6 bleibt
als bestehender Gerätenachweis erhalten; Gate 8 bewertet die neue APK deshalb
statisch und als signiertes Artefakt, nicht als neuen Geräte-PASS.

## Wiederfreigabe

Die lokale Bedingung für die fünf hohen Sicherheitsbefunde ist erfüllt. Ein
öffentliches `GO` ist erst zulässig, wenn die mittleren Befunde risikoseitig
geschlossen oder ausdrücklich akzeptiert und sämtliche externen Punkte mit
realen Nachweisen abgeschlossen sind. Deployment, App-Check-Erzwingung,
Store-Upload und Veröffentlichung benötigen jeweils eine ausdrückliche
Freigabe.
