# plaqa QA Test Matrix

Stand: 2026-08-29
Branch: `main`

## Blockstatus

| Block | Umfang | Status | Nachweis |
|---|---|---|---|
| 1 | Flutter Unit- und Widget-Tests | PASS | 231/231 Tests, Analyze ohne Befund |
| 2 | Functions- und Rules-Tests im Emulator | PASS | 100/100 Functions-Tests, 104/104 Rules-Tests |
| 3 | Flutter-Integrationstests | PASS | 4/4 Integrationsdateien; 234/234 Flutter-Regressionstests |
| 4 | Maestro UI-Automation | PASS | 3/3 Flows in 4m 12s; 234/234 Flutter-Regressionstests |
| 5 | Mehrkonten- und echte Gerätetests | PASS | Lokaler/Redmi-Umfang bestanden; Push und App Check separat `MANUAL REQUIRED` |
| 6 | Android Release Candidate | PASS LOCAL | AAB/APK signiert und validiert; Release-Smoke auf Redmi bestanden; kein Upload |

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
| FN-SYNTAX-001 | Eigene Functions-Quellen und -Tests | Node-22-Syntax | 23/23 Dateien bestanden | PASS |
| FN-EXPORT-001 | Functions-Einstiegspunkt | Initialisierung | 30 Exporte geladen; rund 30,3 Sekunden | PASS |
| FN-ALL-001 | Alle zehn Functions-Testdateien | Node-Test | 100/100 bestanden | PASS |
| FN-LOCAL-001 | Fahrzeugbildgenerierung | Auth-/Functions-Emulator | Authentifizierter Aufruf in 62 ms lokal gesperrt; kein externer Vertex-Aufruf | PASS |
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

## Block 5

Laufzeitumgebung: Redmi `2201117TY` mit Android 13, Maestro CLI 2.5.1,
lokale Profile-APK, ADB-Reverse und die Firebase Emulator Suite mit
Authentication, Functions, Firestore und Storage. Zwei künstliche Konten und
Kennzeichen wurden ausschließlich lokal erzeugt. Produktive Daten, App-Check-
Erzwingung, Deployments und Veröffentlichungen blieben unverändert.

| ID | Bereich | Testart | Ergebnis | Status |
|---|---|---|---|---|
| DEV-BUILD-001 | Redmi-Testartefakt | Flutter Profile/ADB | APK installiert; SHA-256 `B02923F94400B23B7053A95230800F4259AC0F0B8AA41F12AB7734A22AD1AC4A` | PASS |
| DEV-AUTH-001 | Zwei lokale Konten | Maestro/Auth Emulator | Konto A und B mehrfach nach frischem App-Zustand angemeldet | PASS |
| DEV-CONTACT-001 | Suche und Kontaktanfrage | Maestro/Functions/Firestore | A findet `HH-CR 2026`; Anfrage wird erstellt und B kann sie annehmen | PASS |
| DEV-CHAT-001 | Zwei-Konten-Chat | Maestro/Firestore | Initialnachricht, Nachricht von B und Antwort von A sichtbar und im Backend vorhanden | PASS |
| DEV-BLOCK-001 | Blockierung | Maestro/Firestore | A blockiert; Chat verschwindet bei A und B; Backendstatus `blocked` | PASS |
| DEV-RULES-001 | Block-5-Sicherheitsregression | Firestore/Storage Emulator | 109/109 bestanden; ein abgebrochener Emulator-Cleanup bestand isoliert bei Wiederholung | PASS |
| DEV-PERM-001 | Native Berechtigungsanzeige | Maestro/Android | Kamera, Mikrofon, Standort, Medien und Kontakte korrekt klassifiziert | PASS |
| DEV-CAMERA-001 | Kamera | Maestro/Android | nativer Dialog, Kamerastart und sichere Rückkehr zur Meldeseite bestanden | PASS |
| DEV-GPS-001 | Standort | Maestro/Android | GPS erfasst und zu `Kaiserbarg 3A, Hamburg` aufgelöst | PASS |
| DEV-LIFE-001 | Lifecycle und Session | Maestro/ADB | Hintergrund/Vordergrund sowie Force-Stop/Kaltstart behalten gültige Session und UI-Zustand | PASS |
| DEV-OFFLINE-001 | Offline/Wiederverbinden | Maestro/ADB | verständlicher Offline-Zustand; Retry nach ADB-Reverse-Wiederherstellung erfolgreich | PASS |
| DEV-PERF-001 | Start und Speicher | ADB/Profile | Kaltstart 1.600/1.595/1.567 ms; 256.482 KB PSS, 369.244 KB RSS; keine Flutter-Ausnahme oder ANR | PASS |
| DEV-REGRESSION-001 | Flutter-Abschlussregression | Unit/Widget/Statisch | 234/234 und Analyze ohne Befund | PASS |
| DEV-EXTERNAL-001 | Externe KI im lokalen Testbetrieb | Auth-/Functions-Emulator | Fahrzeugbildgenerierung vor Datenzugriff und Vertex-Aufruf gesperrt | PASS |
| DEV-PUSH-001 | Push foreground/background/terminated | Echtes Backend erforderlich | Kein lokaler Firebase-Messaging-Emulator; produktive Zustellung nicht angefasst | MANUAL REQUIRED |
| DEV-APPCHECK-001 | App-Check-Token und Metriken | Echtes Backend erforderlich | Release-Konfiguration statisch geprüft; produktive Token/Metriken und Erzwingung nicht verändert | MANUAL REQUIRED |

