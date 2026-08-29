# plaqa QA Session Handover

Stand: 2026-08-29
Repository: `C:\Projects\plaqa`

## Aktueller Stand

- Die statische Bestandsaufnahme und der vollständige Masterplan wurden erstellt.
- Die Testwerkzeuge wurden lokal eingerichtet.
- Block 1, Flutter Unit- und Widget-Tests, ist vollständig abgeschlossen.
- Block 2, Functions- und Firebase-Rules-Tests, ist vollständig abgeschlossen.
- Block 3, Flutter-Integrationstests gegen lokale Firebase-Emulatoren, ist
  vollständig abgeschlossen.
- Block 4, ausgewählte Maestro-Black-box-Flows auf dem lokalen Android-AVD, ist
  vollständig abgeschlossen.
- Block 5, lokale Mehrkontenabläufe und echte Gerätetests auf dem Redmi, ist im
  sicher lokal ausführbaren Umfang vollständig abgeschlossen.
- Ein bestätigter Produktfehler wurde minimal korrigiert: Die Kennzeichensuche
  respektiert nun auch in der UI die deaktivierte Monatsbegrenzung und blendet
  den Kontingentstatus im Launch-Modus aus.
- Ein bestätigtes Rennen bei der Kontoanlage wurde minimal korrigiert: Nur das
  Auth-Gate legt die erforderlichen Firestore-Basisdaten an; Login und
  Registrierung starten keine konkurrierende zweite Bereitstellung mehr.
- Es wurde nichts deployt, hochgeladen oder veröffentlicht.
- Der verbindliche Ablauf steht in `docs/qa/MASTER_TEST_PLAN.md`.

## Git-Basis

- Branch: `main`
- Arbeitsbasis vor Block 5: `1cdb90afdb377082f9e50ce5d501c5b439e2fead`
- `main` und `origin/main` waren vor Block 5 synchron.
- Die Block-5-Änderungen werden nach Abschlusskontrolle gemeinsam committet und
  zu `origin/main` gepusht.

## Zuletzt abgeschlossen

- Inventar von 40 vorhandenen Flutter-Testdateien
- Ausgangslauf mit 207 von 207 bestandenen Tests
- 24 neue kritische Regressionstests für Feature-Gates, Firestore-Pfade,
  Verifizierungsanforderungen und zentrale Domainmodelle
- Abschlusslauf und Coverage-Lauf mit jeweils 231 von 231 bestandenen Tests
- `flutter analyze --no-pub` ohne Befund
- `git diff --check` ohne Fehler
- Syntaxprüfung aller 23 eigenen Functions-JavaScriptdateien mit Node 22
- 100 von 100 Functions-Tests aus zehn Testdateien bestanden
- 104 von 104 Firestore-/Storage-Rules-Tests aus elf Testdateien bestanden
- Emulatoren zwischen den Rules-Dateien neu gestartet; Abschlussports frei
- 4 von 4 Flutter-Integrationsdateien auf dem dedizierten Android-AVD bestanden
- App-Start, lokale Firebase-Verbindung, vollständige Registrierungsbasisdaten
  sowie Registrierung und Login über die echte Flutter-Oberfläche bestanden
- vollständige Flutter-Regression nach Block 3 mit 234 von 234 Tests bestanden
- abschließendes `flutter analyze --no-pub` ohne Befund
- Maestro-Kaltstart, Fehlanmeldung und vollständige Registrierung mit
  Kennzeicheneingabe und zentraler Navigation als 3 von 3 Flows bestanden
- gemeinsamer Maestro-Abschlusslauf in 4 Minuten 12 Sekunden bestanden
- vollständige Flutter-Regression nach Block 4 mit 234 von 234 Tests bestanden
- lokaler Profile-Build gegen die vollständige Firebase Emulator Suite genutzt;
  Release-Konfiguration, Produktionsdaten und App Check blieben unverändert
