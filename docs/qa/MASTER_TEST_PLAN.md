# plaqa Master-Test-, QA- und Release-Plan

Stand: 2026-08-29
Planbasis vor Gate 7: `main` / `3ad20157b0930e613235e112528d21c35e1860e7`
Status: Umsetzung begonnen; Gate 1 bis Gate 7 im jeweils lokal ausführbaren Umfang abgeschlossen

## 1. Zweck und oberstes Ziel

Dieser Plan führt plaqa schrittweise von der vorhandenen Implementierung zu einem objektiv geprüften Release-Candidate. Ein erfolgreicher Build oder eine grüne Teilmenge automatisierter Tests reicht dafür nicht aus. Automatisierte Tests, manuelle Prüfungen, Sicherheitsprüfungen, Firebase-Prüfungen und reale Gerätetests werden getrennt bewertet.

Die App darf erst als Release-Candidate bezeichnet werden, wenn die in diesem Dokument definierten Gates tatsächlich erfüllt und alle verbleibenden Risiken dokumentiert wurden.

## 2. Verbindliche Arbeitsregeln

1. Es wird immer nur ein klar abgegrenzter Workstream bearbeitet.
2. Ein neuer Workstream beginnt erst, wenn der vorherige abgeschlossen oder ausdrücklich als blockiert dokumentiert wurde.
3. Vor jeder Änderung werden Branch, Commit und Git-Arbeitsstand geprüft.
4. Fremde oder unerwartete Änderungen werden nicht zurückgesetzt.
5. Ein Test erhält nur nach tatsächlicher erfolgreicher Ausführung den Status `PASS`.
6. Weitere Statuswerte sind `FAIL`, `BLOCKED`, `NOT RUN` und `MANUAL REQUIRED`.
7. Testergebnisse, Builds, Deployments und Live-Zustände werden niemals erfunden oder aus alten Dokumenten als aktuell übernommen.
8. Produktive Firebase-Daten werden nicht für destruktive Tests verwendet.
9. Testkonten und Testdaten sind künstlich; echte Ausweise, Fahrzeugscheine, Kennzeichen und personenbezogene Daten sind ausgeschlossen.
10. Security Rules werden nicht gelockert, nur damit Tests bestehen.
11. Fehler werden minimal, nachvollziehbar und im betroffenen Bereich behoben.
12. Nach jeder Korrektur laufen die betroffenen Tests und die relevanten Regressionstests erneut.
13. Veröffentlichungen, Deployments, App-Check-Erzwingung und Store-Einreichungen benötigen eine ausdrückliche Freigabe.
14. Nach jedem größeren Schritt wird `SESSION_HANDOVER.md` aktualisiert.

## 3. Verifizierte Ausgangslage

- Repository: `C:\Projects\plaqa`
- Branch: `main`
- Ausgangscommit: `e6946630d47e474f731c1b7a50c46470d9c5cfd1`
- Lokales `main` und `origin/main` waren bei der Analyse synchron.
- Version: `1.0.0+1`
- Android-Paket-ID und iOS-Bundle-ID: `de.plaqa.app`
- Sichtbarer App-Name: `plaqa`
- Flutter-/Firebase-App mit Android-, iOS-, Web-, Windows- und macOS-Strukturen
- 203 Dart-Dateien und rund 655 Repository-Dateien
- 30 in `functions/index.js` exportierte Cloud Functions
- Firestore Rules, Storage Rules und Composite Indexes vorhanden
- Keine CI-Pipeline im Repository gefunden
- Crashlytics und Firebase Analytics sind aktuell nicht eingebunden
- Keine Keystore-, `.p8`-, Service-Account- oder `key.properties`-Dateien in der geprüften Git-Historie gefunden

Die Live-Deployments bleiben in dieser Testphase ungeprüft. Flutter-Unit- und
Widget-Testbasis, `flutter analyze`, Functions-Tests sowie Firestore-/Storage-
Rules-Tests wurden am 2026-08-27 erneut verifiziert. Die vorhandenen Flutter-
Integrationstests und die ausgewählten Maestro-Black-box-Flows wurden am
2026-08-28 abgeschlossen. Die lokalen Mehrkonten- und echten Redmi-Gerätetests
wurden am 2026-08-29 abgeschlossen. Push-Zustellung und produktive App-Check-
Metriken bleiben ausdrücklich `MANUAL REQUIRED`, weil Firebase Messaging keinen
lokalen Emulator besitzt und produktive Systeme in Block 5 nicht verändert wurden.

