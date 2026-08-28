# plaqa Master-Test-, QA- und Release-Plan

Stand: 2026-08-28
Planbasis: `main` / `e6946630d47e474f731c1b7a50c46470d9c5cfd1`
Status: Umsetzung begonnen; Block 1 bis Block 3 abgeschlossen

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
Integrationstests wurden am 2026-08-28 abgeschlossen; alle späteren Test- und
Buildblöcke behalten bis zu ihrer tatsächlichen Ausführung den Status `NOT RUN`.

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

- Dokumentierter Firestore-Fehler `permission-denied` beim Annehmen einer Kontaktanfrage
- Unerlaubter Zugriff oder Manipulation bei Profilen, Fahrzeugen, Chats, Dokumenten oder Admin-Feldern
- Nicht nachgewiesene vollständige Kontolöschung beziehungsweise Dokumentenbereinigung
- Release-Blocker in Signing, Store-Konfiguration oder Rules-/Functions-Live-Stand

### P1-Kandidaten

- Beide Zweige im geprüften Onboarding-Code markieren Onboarding als abgeschlossen
- Keine echte Zwei-Konten-End-to-End-Abdeckung
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
- Optional: Maestro für Black-box-Smoke-Tests
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

Paket-ID, Firebase-Client, Version, Signing und Berechtigungen werden erneut geprüft. Danach wird bewusst über R8/Resource Shrinking entschieden, ein AAB aus einem sauberen RC-Commit gebaut, Signatur und Hash werden kontrolliert und der Release-Build wird über die interne Spur auf definierten realen Geräten getestet.

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

Am 2026-08-28 wurden Block 1 bis Block 3 der Testausführung abgeschlossen:

- 40 vorhandene Flutter-Testdateien inventarisiert
- Ausgangslauf: 207 von 207 Tests bestanden
- 24 gezielte Unit-/Widget-Regressionstests ergänzt
- bestätigten Widerspruch zur deaktivierten Monatsbegrenzung in der
  Kennzeichensuche minimal korrigiert
- Abschlusslauf und Coverage-Lauf: jeweils 231 von 231 Tests bestanden
- `flutter analyze --no-pub`: ohne Befund
- Line-Coverage: 7.238 von 36.333 instrumentierten Zeilen (19,9 Prozent)
- Functions-Syntax: 21 von 21 eigenen JavaScriptdateien unter Node 22 bestanden
- Functions-Tests: 98 von 98 Tests aus neun Dateien bestanden
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

Maestro-, Mehrkonten-, echte Geräte- und Livetests wurden noch nicht gestartet.
Der nächste Block beginnt erst nach gemeinsamer Besprechung und ausdrücklicher
Fortsetzung durch den Nutzer. Es wurde nichts deployt, hochgeladen oder
veröffentlicht.