- lokaler Zwei-Konten-Ablauf aus Suche, Anfrage, Annahme, zwei Nachrichten und
  Blockierung auf dem Redmi vollständig bestanden
- Backendstatus und drei Nachrichten mit korrekten Absendern nachgewiesen
- Kamera, GPS, Berechtigungsstatus, Lifecycle, Session-Wiederherstellung,
  Offline-Zustand und Wiederverbindung auf dem Redmi bestanden
- drei Online-Kaltstarts zwischen 1.567 und 1.600 ms; 256.482 KB Total PSS;
  keine Flutter-Ausnahme, kein ANR und kein erkannter Layoutüberlauf
- Abschlussregression mit 234/234 Flutter- und 109/109 Rules-/Security-Tests;
  `flutter analyze --no-pub` ohne Befund
- authentifizierter Functions-Emulator-Nachweis: lokale Fahrzeugbildgenerierung
  wird in 62 ms abgewiesen und kann keinen externen Vertex-Aufruf auslösen

## Laufender Workstream

- Keiner; Block 1 bis Block 5 sind im jeweils freigegebenen Umfang abgeschlossen.

## Testergebnisse

- Flutter-Tests: `PASS` - 231/231, sequenzieller Abschlusslauf
- Flutter-Coverage: `PASS` - 7.238/36.333 Zeilen, 19,9 Prozent
- Flutter Analyze: `PASS` - keine Befunde
- Functions-Syntax: `PASS` - 23/23 eigene JavaScriptdateien unter Node 22
- Functions-Tests: `PASS` - 100/100 aus zehn Testdateien
- Firestore-/Storage-Rules-Tests: `PASS` - 109/109 nach Block 5
- Flutter-Integrationstests: `PASS` - 4/4 Dateien auf lokalem Android-AVD
- Maestro UI-Automation: `PASS` - 3/3 dauerhafte Flows in 4m 12s
- Flutter-Gesamtregression: `PASS` - 234/234 nach Block 5
- Redmi Mehrkonten-/Gerätetests: `PASS` - lokaler Block-5-Umfang
- Kamera/GPS/Lifecycle/Offline: `PASS` - echtes Redmi
- Push-Zustellung: `MANUAL REQUIRED` - kein lokaler Messaging-Emulator
- Produktive App-Check-Gerätevalidierung: `MANUAL REQUIRED`
- Website-Tests: `NOT RUN`
- Android Debug-/Release-Build: `NOT RUN`
- Mehrkonten-/echte Gerätetests: `PASS` - lokaler/Redmi-Umfang
- iOS-Build: `BLOCKED` bis Mac/Xcode verfügbar und freigegeben ist

## Bekannte priorisierte Risiken

1. Push und App Check benötigen eine ausdrücklich freigegebene Staging-/Live-
   Geräteprüfung; Block 5 hat produktive Systeme bewusst nicht verwendet
2. Verdächtige Onboarding-Verzweigung, die in beiden Fällen Onboarding als abgeschlossen markiert
3. Keine CI-Pipeline
4. Kontolöschung und Verifizierungs-Cleanup noch nicht end-to-end nachgewiesen
5. Android-Release-Smoke-Test und iOS-Mac-Abnahme offen
6. Einzelne erwartete Rules-Negativpfade protokollieren weiterhin die Emulator-
   Grenze von 1.000 Ausdrücken; der legitime Mehrkontenpfad wurde korrigiert und
   besteht auf dem Redmi sowie in der Rules-Regression

## Nächste konkrete Aktion

Den Abschluss von Block 5 gemeinsam besprechen und danach den nächsten
freigegebenen Testblock beginnen. Produktive Push-/App-Check-Prüfungen bleiben
getrennt und dürfen nicht stillschweigend vorgezogen werden.

## Erforderliche Entscheidung

Der Nutzer entscheidet über den Start des nächsten Blocks und über jeden
Staging-/Live-Test. Es wurde in Block 5 nichts deployt oder veröffentlicht.