## 4. Architekturübersicht

- Start, Firebase, App Check und Push: `lib/main.dart`
- App und Theme: `lib/app/carisma_app.dart`
- Hauptnavigation: Suchen, Profil, Chats, Melden, Einstellungen
- Feature-orientierte Ordner unter `lib/features`
- Services und Repositories direkt in den jeweiligen Features
- Firebase Auth, Firestore, Storage, Functions, Messaging und App Check
- Lokale Einstellungen über Shared Preferences beziehungsweise App-Runtime-Preferences
- Zustandsverwaltung überwiegend mit `StatefulWidget`, `setState`, `StreamBuilder` und `FutureBuilder`
- Kein zentrales Provider-/Riverpod-/Bloc-/DI-System
- Mehrere sehr große Dateien mit 3.000 bis über 7.000 Zeilen
- Historische interne Namen wie `CaRisma`, `Carma` und `carma` sind weiterhin vorhanden

## 5. Funktionslandkarte

1. App-Start, Firebase-Initialisierung, App Check und Push
2. Onboarding und Einwilligungen
3. Registrierung, E-Mail-Verifizierung und Login
4. Google- und Apple-Anmeldung sowie Kontoverknüpfung
5. Passwort-Reset, E-Mail-Änderung, MFA, Recovery und Sitzungswiderruf
6. Nutzerprofil, Sichtbarkeit, Profilbilder, Follower und Profilaufrufe
7. Fahrzeuganlage, Hauptfahrzeug, Deaktivierung, Galerie, Umbauten und Timeline
8. DACH-Kennzeichen, Normalisierung, Suche und Kontaktgründe
9. Kontaktanfragen, Annahme, Ablehnung und Blockierung
10. Chat, Nachrichten, Anhänge, Reaktionen und Lesestatus
11. Storys, Feed, Beiträge, Likes, Kommentare und Antworten
12. Fahrzeughinweise, Nutzer-/Inhaltsmeldungen und Moderation
13. Profil-, Fahrzeug- und Dokumentenverifizierung
14. Einstellungen, Berechtigungen, Datenschutz und Benachrichtigungen
15. Datenexport, Kontolöschung und Anonymisierung
16. Website, Auth-Aktionsseiten, Supportformulare und E-Mail-Automation
17. Administrative MFA- und Verifizierungsabläufe
18. KI-gestützte Fahrzeug-Hero-Bilder

## 6. Bekannte Hauptrisiken

### P0-Kandidaten

- Nicht nachgewiesene produktive Push- und App-Check-Gerätepfade
- Unerlaubter Zugriff oder Manipulation bei Profilen, Fahrzeugen, Chats, Dokumenten oder Admin-Feldern
- Nicht nachgewiesene vollständige Kontolöschung beziehungsweise Dokumentenbereinigung
- Release-Blocker in Signing, Store-Konfiguration oder Rules-/Functions-Live-Stand

### P1-Kandidaten

- Beide Zweige im geprüften Onboarding-Code markieren Onboarding als abgeschlossen
- Push und App Check nur statisch beziehungsweise im Monitoring geprüft
- Große, eng gekoppelte Screens und Repositories erhöhen Regressionsrisiko
- Kein Crashlytics für die spätere Produktionsbeobachtung

### Weitere Risiken

- Keine CI; die aktuelle Flutter-Line-Coverage liegt trotz gezielter Ergänzungen
  erst bei 19,9 Prozent und muss risikobasiert weiter ausgebaut werden
- Android R8/Minify und Resource Shrinking nicht ausdrücklich aktiviert
- iOS-Push-Entitlement muss im finalen Xcode-Projekt geprüft werden
- Rechtliche Texte und Aufbewahrungsangaben benötigen externe Bestätigung
- Test-, Staging- und Produktionsumgebung sind noch nicht vollständig getrennt dokumentiert

## 7. Mehrstufige Teststrategie

