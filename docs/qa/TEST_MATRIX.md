# plaqa QA Test Matrix

Stand: 2026-08-28
Branch: `main`

## Blockstatus

| Block | Umfang | Status | Nachweis |
|---|---|---|---|
| 1 | Flutter Unit- und Widget-Tests | PASS | 231/231 Tests, Analyze ohne Befund |
| 2 | Functions- und Rules-Tests im Emulator | PASS | 98/98 Functions-Tests, 104/104 Rules-Tests |
| 3 | Flutter-Integrationstests | PASS | 4/4 Integrationsdateien; 234/234 Flutter-Regressionstests |
| 4 | Maestro UI-Automation | PASS | 3/3 Flows in 4m 12s; 234/234 Flutter-Regressionstests |
| 5 | Mehrkonten- und echte Gerätetests | NOT RUN | Noch nicht gestartet |

## Block 1

| ID | Bereich | Testart | Ergebnis | Status |
|---|---|---|---|---|
| FL-BASE-001 | Vorhandene Flutter-Suite | Unit/Widget | 207/207 bestanden | PASS |
| FL-GATE-001 | Feature-Gates und Kontozustände | Unit | 7/7 bestanden | PASS |
| FL-PATH-001 | Firestore-Pfadkonstruktion | Unit | 5/5 bestanden | PASS |
| FL-MODEL-001 | Domainmodelle und Verifizierung | Unit | 11/11 bestanden | PASS |
| FL-QUOTA-001 | Deaktivierte Monatsbegrenzung | Unit/Regression | 1/1 neu ergänzt, Gesamttest bestanden | PASS |
| FL-ALL-001 | Vollständiger Abschlusslauf | Unit/Widget | 231/231 bestanden | PASS |
| FL-COV-001 | Vollständiger Coverage-Lauf | Unit/Widget | 231/231; 7.238/36.333 Zeilen | PASS |
| FL-ANALYZE-001 | Flutter Analyze | Statisch | Keine Befunde | PASS |
| FL-DIFF-001 | Git-Diff-Prüfung | Statisch | Keine Whitespace-Fehler | PASS |

## Block 2

Laufzeitumgebung: Android-Studio-JDK 21, Functions-Runtime Node 22 und
Firebase CLI 15.15.0. Firestore und Storage liefen ausschließlich lokal auf
`127.0.0.1`; die Emulatoren wurden zwischen den Rules-Dateien neu gestartet.

| ID | Bereich | Testart | Ergebnis | Status |
|---|---|---|---|---|
| FN-SYNTAX-001 | Eigene Functions-Quellen und -Tests | Node-22-Syntax | 21/21 Dateien bestanden | PASS |
| FN-EXPORT-001 | Functions-Einstiegspunkt | Initialisierung | 30 Exporte geladen; rund 30,3 Sekunden | PASS |
| FN-ALL-001 | Alle neun Functions-Testdateien | Node-Test | 98/98 bestanden | PASS |
| RULE-ACCOUNT-001 | Kontosicherheit | Firestore/Storage Emulator | 6/6 bestanden | PASS |
| RULE-CHAT-001 | Chats und Teilnehmerrechte | Firestore/Storage Emulator | 13/13 bestanden | PASS |
| RULE-CONTACT-001 | Kontaktanfragen und Fahrzeuge | Firestore/Storage Emulator | 8/8 bestanden | PASS |
| RULE-PERSONAL-001 | Private Profildaten | Firestore/Storage Emulator | 11/11 bestanden | PASS |
| RULE-VEHICLE-001 | Profilfahrzeuge | Firestore/Storage Emulator | 8/8 bestanden | PASS |
| RULE-VERIFY-001 | Profilverifizierung und Dokumente | Firestore/Storage Emulator | 16/16 bestanden | PASS |
| RULE-CLEANUP-001 | Report-Bereinigung | Emulator/Node-Test | 7/7 bestanden | PASS |
| RULE-RATE-001 | Melde-Limits und Bildbereinigung | Emulator/Node-Test | 12/12 bestanden | PASS |
| RULE-REPORT-001 | Meldungen und Beweisbilder | Firestore/Storage Emulator | 14/14 bestanden | PASS |
| RULE-SETTINGS-001 | Einstellungen und Serviceanfragen | Firestore Emulator | 6/6 bestanden | PASS |
| RULE-SOCIAL-001 | Beiträge, Likes, Kommentare und Medien | Firestore/Storage Emulator | 3/3 bestanden | PASS |
| RULE-ALL-001 | Alle elf Rules-Testdateien | Sequenzieller Abschlusslauf | 104/104 bestanden | PASS |
| EMU-CLOSE-001 | Emulator-Prozesse und Ports | Abschlusskontrolle | Ports 8080, 9199 und 9150 frei | PASS |

Erwartete `PERMISSION_DENIED`-Meldungen stammen aus Negativtests. Ein separater
Komplexitätshinweis zur Firestore-Auswertungsgrenze ist als `OBS-001` im
Bug-Register dokumentiert und wurde nicht durch eine Rules-Lockerung kaschiert.

## Block 3

