# plaqa Release Checklist

Stand: 2026-08-18 20:39 CEST

## Statuslegende

- `[x]` erledigt und in dieser Bestandsaufnahme nachgewiesen
- `[ ]` offen
- `[BLAZE]` durch Billing/Blaze blockiert
- `[WEB]` wartet auf die öffentliche Website
- `[SUPPORT]` wartet auf Firebase-Support
- `[LIVE]` nur mit Gerät, Testkonto oder realem Backend prüfbar

## Lokaler Code-Abschluss

- [x] Firebase-Zielprojekt lokal einheitlich `carma-a84e4`.
- [x] Android-Anzeigename ist `plaqa`; technischer Paketname bleibt `com.carma.app`.
- [x] Hosting-Konfiguration und Auth-Action-Handler sind lokal vorhanden.
- [x] Sichtbaren alten Medien-Dateinamen korrigiert; neue Dateien verwenden `plaqa_<timestamp>.png`.
- [x] Interne `CaRisma*`-Klassen und technische Firebase-/Paket-IDs bewusst als interne Bezeichner beibehalten.
- [ ] 76 markierte Legal-Platzhalter (`ANGABE ERGÄNZEN` / `RECHTLICH PRÜFEN`) vor Veröffentlichung fachlich und rechtlich abschließen.
- [x] Öffentliche/private Datenmodelle, Fehlertexte, Ladezustände und Debug-Gates statisch geprüft; gefundene rohe technische UI-Fehler und sichtbare UID entfernt.
- [x] `HH-CR 2026` und Profil-Demo-Inhalte sind statisch auf Debug-/Demo-Pfade begrenzt.
- [ ] `firestore-debug.log` bleibt ignoriert; keine Logs stagen.
- [x] `android/key.properties` und `android/upload-keystore.jks` sind lokal vorhanden und von Git ausgeschlossen.
- [ ] Release-Keystore und Passwörter außerhalb des Repositories zusätzlich sicher sichern.

## Flutter-Tests und Analyse

- [x] Alle 31 Flutter-Testdateien ausgeführt: 169 Tests bestanden.
- [x] Keine fehlgeschlagenen Flutter-Tests im statischen Abschlusslauf.
- [x] Nur tatsächlich geänderte Dart-Dateien formatiert.
- [x] `flutter analyze --no-pub`: keine Probleme gefunden.
- [x] `git diff --check` im finalen Abschlusslauf bestanden; nur erwartete Zeilenende-Warnungen vorhanden.

## Functions-Tests

- [x] 23 lokale Function-Exports inventarisiert.
- [x] 12 veröffentlichte Function-Namen, Region und Runtime read-only bestätigt.
- [x] `node --check functions/index.js` bestanden.
- [x] Syntaxchecks aller 9 produktiven Functions-JavaScript-Dateien bestanden.
- [x] Alle 6 Functions-Testdateien ausgeführt: 68 Tests bestanden.
- [ ] Eigene Tests für `recordProfileView`, `submitPlateHint`, `requestVehicleHeroImage`, `maintainChatStories` und `maintainPlateHints` prüfen/ergänzen.
- [x] Lokale Modulinitialisierung kontrolliert: 23 Exports in rund 5,1 Sekunden, keine top-level Netzwerk-/KI-Anfrage gefunden.
- [ ] Frueheren Deploy-Analyse-Timeout beim naechsten gezielten Functions-Deploy weiter beobachten.

## Rules-Emulatoren

- [x] 11 lokale Rules-Testdateien inventarisiert.
- [ ] JDK 21 für Firebase Emulatoren setzen.
- [ ] Vollständige Firestore-/Storage-Emulatortests seriell ausführen.
- [ ] Eigentümer-, Teilnehmer-, Außenstehender- und Admin-Zugriffe prüfen.
- [ ] Profil-, Fahrzeug-, Chat-, Anfrage-, Report-, Settings-, Social-Post- und Verifizierungsregeln prüfen.
- [ ] Keine Rules deployen, bevor alle Emulatorprüfungen bestanden sind.

## Debug- und Release-Build

- [ ] Debug-APK ohne Gerät kompilieren.
- [ ] Release-App-Bundle ohne Gerät kompilieren.
- [ ] Release-Signing-Konfiguration prüfen, ohne Schlüssel oder Passwörter auszugeben.
- [ ] App-Name, Icon, Splashscreen und Paketname im Build prüfen.
- [ ] Build-Artefakte nicht in Git aufnehmen.

## Firebase und Blaze

- [BLAZE] Blaze/Billing erst nach ausdrücklicher Freigabe aktivieren.
- [BLAZE] 11 nur lokal vorhandene Functions nach Tests gruppiert deployen.
- [ ] Firestore Rules nach bestandenem Emulatorlauf gezielt deployen.
- [ ] Storage Rules nach bestandenem Emulatorlauf gezielt deployen.
- [ ] Vier lokale Firestore Indexes mit tatsächlichen Queries abgleichen und Deploybedarf bestätigen.
- [ ] Keine bereits veröffentlichte Function ohne bestätigten lokalen Unterschied neu deployen.
- [LIVE] Function-Logs nach jedem Deploy begrenzt und ohne sensible Inhalte prüfen.

## App Check

- [x] Android-App-Check-Aktivierung ist im App-Code vorbereitet.
- [ ] Debug- und Release-Provider in Firebase prüfen.
- [LIVE] App-Check-Tokens im Gerätebetrieb prüfen.
- [LIVE] App Check erst nach erfolgreichen Tests schrittweise erzwingen.
- [ ] MFA-Recovery steht lokal weiterhin auf `enforceAppCheck: false`; Änderung erst nach Provider-Nachweis.