### Statische Qualität

- Formatprüfung ohne automatische Änderung, `flutter analyze` und Syntaxprüfungen
- TODO/FIXME, Dead Code, Null-Safety, veraltete APIs, Secrets und Dependencies

### Unit- und Widget-Tests

- Kennzeichen, Validierungen, Datenkonvertierung, Zustände und Fehler-Mapping
- Lade-, Leer- und Fehlerzustände, Formulare, Dialoge und Navigation
- Mehrfachklicks, kleine Displays, Textskalierung, Tastatur, Fokus und Semantics

### Integration und E2E

- `integration_test` als Flutter-Grundlage
- Firebase Emulator Suite für Auth, Firestore, Storage und Functions
- Maestro optional für wenige Black-box-Smoke-Reisen
- Echte Android- und später iOS-Geräte für Push, App Check und native Berechtigungen

### Backend und Security

- Eigentümer, Teilnehmer, Fremde, blockierte Nutzer und Admins
- Typen, Textlängen, Statuswechsel, Uploadpfade und Löschung
- IDOR, Mass Assignment, Enumeration, Rate Limits, Race Conditions und Kostenrisiken
- Auth-, MFA-, Sitzungs-, Deep-Link-, Logging- und Datenschutzprüfung

### Performance und Stabilität

- Startzeit, Jank, Rebuilds, Speicher, Listener, Streams und Controller
- Firestore Reads, Pagination, Debouncing, große Medien und App-Lifecycle

## 8. Empfohlene Werkzeuge

- Vorhanden: `flutter_test`, `test`, Firebase Rules Unit Testing und Firebase Emulator Suite
- Eingerichtet: Flutter `integration_test`
- Bei konkretem Bedarf zu prüfen: `mocktail` und `fake_async`
- Eingerichtet: Maestro 2.5.1 für ausgewählte Black-box-Smoke-Tests
- Manuell: Flutter DevTools und Android Profiler
- CI: GitHub Actions oder eine vergleichbare vorhandene Plattform
- Optional kostenpflichtig: Firebase Test Lab für Gerätefragmentierung
- Zunächst nicht vorgesehen: Appium, weil es für den aktuellen Umfang unnötig schwergewichtig wäre

## 9. Sichere Testdatenstrategie

Reproduzierbare Seeds erzeugen Nutzer A/B, unverifizierte, verifizierte, blockierte und deaktivierte Nutzer, unvollständige Profile, Fahrzeuge, offene Anfragen, aktive Chats und erforderliche Adminrollen. Jeder Test räumt nur eigene Emulator-Daten auf. Produktive Daten, echte Kennzeichen und private Dokumente bleiben ausgeschlossen.

## 10. Priorisierte Workstreams

| ID | Scope | Priorität | Akzeptanzkern | Komplexität |
|---|---|---:|---|---|
| WS00 | Baseline und QA-Protokoll | P0 | Alle Befehle und Status commitbezogen dokumentiert | Mittel |
| WS01 | Toolchain, Analyse und Builds | P0 | Keine ungeklärten Analyse-/Buildfehler | Mittel |
| WS02 | Emulatoren, Testkonten und Seeds | P0 | Keine Produktions- oder Zufallsdaten nötig | Hoch |
| WS03 | Firestore- und Storage-Sicherheit | P0 | Kein bekannter unerlaubter Zugriff | Kritisch |
| WS04 | Kontaktanfragen und Permission-Fehler | P0 | Zwei-Konten-Ablauf ohne Rules-Fehler/Duplikate | Kritisch |
| WS05 | Auth, MFA und Onboarding | P0 | Alle vorgesehenen Auth-Wege und Fehlerzustände geprüft | Hoch |
| WS06 | Profile, Fahrzeuge und Kennzeichen | P1 | Eigentum, Sichtbarkeit und Lifecycle korrekt | Hoch |
| WS07 | Suche, Hinweise und Missbrauchsschutz | P1 | Keine Enumeration oder ungebremste Suche | Hoch |
| WS08 | Chat, Nachrichten und Anhänge | P1 | Teilnehmerrechte und Medienabläufe korrekt | Kritisch |
| WS09 | Push und App Check | P1 | Navigation und legitime Tokens nachgewiesen | Hoch |
| WS10 | Community, Storys und Moderation | P1 | Sichtbarkeit, Interaktionen und Reports abgesichert | Hoch |
| WS11 | Verifizierung und Dokumente | P0 | Upload, Review, Zugriff und Cleanup korrekt | Kritisch |
| WS12 | Datenschutz, Export und Kontolöschung | P0 | Jede Datenkategorie besitzt ein geprüftes Ergebnis | Kritisch |
| WS13 | Offline, Lifecycle und Fehlerbehandlung | P1 | Keine Datenverluste, Duplikate oder unhandled errors | Hoch |
| WS14 | Security, Kosten und Abuse | P0 | Keine offenen P0/P1-Security-Befunde | Kritisch |
| WS15 | Performance, UX und Accessibility | P2 | Keine kritischen Bedien-/Stabilitätsprobleme | Mittel/Hoch |
| WS16 | Android Release-Readiness | P0 | Signiertes AAB besteht reale Release-Smoke-Tests | Hoch |
| WS17 | iOS Readiness | P1 | Mac-Build, Signing und echte iPhone-Tests | Hoch/Extern |
| WS18 | Vollregression und Release Candidate | P0 | Alle Gates erfüllt und Restrisiken dokumentiert | Kritisch |

