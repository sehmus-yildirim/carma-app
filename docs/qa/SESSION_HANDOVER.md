# plaqa QA Session Handover

Stand: 2026-08-28
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
- Commit: `dd619a9e9fe3da06258cfc0d0b2ddf8d143e21fd`
- `main` und `origin/main` waren synchron.
- Der Arbeitsbaum enthält die bewusst noch nicht committeten Toolchain-, Test-,
  Dokumentations- und Fehlerkorrekturen dieses Blocks.

## Zuletzt abgeschlossen

- Inventar von 40 vorhandenen Flutter-Testdateien
- Ausgangslauf mit 207 von 207 bestandenen Tests
- 24 neue kritische Regressionstests für Feature-Gates, Firestore-Pfade,
  Verifizierungsanforderungen und zentrale Domainmodelle
- Abschlusslauf und Coverage-Lauf mit jeweils 231 von 231 bestandenen Tests
- `flutter analyze --no-pub` ohne Befund
- `git diff --check` ohne Fehler
- Syntaxprüfung aller 21 eigenen Functions-JavaScriptdateien mit Node 22
- 98 von 98 Functions-Tests aus neun Testdateien bestanden
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
- lokale Firebase-Suite und dedizierter Test-AVD beendet; Ports 9099, 8080,
  9199, 5001, 4400 und 9150 frei; das angeschlossene Redmi nicht verwendet

## Laufender Workstream

- Keiner; Block 1 bis Block 4 sind abgeschlossen. Block 5 wurde nicht gestartet.

## Testergebnisse

- Flutter-Tests: `PASS` - 231/231, sequenzieller Abschlusslauf
- Flutter-Coverage: `PASS` - 7.238/36.333 Zeilen, 19,9 Prozent
- Flutter Analyze: `PASS` - keine Befunde
- Functions-Syntax: `PASS` - 21/21 eigene JavaScriptdateien unter Node 22
- Functions-Tests: `PASS` - 98/98 aus neun Testdateien
- Firestore-/Storage-Rules-Tests: `PASS` - 104/104 aus elf Testdateien
- Flutter-Integrationstests: `PASS` - 4/4 Dateien auf lokalem Android-AVD
- Maestro UI-Automation: `PASS` - 3/3 dauerhafte Flows in 4m 12s
- Flutter-Gesamtregression: `PASS` - 234/234 nach Block 4
- Website-Tests: `NOT RUN`
- Android Debug-/Release-Build: `NOT RUN`
- Mehrkonten-/echte Gerätetests: `NOT RUN`
- iOS-Build: `BLOCKED` bis Mac/Xcode verfügbar und freigegeben ist

## Bekannte priorisierte Risiken

1. Dokumentierter Firestore-`permission-denied`-Fehler beim Annehmen einer Kontaktanfrage; im Ein-Konto-Block 3 nicht abgedeckt
2. Verdächtige Onboarding-Verzweigung, die in beiden Fällen Onboarding als abgeschlossen markiert
3. Keine vollständigen Zwei-Konten-End-to-End-Tests; `OBS-001` bleibt bis dahin offen
4. Keine CI-Pipeline
5. App Check nur Monitoring und keine aktuelle Gerätevalidierung
6. Kontolöschung und Verifizierungs-Cleanup noch nicht end-to-end nachgewiesen
7. Android-Release-Smoke-Test und iOS-Mac-Abnahme offen
8. Emulatorwarnung zur Firestore-Grenze von 1.000 Regelausdrücken in einzelnen
   Chat-/Kontakt-Negativpfaden (`OBS-001`); noch kein positiver Nutzerpfadfehler

## Nächste konkrete Aktion

Den Abschluss von Block 4 gemeinsam besprechen. Erst danach und nur nach
ausdrücklicher Fortsetzung mit Block 5 beginnen: kontrollierte Mehrkonten- und
echte Redmi-Gerätetests mit isolierten Testdaten. Keine Livetests vorziehen.

## Erforderliche Entscheidung

Der Nutzer entscheidet, wann Block 5 startet. Bis dahin werden keine weiteren
Tests, Builds, Deployments oder Veröffentlichungen gestartet.
