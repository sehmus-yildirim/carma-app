# plaqa iOS Phase 1 unter Windows

Stand: 2026-08-24

## Ergebnis

Die unter Windows moeglichen Arbeiten der iOS-Phase 1 sind umgesetzt. Bundle-ID,
iOS 15, Firebase-Client, Berechtigungen, Apple-Anmeldepfade, App Check, FCM-
Lebenszyklus, plattformgerechte UI-Pfade, App-Icon, Launch Screen sowie die
Datenschutz- und Store-Unterlagen sind vorbereitet.

## Abgeschlossen

- iOS-App-Identitaet `de.plaqa.app`, Testziel und Version
- Firebase-iOS-App und Clientkonfiguration
- iOS 15 als Mindestziel und Podfile
- deutsche Kamera-, Foto-, Mikrofon- und Standorttexte
- Apple Login, Linking, Reauthentifizierung und Widerruf im Flutter-Code
- iOS App Check: Debug sowie App Attest mit DeviceCheck-Fallback
- FCM-Berechtigung, Token-Lebenszyklus, Hintergrund und Benachrichtigungsrouting
- Safe-Area-, Tastatur-, Medien-, Teilen-, Karten- und Link-Pfade statisch
- vollstaendige iOS-Iconvarianten und adaptiver plaqa-Launch-Screen
- iOS-Datenschutzmatrix, Privacy Labels, Store-Texte, Review- und Screenshotplan
- System/Hell/Dunkel mit lokaler und Firestore-Persistenz
- appweite Standardkarten ohne alte aeussere Schatten und Glows
- Secrets und Apple-Schluessel durch `.gitignore` abgesichert

## Bewusste Grenzen

Ohne Mac, Xcode, Apple-Konfiguration und echtes iPhone koennen folgende Punkte
nicht abgeschlossen werden:

- CocoaPods-Aufloesung und iOS-Kompilierung
- Signing, Provisioning und Apple-Capabilities
- APNs-Key und echte Push-Zustellung
- Apple Provider und Private Email Relay final aktivieren
- App-Attest-/DeviceCheck-Metriken und Debug-Token registrieren
- Kamera-, Galerie-, Dateien-, Tastatur-, Safe-Area-, Auth-, MFA- und Push-Livetest
- App Store Connect oder TestFlight

Diese Punkte wurden nicht als bestanden markiert. Eine fehlende Anmeldung oder
Freigabe hat die Windows-Arbeit nicht unterbrochen.

## Verifikation

- `flutter analyze --no-pub`: ohne Fehler oder Warnungen
- vollstaendiger Flutter-Testlauf: 205 Tests bestanden
- gezielter Firestore-Rules-Test: 5 Tests bestanden
- App Check: Apple Debug sowie App Attest/DeviceCheck durch Tests bestaetigt
- Theme: Persistenz, Firestore-Werte und Kernkontraste durch Tests bestaetigt
- iOS XML- und JSON-Dateien: statisch gueltig
- aktive Bundle-IDs: keine alte `com.example.carma`-Konfiguration vorhanden
- App-Icons: 19 Eintraege vorhanden, keine Groessenabweichung
- Marketing-Icon: 1024 x 1024, RGB, kein Alpha-Kanal
- sensible Apple-, Android- und Firebase-Admin-Dateien: von Git ausgeschlossen
- `git diff --check`: ohne Fehler; Zeilenendungs-Hinweise sind nicht inhaltlich

## UI-Bereinigung nach Hauptnavigation

- Suchen: Laender-, Regions-, Kennzeichen-, Status- und Ergebniskarten sind flach
  begrenzt; keine alten aeusseren Kartenlichter.
- Profil und Startseite: Umschalter, Storyleiste, Beitraege, Fahrzeugdaten und
  Informationskarten verwenden dieselben flachen Flaechen.
- Chats und Anfragen: Tabs, Listen, Leerzustaende, Composer und normale Dialoge
  besitzen keine alten aeusseren Glows.
- Melden: Kategorien, Laender, Region, Kennzeichen und Status verwenden den
  einheitlichen Kartenstil.
- Einstellungen: alle gemeinsam genutzten Bereichskarten, Hinweise, Schalter und
  Aktionsflaechen folgen dem adaptiven Theme ohne Kartenschatten.

Kennzeichenrelief sowie Overlays direkt auf Fotos, Videos, Storys und dem
Fahrzeugbild bleiben bewusst erhalten. Sie liegen innerhalb des Medieninhalts
und sichern Lesbarkeit beziehungsweise die realistische Kennzeichendarstellung.

## Theme

In `App-Komfort > Design` stehen `System`, `Hell` und `Dunkel` zur Auswahl. Die
Auswahl wird sofort dargestellt, lokal gespeichert und beim Speichern mit den
Nutzereinstellungen in Firestore synchronisiert. Nicht gespeicherte Aenderungen
werden beim Verlassen kontrolliert zurueckgenommen. `System` folgt der
Geraetehelligkeit. Die hellen Flaechen sind neutral weiss/grau, Texte dunkel und
die bestehenden blauen plaqa-Akzente bleiben erhalten.

## Veroeffentlichungsstatus

- Firebase Deploy: nein
- App Check Enforcement: nein
- App Store Upload: nein
- TestFlight: nein
- oeffentliche Veroeffentlichung: nein