## 11. Vorgehen pro Workstream

1. Scope und Git-Basis bestätigen
2. aktuelles Verhalten und Anforderungen analysieren
3. Risiken und Testfälle definieren
4. Tests implementieren und tatsächlich ausführen
5. Ergebnisse mit `PASS`, `FAIL`, `BLOCKED` oder `NOT RUN` dokumentieren
6. Fehler reproduzieren, priorisieren und Root Cause bestimmen
7. minimale Korrektur nach Freigabe implementieren
8. betroffene Tests und Regression erneut ausführen
9. manuelle Prüfungen und Restrisiken dokumentieren
10. Handover aktualisieren und erst dann den nächsten Workstream vorschlagen

## 12. Geplante E2E-Nutzerreisen

1. Neuinstallation, Registrierung, Verifizierung und Profilanlage
2. E-Mail-, Google- und Apple-Anmeldung sowie Kontoverknüpfung
3. Nutzer A legt Fahrzeug/Kennzeichen an; Nutzer B sucht danach
4. Kontaktanfrage senden, annehmen und Chat automatisch öffnen
5. Anfrage ablehnen, blockieren und erneuten Zugriff prüfen
6. Nachricht, Bild, Video, Audio, Dokument, Reaktion und Lesestatus
7. Fahrzeughinweis ohne bestehenden Chat senden
8. Story/Beitrag erstellen, liken, kommentieren, antworten und melden
9. Verifizierungsdokument hochladen, prüfen und bereinigen
10. Push im Vordergrund, Hintergrund und nach App-Beendigung
11. Offline/Online, Schreibabbruch, Neustart und Session-Wiederherstellung
12. Datenexport, Kontolöschung und anschließende Datenprüfung
13. Missbrauch: fremde IDs, doppelte Aktionen, lange Texte und falsche Uploadtypen

## 13. Release-Gates

1. **Baseline:** reproduzierbarer Build, Analyze und bestehende Tests
2. **Kernfunktionen:** Registrierung, Login, Profil, Fahrzeug, Suche, Anfrage und Chat bestehen E2E
3. **Firebase-Sicherheit:** keine bekannten unerlaubten Firestore-/Storage-Zugriffe
4. **Stabilität:** keine offenen P0 und keine nicht freigegebenen P1
5. **Datenschutz:** Kontolöschung, Export und Dokumentenbereinigung nachgewiesen
6. **Android RC:** signiertes AAB, reale Installation und Release-Smoke-Test
7. **iOS Readiness:** Windows-Vorbereitung und später Mac-/Xcode-/TestFlight-Abnahme
8. **Finaler RC:** Vollregression, Restrisiken, Monitoring und Rollback dokumentiert

## 14. Android-Release-Strategie