Android `gfxinfo` erfasst Flutter-Surface-Rendering auf diesem Gerät nicht
repräsentativ; die Jank-Endprüfung bleibt deshalb zusätzlich Bestandteil des
späteren Profiler-/Release-Candidate-Blocks. Das ändert den bestandenen Block-5-
Geräte-Smoke-Test nicht.

## Gate 6

Laufzeitumgebung: Flutter 3.41.7, Dart 3.11.5, Android Gradle/R8,
`bundletool 1.18.3`, Android Build Tools und echtes Redmi `2201117TY` mit
Android 13. Der Release-Build verwendete das lokale Upload-Zertifikat; Keystore
und Passwörter blieben außerhalb von Git. Es wurde nichts deployt, in die Play
Console hochgeladen oder veröffentlicht.

| ID | Bereich | Testart | Ergebnis | Status |
|---|---|---|---|---|
| RC-ID-001 | Paket/Firebase/Version | Statisch | `de.plaqa.app`, `carma-a84e4`, `1.0.0+1`, Firebase-Zertifikatzuordnung geprüft | PASS |
| RC-HARDEN-001 | R8 und Ressourcen | Build/Statisch | Minifizierung, Resource Shrinking und optimiertes Shrinking aktiv | PASS |
| RC-AAB-001 | Release App Bundle | Flutter/Gradle | 70,70 MiB; SHA-256 `1382A293107CCD27193CD0D3FFFD01A5B11BE5E5679FCD4CE89827E730B786C6` | PASS |
| RC-APK-001 | Release APK | Flutter/Gradle | 82,31 MiB; SHA-256 `9B2816A541515F53D666A854ED91622B4C8ACBAB6AC29D1C30834CAD0B496DAC` | PASS |
| RC-BUNDLE-001 | AAB-Struktur | bundletool | Bundle validiert | PASS |
| RC-SIGN-001 | APK/AAB-Signierung | apksigner/keytool | genau ein Signierer; erwartete Release-SHA-1 und SHA-256 | PASS |
| RC-ALIGN-001 | APK-Alignment | zipalign | 16-KiB-Prüfung erfolgreich | PASS |
| RC-MANIFEST-001 | Release-Manifest | AAPT/Manifest | Version, SDK 24/36 und Berechtigungen geprüft; weder debuggable noch Cleartext | PASS |
| RC-DEVICE-001 | Release-Installation | ADB/Redmi | signierte APK installiert; installierte Datei stimmt bytegenau mit dem lokalen APK überein | PASS |
| RC-START-001 | Release-Kaltstart | ADB | 2.439 ms nach Installation, danach 612/495 ms; isoliert 608 ms | PASS |
| RC-MEM-001 | Release-Speicher | ADB | 165.052 KB PSS, 246.320 KB RSS, 671 KB Swap PSS | PASS |
| RC-UI-001 | Release-Anmeldung | Maestro/visuell | Login und Registrierung sichtbar; kein Null-Check, RenderFlex oder ANR | PASS |
| RC-LOG-001 | Release-Runtime | Logcat | kein App-Crash, ANR oder unbehandelter Flutter-/Layoutfehler | PASS |
| RC-RESTORE-001 | Redmi-Rückbau | ADB/SHA-256 | ursprüngliche Debug-APK bytegenau wiederhergestellt; Gerät gesperrt | PASS |
| RC-FN-001 | Functions-Abschlussregression | Node 22 | 100/100 aus zehn Dateien | PASS |
| RC-RULES-001 | Rules-Abschlussregression | lokale Emulatoren | 109/109 aus elf Dateien; Emulatorports anschließend frei | PASS |
| RC-WEB-001 | Website-Abschlussregression | Node/Browservertrag | 30/30 bestanden | PASS |
| RC-ANALYZE-001 | Flutter Analyze | Statisch | keine Befunde; 49,9 Sekunden | PASS |
| RC-FLUTTER-001 | Flutter-Gesamtregression | Unit/Widget | 234/234; Exit-Code 0 | PASS |
| RC-PLAY-001 | Interne Play-Testspur | Externer Store-Schritt | nicht hochgeladen; gesonderte Freigabe erforderlich | MANUAL REQUIRED |

## Abgrenzung

Block 1 prüft isolierte Dart-Logik und Flutter-Widgets. Block 2 prüft Functions
und Firebase-Regeln reproduzierbar mit künstlichen lokalen Emulator-Daten. Block
3 prüft die vorhandenen Flutter-Integrationsabläufe mit einem künstlichen Konto.
Block 4 bedient ausgewählte Kernreisen als Black-box über die gerenderte
Android-Oberfläche. Block 5 ergänzt lokale Mehrkontenpfade und ein echtes Redmi.
Gate 6 prüft das gehärtete, signierte Android-Release-Artefakt. Keiner dieser
lokalen Gates ist ein Nachweis für produktive Push-, App-Check-, Store- oder
Live-Backend-Abläufe.