## Google Auth

- [x] Branding auf `plaqa`, App-Icon, `support@plaqa.de` und `info@plaqa.de` eingestellt.
- [x] Zielgruppe extern und in Produktion.
- [x] Keine zusätzlichen vertraulichen oder eingeschränkten OAuth-Scopes eingetragen.
- [x] Zwei Android-Clients für `com.carma.app` und ein Web-Client vorhanden.
- [ ] Alte `com.example.carma`-Clients erst nach abschließender Plattformprüfung entfernen.
- [WEB] Startseiten-, Datenschutz- und AGB-URL ergänzen.
- [WEB] Branding-Verifizierung erst nach Veröffentlichung der Website einreichen.
- [LIVE] Google-Login, Session-Neustart und MFA auf Android prüfen.

## Auth-E-Mails und Custom SMTP

- [x] IONOS-Postfächer `info`, `support`, `privacy`, `partners` und `no-reply` sind angelegt.
- [x] SPF, DKIM und DMARC wurden mit PASS bestätigt.
- [x] Direkter SMTP-Versand über IONOS Port 587/STARTTLS funktioniert.
- [SUPPORT] Firebase Custom SMTP bleibt deaktiviert, bis Firebase die fehlende Zustellung klärt.
- [SUPPORT] Firebase-Template-Sperre und Custom-Action-URL-Fehler sind beim Support gemeldet.
- [LIVE] Bestätigung, Passwort-Reset, E-Mail-Änderung und MFA-Hinweise nach Supportlösung testen.

## Website und Rechtliches

- [x] `auth.plaqa.de/auth/action` ist per HTTPS erreichbar.
- [WEB] Öffentliche Website `https://plaqa.de/` erstellen.
- [WEB] HTML-Seiten für Datenschutz, AGB, Impressum, Support und FAQ veröffentlichen.
- [WEB] Website-Domain in Google Auth vollständig hinterlegen.
- [ ] Sämtliche Legal-Platzhalter mit fachlichen Releaseentscheidungen füllen.
- [ ] AGB, Datenschutz, Impressum, DSA-/Moderationsangaben und Löschfristen rechtlich prüfen lassen.
- [ ] Legal-Versionen und Aktualisierungsdatum festlegen.

## Ein-Gerät-Livetests

- [LIVE] Registrierung, E-Mail-Verifikation, Login, Logout und Session-Neustart.
- [LIVE] Google Login und SMS-MFA aktivieren, anmelden und entfernen.
- [LIVE] Profilbild, persönliche Datensperre und Profilreferenz-Synchronisierung.
- [LIVE] Fahrzeug erstellen, aktualisieren, Primärfahrzeug setzen und deaktivieren.
- [LIVE] Dokumente hochladen, einreichen, nachreichen und Ablauf prüfen.
- [LIVE] Einstellungen speichern und Standardland unmittelbar übernehmen.
- [LIVE] Kontoexport/-löschung ausschließlich mit freigegebenem Testkonto.
- [LIVE] Zwei Konten nacheinander auf demselben Gerät für Anfragen, Sichtbarkeit und Profilzugriffe verwenden.

## Spätere Zwei-Geräte-Livetests

- [LIVE] Kennzeichensuche mit zwei gleichzeitig aktiven Standorten.
- [LIVE] Kontaktanfrage in Echtzeit senden, annehmen, ablehnen und zurückziehen.
- [LIVE] Chat-Echtzeitstream, Zustellung, Lesebestätigung und Anhänge.
- [LIVE] Push-Benachrichtigungen für Chat, Anfragen, Hinweise und Verifizierung.
- [LIVE] Story-Aufrufe, Antworten und Ausschlüsse zwischen zwei Nutzern.

## Demo- und Testdaten

- [ ] Fünf Beispielbeiträge vor Release entfernen oder strikt auf Debug begrenzen.
- [ ] Testfahrzeug BMW X6 M50d und Debug-Bild vor Release entfernen oder strikt auf Debug begrenzen.
- [ ] Beispiel-Likes, Kommentare, Chats und Anfragen vor Release entfernen oder strikt auf Debug begrenzen.
- [ ] Debug-Kennzeichen `HH-CR 2026` im Release nachweislich deaktiviert lassen.
- [ ] Keine Produktionskonten für Bereinigungs- oder Löschtests verwenden.

## Play Console

- [ ] endgültigen technischen Paketnamen `com.carma.app` bewusst bestätigen.
- [ ] signiertes Android App Bundle erzeugen und intern testen.
- [ ] Store-Name, Kurz-/Langbeschreibung, Screenshots, Icon und Feature-Grafik erstellen.
- [ ] Datenschutzerklärung, Datensicherheit, Altersfreigabe und Inhaltsangaben ausfüllen.
- [ ] interne/geschlossene Testspur durchführen.
- [ ] Crash-/ANR-Berichte und Pre-Launch-Report prüfen.
- [ ] finale Produktionsfreigabe erst nach Website, Legal-Abschluss, Deploys und Live-Tests.

## Git und Sicherung

- [x] Aktueller Branch ist `main`.
- [ ] Lokaler Branch ist drei Commits vor `origin/main`; später kontrolliert pushen.
- [ ] Vorhandene uncommitted Domain-/Hosting-/Settings-Änderungen nach allen statischen Prüfungen committen.
- [ ] Die beiden Abschlussdokumente zusammen mit den beabsichtigten Änderungen stagen.
- [ ] Keine Logs, Secrets, Keystores, Build-Ausgaben oder Emulator-Daten stagen.
- [ ] Abschluss-Commit erstellen und ohne Force-Push nach `origin/main` pushen.