Paket-ID, Firebase-Client, Version, Signing und Berechtigungen werden erneut geprüft. Danach wird bewusst über R8/Resource Shrinking entschieden, ein AAB aus einem sauberen RC-Commit gebaut, Signatur und Hash werden kontrolliert und der Release-Build auf definierten realen Geräten getestet. Der Upload in eine interne Play-Spur bleibt ein separater, ausdrücklich freizugebender externer Schritt.

## 15. iOS-Strategie

Unter Windows werden Bundle-ID, Mindestversion, Firebase, Info.plist, Apple-Login-, Push- und App-Check-Code sowie Store-/Datenschutzunterlagen gepflegt. Auf macOS/iPhone folgen CocoaPods, Xcode-Build, Signing, Provisioning, Entitlements, APNs, App Attest, Apple-Anmeldung, native Berechtigungen, TestFlight und echte Geräte-Smoke-Tests.

## 16. CI- und Quality-Gate-Plan

Pull Requests sollen Secret-/Dependency-Scan, Formatprüfung, Analyze, Flutter-Tests mit Coverage, Functions-Tests, Emulator-Rules-Tests, Website-Tests und Android-Debug-Build ausführen. RC-Tags ergänzen den signierten Release-Build, Artefakthash und die vollständige Regression.

## 17. Dauerhafte QA-Dokumentation

- `docs/qa/MASTER_TEST_PLAN.md`
- `docs/qa/TEST_MATRIX.md`
- `docs/qa/BUG_REGISTER.md`
- `docs/qa/RELEASE_READINESS.md`
- `docs/qa/MANUAL_TEST_CHECKLIST.md`
- `docs/qa/IOS_RELEASE_CHECKLIST.md`
- `docs/qa/ANDROID_RELEASE_CHECKLIST.md`
- `docs/qa/SECURITY_REVIEW.md`
- `docs/qa/SESSION_HANDOVER.md`

Jeder Testfall erhält ID, Modul, Ziel, Vorbedingungen, Testdaten, Schritte, erwartetes und tatsächliches Ergebnis, Testart, Status, Priorität, Commit und gegebenenfalls Bug-ID.

## 18. Umsetzungsreihenfolge und Aufwand

Reihenfolge: `WS00 → WS01 → WS02 → WS03 → WS04 → WS05 → WS06 → WS07 → WS08 → WS09 → WS10 → WS11 → WS12 → WS13 → WS14 → WS15 → WS16 → WS17 → WS18`.

P0-Befunde unterbrechen die normale Reihenfolge. Vorläufige Gesamtgröße: etwa sechs bis zehn Entwicklerwochen zuzüglich externer Geräte-, Store-, Mac- und Rechtsprüfungen. Nach WS00/WS01 wird die Schätzung anhand tatsächlicher Resultate aktualisiert.

## 19. Definition Release-Candidate

plaqa gilt nur dann als Release-Candidate, wenn ein benannter Commit vollständig geprüft wurde, alle vorgesehenen Tests tatsächlich gelaufen sind, keine offenen P0 oder nicht freigegebenen P1 bestehen, Kernreisen mit mindestens zwei Konten bestanden wurden, Firestore/Storage keine bekannten unerlaubten Zugriffe erlauben, Kontaktanfragen, Kontolöschung und Dokumenten-Cleanup nachgewiesen sind, Android real getestet wurde und iOS vollständig abgenommen oder als separater Release abgegrenzt ist. App Check, Push, Datenschutz, Store-Angaben, Monitoring, Rollback und alle Restrisiken müssen dokumentiert sein.

## 20. Aktueller Ausführungsstand

Am 2026-08-28 wurden Block 1 bis Block 4 und am 2026-08-29 der lokal
ausführbare Umfang von Block 5 sowie Gate 6 abgeschlossen:

- 40 vorhandene Flutter-Testdateien inventarisiert
- Ausgangslauf: 207 von 207 Tests bestanden
- 24 gezielte Unit-/Widget-Regressionstests ergänzt
- bestätigten Widerspruch zur deaktivierten Monatsbegrenzung in der
  Kennzeichensuche minimal korrigiert
