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
- Gate 6, gehärteter und signierter Android Release Candidate samt echtem
  Release-Smoke-Test auf dem Redmi, ist lokal vollständig abgeschlossen.
- Gate 7, iOS-Readiness, ist im vereinbarten Windows-Umfang vollständig
  abgeschlossen; Mac/Xcode/iPhone/TestFlight bleiben manuell erforderlich.
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
- Arbeitsbasis vor Gate 6: `3ea0dc6d212238c5e55ffb808415e831bc582117`
- Gate-6-Abschlusscommit:
  `7e59e7daeb1d20ee2e9fe90f99c742fd1687e14c`
- `main` und `origin/main` sind nach dem Gate-6-Push synchron.
- Arbeitsbasis vor Gate 7:
  `3ad20157b0930e613235e112528d21c35e1860e7`
- Gate-7-Implementierungs- und Abschlusscommit:
  `55e993c05671744451cccf07d122b82a13232b00`

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
- Release-Konfiguration mit R8, Resource Shrinking und 3-GB-Gradle-Grenze auf
  dem 8-GB-Windows-System erfolgreich gebaut
- signiertes AAB und APK erzeugt; AAB durch `bundletool`, APK durch
  `apksigner` und 16-KiB-`zipalign` validiert
- Release-APK auf dem Redmi installiert, bytegenau geprüft und ohne
  `DEBUGGABLE`-/Klartextfreigabe gestartet
- Release-Kaltstarts 2.439/612/495 ms und isoliert 608 ms; stabiler Zustand
  165.052 KB Total PSS und 246.320 KB Total RSS
- Maestro-Release-Smoke-Test und isolierter Runtime-Log ohne Crash, ANR,
  Null-Check-, RenderFlex- oder unbehandelte Flutter-Ausnahme
- ursprüngliche Debug-APK bytegenau wiederhergestellt und Redmi gesperrt
- Gate-6-Abschlussregression: Flutter 234/234, Functions 100/100, Rules 109/109,
  Website 30/30 und Analyze ohne Befund
- iOS-Bundle-ID, Firebase-Mapping, Mindestversion, Usage Descriptions,
  AppDelegate, SceneDelegate, Apple Login und App Check inventarisiert
- fehlende APNs-/App-Attest-Entitlements und Background-fetch-Konfiguration
  ergänzt; Push-, Background- und Apple-Login-Capabilities markiert
- alle 19 iOS-App-Icon-Slots auf Datei, Pixelmaß und Alpha-Kanal geprüft
- dauerhafter iOS-Windows-Validator mit 124/124 Prüfungen bestanden
- vollständige Mac-/Xcode-/iPhone-/TestFlight-Übergabeliste erstellt
- Gate-7-Abschlussregression: Flutter 234/234, Functions 100/100, Rules 109/109,
  Website 30/30 und Analyze ohne Befund
- Firebase-Emulatoren beendet; Ports 8080, 9199, 9150 und 4400 frei

## Laufender Workstream

- Keiner; Block 1 bis Gate 7 sind im jeweils freigegebenen lokalen Umfang
  abgeschlossen.

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
- Website-Tests: `PASS` - 30/30 in der Gate-6-Abschlussregression
- Android Release-AAB/APK: `PASS` - signiert, validiert und auf Redmi geprüft
- Android Release-Smoke: `PASS` - echtes Redmi/Android 13
- Mehrkonten-/echte Gerätetests: `PASS` - lokaler/Redmi-Umfang
- iOS-Build: `BLOCKED` bis Mac/Xcode verfügbar und freigegeben ist
- iOS-Windows-Konfiguration: `PASS` - 124/124 Prüfungen
- Gate-7-Flutter-Regression: `PASS` - 234/234
- Gate-7-Functions-Regression: `PASS` - 100/100
- Gate-7-Rules-Regression: `PASS` - 109/109
- Gate-7-Website-Regression: `PASS` - 30/30
- Gate-7-Analyze: `PASS` - keine Befunde
- iOS-Mac-Build/Signing/iPhone/TestFlight: `MANUAL REQUIRED`

## Bekannte priorisierte Risiken

1. Push und App Check benötigen eine ausdrücklich freigegebene Staging-/Live-
   Geräteprüfung; Block 5 hat produktive Systeme bewusst nicht verwendet
2. Verdächtige Onboarding-Verzweigung, die in beiden Fällen Onboarding als abgeschlossen markiert
3. Keine CI-Pipeline
4. Kontolöschung und Verifizierungs-Cleanup noch nicht end-to-end nachgewiesen
5. iOS-Mac-/Xcode-/iPhone-/TestFlight-Abnahme offen; Windows-Vorbereitung grün
6. Einzelne erwartete Rules-Negativpfade protokollieren weiterhin die Emulator-
   Grenze von 1.000 Ausdrücken; der legitime Mehrkontenpfad wurde korrigiert und
   besteht auf dem Redmi sowie in der Rules-Regression

## Nächste konkrete Aktion

Gate 8 planen und dabei die finale Vollregression, offene P0/P1-Risiken,
Monitoring, Rollback sowie getrennte Android-/iOS-Storefreigaben zusammenführen.
Die Mac-/Xcode-/iPhone-Liste aus `IOS_RELEASE_CHECKLIST.md` bleibt offen.

## Erforderliche Entscheidung

Der Nutzer entscheidet über den Start von Gate 8 und über jeden Store-,
Staging-, Apple-Portal- oder Live-Test. In Gate 7 wurde nichts deployt,
hochgeladen oder veröffentlicht.