Laufzeitumgebung: dedizierter Android-AVD `plaqa_pixel_6_api_35` und lokale
Firebase Emulator Suite mit Authentication auf Port 9099, Firestore auf Port
8080 und Storage auf Port 9199. Das angeschlossene Redmi wurde nicht verwendet.

| ID | Bereich | Testart | Ergebnis | Status |
|---|---|---|---|---|
| INT-START-001 | App-Start | Flutter Integration | 1/1 bestanden; keine unbehandelte Flutter-Ausnahme | PASS |
| INT-CONNECT-001 | Auth-/Firestore-Brücke | Flutter Integration/Firebase Emulator | 1/1 bestanden; künstliches lokales Konto und Firestore-Lesezugriff | PASS |
| INT-PROVISION-001 | Registrierungsbasisdaten | Flutter Integration/Firebase Emulator | 1/1 bestanden; privates und öffentliches Profil, Suchstatus und 4 Zustimmungen vorhanden | PASS |
| INT-AUTH-001 | Registrierung und Login | Flutter Integration/UI | 1/1 bestanden; Registrierung, Navigation, Fehlanmeldung und Wiederanmeldung | PASS |
| FL-REGRESSION-002 | Vollständige Flutter-Regression | Unit/Widget | 234/234 bestanden | PASS |
| FL-ANALYZE-002 | Flutter Analyze | Statisch | Keine Befunde | PASS |
| FL-DIFF-002 | Git-Diff-Prüfung | Statisch | Keine Whitespace-Fehler; nur erwartete LF-/CRLF-Hinweise | PASS |
| INT-CLOSE-001 | Lokale Testumgebung | Abschlusskontrolle | Firebase-Suite und Test-AVD beendet; Ports 9099, 8080, 9199 und 4400 frei; Redmi unberührt | PASS |

Der UI-Ablauf deckt ein einzelnes künstliches Konto ab. Mehrkonten-, Push-,
App-Check-Metrik-, native Geräte- und produktive Backendprüfungen gehören nicht
zu Block 3 und bleiben in den späteren Blöcken offen.

## Block 4

Laufzeitumgebung: Maestro CLI 2.5.1, dedizierter Android-AVD
`plaqa_pixel_6_api_35`, Profile-APK und vollständige lokale Firebase Emulator
Suite mit Authentication, Functions, Firestore und Storage. Die App erhielt die
lokalen Defines `PLAQA_USE_FIREBASE_EMULATORS=true` und
`PLAQA_FIREBASE_EMULATOR_HOST=10.0.2.2`. Klartextzugriff ist nur im Android-
Profile-Manifest erlaubt; die Release-Konfiguration blieb unverändert. Das
angeschlossene Redmi wurde nicht verwendet.

| ID | Bereich | Testart | Ergebnis | Status |
|---|---|---|---|---|
| MST-START-001 | Frischer App-Start | Maestro Black-box | Anmeldung innerhalb von 60 Sekunden sichtbar; keine Null-, Layout- oder ANR-Meldung | PASS |
| MST-AUTH-001 | Fehlanmeldung | Maestro Black-box/Firebase Auth Emulator | Eingabe bestätigt; sichere Meldung `E-Mail oder Passwort ist falsch.`; keine Navigation | PASS |
| MST-REGISTER-001 | Registrierung und Kernnavigation | Maestro Black-box/Firebase Emulator Suite | Ein Konto, 3 Einwilligungen, Profilanlage, Kennzeichen `HH CR 2026`, Profil, Chats, Melden und Einstellungen bestanden | PASS |
| MST-SUITE-001 | Abschlusslauf aller Flows | Maestro Black-box | 3/3 Flows in 4m 12s bestanden | PASS |
| FL-REGRESSION-003 | Vollständige Flutter-Regression | Unit/Widget | 234/234 bestanden | PASS |
| FL-ANALYZE-003 | Flutter Analyze | Statisch | Keine Befunde | PASS |
| MST-CLOSE-001 | Lokale Testumgebung | Abschlusskontrolle | Firebase-Suite und AVD beendet; Ports 9099, 8080, 9199, 5001, 4400 und 9150 frei; Redmi unberührt | PASS |

Der optionale Android-Dialog `No thanks` war im Abschlusslauf nicht vorhanden
und wurde deshalb erwartungsgemäß als optionale Warnung protokolliert. Das ist
kein Produktfehler. Mehrkonten-, Push-, App-Check-, Kamera-, GPS-, Performance-
und echte Gerätetests bleiben Bestandteil von Block 5.

## Abgrenzung

Block 1 prüft isolierte Dart-Logik und Flutter-Widgets. Block 2 prüft Functions
und Firebase-Regeln reproduzierbar mit künstlichen lokalen Emulator-Daten. Block
3 prüft die vorhandenen Flutter-Integrationsabläufe mit einem künstlichen Konto.
Block 4 bedient ausgewählte Kernreisen als Black-box über die gerenderte
Android-Oberfläche. Keiner dieser Blöcke ist ein Nachweis für echte Mehrkonten-,
Geräte- oder produktive Backend-Abläufe. Diese Nachweise folgen ausschließlich
in den späteren, getrennten Blöcken.