- Abschlusslauf und Coverage-Lauf: jeweils 231 von 231 Tests bestanden
- `flutter analyze --no-pub`: ohne Befund
- Line-Coverage: 7.238 von 36.333 instrumentierten Zeilen (19,9 Prozent)
- Functions-Syntax: 23 von 23 eigenen JavaScriptdateien unter Node 22 bestanden
- Functions-Tests: 100 von 100 Tests aus zehn Dateien bestanden
- Functions-Einstiegspunkt: 30 Exporte erfolgreich geladen
- Firestore-/Storage-Rules: 104 von 104 Tests aus elf Dateien bestanden
- Rules-Emulatoren wurden dateiweise neu gestartet und anschließend beendet
- offene Beobachtung `OBS-001`: Die Emulatorausgabe erreicht in einzelnen
  Chat-/Kontakt-Negativpfaden die Firestore-Grenze von 1.000 Regelausdrücken;
  ein Fehler in einem legitimen Nutzerpfad ist noch nicht reproduziert
- vier von vier Flutter-Integrationstests auf dem dedizierten Android-AVD
  `plaqa_pixel_6_api_35` gegen lokale Auth-, Firestore- und Storage-Emulatoren
  bestanden
- App-Start, Emulatorverbindung, vollständige Registrierungsbasisdaten und der
  UI-Ablauf aus Registrierung, Navigation, Fehlanmeldung und Wiederanmeldung
  bestanden
- ein intermittierendes Rennen bei der doppelten Firestore-Bereitstellung in
  Auth-Oberfläche und Auth-Gate als `BUG-002` behoben; das Auth-Gate ist jetzt
  alleiniger Besitzer der Bereitstellung
- vollständige Flutter-Regression nach der Korrektur: 234 von 234 Tests
  bestanden; `flutter analyze --no-pub` ohne Befund
- drei dauerhafte Maestro-Flows auf dem dedizierten Android-AVD gegen die
  vollständige lokale Firebase Emulator Suite bestanden: App-Kaltstart,
  verständlicher Fehlanmeldungszustand sowie Registrierung mit Einwilligungen,
  Kennzeicheneingabe und Navigation durch Profil, Chats, Melden und Einstellungen
- abschließender gemeinsamer Maestro-Lauf: 3 von 3 Flows in 4 Minuten 12 Sekunden
- Profile-APK ausschließlich für lokale Emulatorprüfungen mit
  `PLAQA_USE_FIREBASE_EMULATORS=true` und Host `10.0.2.2`; die
  Release-Netzwerksicherheit wurde nicht gelockert
- erneute Abschlussregression nach Block 4: 234 von 234 Flutter-Tests bestanden,
  `flutter analyze --no-pub` ohne Befund
- Firebase-Suite und Test-AVD kontrolliert beendet; Ports 9099, 8080, 9199,
  5001, 4400 und 9150 frei; das angeschlossene Redmi blieb bis Block 4 unberührt
- lokale Profile-APK mit Host `127.0.0.1` auf dem Redmi `2201117TY` installiert;
  Produktionsdaten, Live-Functions, App-Check-Erzwingung und Deployments blieben
  unverändert
- zwei künstliche Emulator-Konten suchten ein Fahrzeug, sendeten und nahmen eine
  Kontaktanfrage an, tauschten zwei Nachrichten aus und prüften die Blockierung
  aus beiden Kontoperspektiven erfolgreich
- der Backend-Nachweis bestätigte drei Nachrichten, beide Teilnehmer, Status
  `blocked` und den korrekten blockierenden Nutzer
- legitime Kontaktanfragen, fehlende Follow-Dokumente, Blockierung und Story-
  Abfragen wurden in den Rules minimal korrigiert und durch Regressionen geschützt
- Kamera-Berechtigungsdialog, Rückkehr aus der nativen Kamera, App-Berechtigungs-
  status, GPS-Auflösung, Hintergrund/Vordergrund, Kaltstart-Session sowie Offline-
  und Wiederverbindungszustand auf dem Redmi bestanden
- GPS löste den realen Gerätestandort erfolgreich zu `Kaiserbarg 3A, Hamburg` auf
- drei Online-Kaltstarts: 1.600 ms, 1.595 ms und 1.567 ms; stabiler Zustand:
  256.482 KB Total PSS und 369.244 KB Total RSS; keine Flutter-Ausnahme, kein ANR
  und kein erkannter Layoutüberlauf
- Abschlussregression: 234 von 234 Flutter-Tests, `flutter analyze --no-pub`
  ohne Befund sowie 109 von 109 Rules-/Security-Tests bestanden
- lokale Fahrzeugbildgenerierung serverseitig vor externen Vertex-AI-Zugriffen
  geschützt; authentifizierter Emulator-Nachweis bestand in 62 ms

Block 5 ist für den sicher lokal ausführbaren Mehrkonten- und Redmi-Umfang
abgeschlossen. Push im Vorder-/Hintergrund sowie produktive App-Check-Tokens und
-Metriken bleiben `MANUAL REQUIRED` und werden in einem ausdrücklich freigegebenen
Staging-/Produktionsschritt geprüft. Es wurde nichts deployt oder veröffentlicht.

## 21. Gate-6-Abschluss: Android Release Candidate

Gate 6 wurde auf Basis von `main` / `3ea0dc6d212238c5e55ffb808415e831bc582117`
lokal vollständig ausgeführt:

- Paket-ID `de.plaqa.app`, Version `1.0.0+1`, SDK 24/36, Firebase-Projekt
  `carma-a84e4`, OAuth-Zertifikate, Signing und Berechtigungen geprüft
- R8, Resource Shrinking und optimiertes Resource Shrinking aktiviert
- Release-AAB mit 70,70 MiB und SHA-256
  `1382A293107CCD27193CD0D3FFFD01A5B11BE5E5679FCD4CE89827E730B786C6`
- Release-APK mit 82,31 MiB und SHA-256
  `9B2816A541515F53D666A854ED91622B4C8ACBAB6AC29D1C30834CAD0B496DAC`
- AAB durch `bundletool 1.18.3` validiert; APK-Signatur, ein Signierer,
  Release-Zertifikat und 16-KiB-Zip-Alignment bestätigt
- zusammengeführtes Release-Manifest ohne `debuggable` und ohne
  Klartextfreigabe bestätigt
- Release-APK auf dem Redmi `2201117TY` installiert und bytegenau mit dem
  geprüften lokalen Artefakt verglichen
- Kaltstarts 2.439 ms direkt nach Installation, danach 612 ms und 495 ms;
  isolierter Kontrollstart 608 ms
- stabiler Release-Zustand mit 165.052 KB Total PSS, 246.320 KB Total RSS und
  671 KB Swap PSS
- Maestro-Release-Kaltstart, visuelle Login-Prüfung und isolierter Runtime-Log
  ohne Crash, ANR, Null-Check-, RenderFlex- oder unbehandelte Flutter-Ausnahme
- vorherige Debug-APK nach dem Test per SHA-256 bytegenau wiederhergestellt;
  App gestoppt und Redmi gesperrt
- frische Abschlussregression: 234/234 Flutter-Tests, Analyze ohne Befund,
  100/100 Functions-Tests, 109/109 Rules-Tests und 30/30 Website-Tests
- Firebase-Emulatoren beendet und Testports wieder frei

Gate 6 trägt den Status `PASS LOCAL`. Der Upload in die interne Play-Spur,
Play App Signing, Store-Angaben, produktive Push-/App-Check-Prüfungen und jede
Veröffentlichung bleiben externe, gesondert freizugebende Schritte. Der unter
Windows ausführbare Teil von Gate 7 ist inzwischen abgeschlossen; Gate 8 und
die Mac-/iPhone-Abnahme stehen weiterhin aus. Details stehen in
`docs/qa/ANDROID_RELEASE_CHECKLIST.md` und `docs/qa/RELEASE_READINESS.md`.

## 22. Gate-7-Abschluss: iOS Readiness unter Windows

Gate 7 wurde auf Basis von `main` /
`3ad20157b0930e613235e112528d21c35e1860e7` im ausdrücklich vereinbarten
Windows-Umfang abgeschlossen:

- Bundle-ID `de.plaqa.app`, App-Name `plaqa`, Version `1.0.0+1` und iOS 15.0
  über Xcode-Projekt, Podfile und Flutter Framework konsistent
- `GoogleService-Info.plist`, FlutterFire-Konfiguration, Google-URL-Scheme,
  Firebase-App-, Projekt-, Sender-, Client- und Bundle-ID abgeglichen
- fünf native Datenschutzhinweise für Kamera, Standort, Mikrofon und Fotos
  strukturiert validiert
- APNs-Entitlement und Xcode Push-Capability ergänzt
- Background fetch und Remote notifications aktiviert; Firebase Method
  Swizzling bleibt aktiv
- Sign in with Apple in Entitlement, Xcode-Capability und FlutterFire-Code
  nachgewiesen
- App-Attest-Produktionsentitlement ergänzt; Release-Code verwendet App Attest
  mit DeviceCheck-Fallback, Debug-Code den Debug-Provider
- AppDelegate, SceneDelegate und Pluginregistrierung geprüft
- 19 von 19 iPhone-, iPad- und Store-App-Icon-Slots mit exakten Pixelmaßen und
  ohne Alpha-Kanal bestätigt
- keine privaten Apple-Schlüssel, Zertifikate oder Provisioning Profiles im
  iOS-Projekt; kein fremdes Apple-Team fest verdrahtet
- dauerhafter Validator `npm run test:ios:windows` mit inzwischen 126 von 126 Prüfungen
  bestanden
- frische Gate-7-Abschlussregression: 234/234 Flutter-Tests, Analyze ohne
  Befund, 100/100 Functions-Tests, 109/109 Firestore-/Storage-Rules und 30/30
  Website-Tests
- Firebase-Emulatoren kontrolliert beendet; Ports 8080, 9199, 9150 und 4400
  wieder frei

Gate 7 trägt damit `PASS WINDOWS / MANUAL REQUIRED`. Apple Developer Portal,
CocoaPods, Xcode-Build, Signing, Provisioning, endgültige Entitlements, Privacy
Report, IPA, echte iPhone-Tests, APNs-Zustellung, App-Check-Metriken und
TestFlight benötigen macOS beziehungsweise externe Konten. Diese Punkte stehen
verbindlich in `docs/qa/IOS_RELEASE_CHECKLIST.md`. Es wurde nichts deployt,
hochgeladen oder veröffentlicht.

## 23. Gate-8-Abschluss: finale technische Release-Abnahme

Gate 8 wurde auf Basis von `main` /
`a8ebd42a9a039f70ff17a50e85adce43f4fdf077` vollständig im lokal und unter
Windows ausführbaren Umfang abgeschlossen:

- iOS-Firebase-App-Zuordnung korrigiert und automatisch gegen die Plist geprüft
- persistentes Onboarding für neue Profile korrigiert und mit drei Tests
  abgesichert
- zwei hohe transitive npm-Sicherheitsadvisories innerhalb kompatibler
  Paketbereiche behoben
- frische Regression: 237/237 Flutter, Analyze ohne Befund, 100/100 Functions,
  109/109 Rules, 30/30 Website und 126/126 iOS-Windows-Prüfungen
- neues Android-AAB mit SHA-256
  `65D9F708B7E5C05099DC0034AF910DC9AAA3A0B2B2A41568935D54638533174A`
- neue Android-APK mit SHA-256
  `FF226D7DFFAC3B52076831D50599BAE526E1DA47065BA904511390F85A168DAC`
- AAB durch bundletool validiert; APK-Signatur, Signierer,
  16-KiB-Alignment, Paket, Version, SDK und ABIs bestätigt
- Standard-Security-Scan `d316c0fd-3693-447f-badf-1864041b52df`
  abgeschlossen und versiegelt: 5 hohe und 6 mittlere Befunde
- manuelle Releaseabnahme, Monitoring, Rollback und klare GO/NO-GO-Kriterien
  dokumentiert

Gate 8 trägt **COMPLETE / PUBLIC NO-GO**. Dieser Status bedeutet, dass die
Prüfung vollständig ist und ihre Ergebnisse eine Veröffentlichung sperren.
Store-Upload, Deployment, App-Check-Erzwingung, TestFlight und Veröffentlichung
wurden nicht ausgeführt. Die Wiederfreigabe setzt Behebung und Regression aller
hohen Befunde, Behandlung der mittleren Befunde und reale externe Nachweise
voraus. Details stehen in `docs/qa/GATE_8_RELEASE_DECISION.md`.
