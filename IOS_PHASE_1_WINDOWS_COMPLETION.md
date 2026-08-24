# plaqa iOS Phase 1 unter Windows

Stand: 2026-08-25

## Ergebnis

Die unter Windows programmierbaren iOS-Arbeiten sind umgesetzt. Die Apple-
Developer-, Firebase- und App-Store-Connect-Grundkonfiguration ist bis auf den
finalen Build-Abgleich und echte Apple-Geraetetests vorbereitet. Es
wurde kein iOS-Build hochgeladen, kein TestFlight gestartet und nichts
veroeffentlicht.

## Abgeschlossen

- iOS-App-Identitaet `de.plaqa.app`, Testziel, Version `1.0.0` und Buildnummer 1
- Firebase-iOS-App und Clientkonfiguration
- iOS 15 als Mindestziel und Podfile
- deutsche Kamera-, Foto-, Mikrofon- und Standorttexte
- Apple Login, Linking, Reauthentifizierung und Widerruf im Flutter-Code
- aktive Apple-Developer-Mitgliedschaft und explizite App-ID `de.plaqa.app`
- Apple-Capabilities Sign in with Apple und Push Notifications
- Associated Domains fuer Version 1 kontrolliert deaktiviert, weil noch kein
  eingehendes Universal-Link-Routing und keine AASA-Datei existiert
- iOS App Check mit App Attest und DeviceCheck-Fallback, weiterhin Monitoring
- kombinierter Apple-Schluessel fuer DeviceCheck und APNs ausserhalb von Git
- APNs-Schluessel fuer Entwicklung und Produktion in Firebase Cloud Messaging
- benutzerdefiniertes Firebase-SMTP ueber IONOS mit `no-reply@plaqa.de`
- Apple Private Email Relay mit der tatsaechlichen Absenderquelle
- FCM-Berechtigung, Token-Lebenszyklus, Hintergrund und Benachrichtigungsrouting
- Safe-Area-, Tastatur-, Medien-, Teilen-, Karten- und Link-Pfade statisch
- vollstaendige iOS-Iconvarianten und plaqa-Launch-Screen
- iOS-Datenschutzmatrix, Privacy Labels, Store-Texte, Review- und Screenshotplan
- App-Store-Connect-Entwurf fuer `plaqa`, Apple-ID `6804814664`, Version
  `1.0.0`, kostenlos, DACH, nur iOS und manuelle Veroeffentlichung
- acht iPhone- und acht iPad-Screenshots als gespeicherter Store-Entwurf
- iPad-Screenshots lokal als acht JPEG-Dateien mit `2048 x 2732` archiviert
- Altersfreigabe 16+, Inhaltsrechte, Copyright, Review-Kontakt und geschuetztes
  Review-Testkonto in App Store Connect gespeichert
- App Privacy mit 19 Datentypen als unveroeffentlichter Entwurf vorbereitet
- appweite Standardkarten ohne alte aeussere Schatten und Glows
- Secrets und Apple-Schluessel durch `.gitignore` abgesichert

## Bewusste Grenzen

Ohne Mac, Xcode und echtes iPhone koennen folgende Punkte nicht abgeschlossen
werden:

- CocoaPods-Aufloesung und iOS-Kompilierung
- Signing, Provisioning und finale Xcode-Capability-Pruefung
- Erneuerung der Provisioning Profiles nach Capability-Aenderungen
- APNs-Zustellung und Benachrichtigungsrouting auf einem echten iPhone
- App-Attest-/DeviceCheck-Metriken und Debug-Token auf einem echten Geraet
- Apple Login, Relay, Kamera, Galerie, Dateien, Tastatur, Safe Area und MFA live
- App-Store-Build, TestFlight und Review

Universal Links sind fuer Version 1 bewusst deaktiviert. Eine spaetere
Einfuehrung benoetigt die oeffentliche `apple-app-site-association`-Datei,
eingehendes Flutter-Routing, erneute Aktivierung der Capability sowie einen
Xcode-/Geraetetest.

Die App-Store-Connect-Nutzungsbedingungen wurden persoenlich angenommen. Der
App-Eintrag und die nicht rechtlich bindenden Metadaten sind als Entwurf
gespeichert. Altersfreigabe 16+, Inhaltsrechte, Copyright, Review-Kontaktdaten,
Review-Testkonto sowie acht iPhone- und acht iPad-Screenshots sind hinterlegt.
App Privacy bleibt mit 19 Datentypen unveroeffentlicht und muss zusammen mit den
Store-Angaben gegen den finalen iOS-Build abgeglichen werden. Der Build bleibt
offen.

## Verifikation

- `flutter analyze --no-pub`: letzter dokumentierter Lauf ohne Fehler
- vollstaendiger Flutter-Testlauf: letzter dokumentierter Lauf bestanden
- iOS XML- und JSON-Dateien: statisch gueltig
- aktive Bundle-IDs: keine alte `com.example.carma`-Runner-Konfiguration
- App-Icons: alle referenzierten Varianten vorhanden
- Marketing-Icon: 1024 x 1024, RGB, kein Alpha-Kanal
- App Store Connect: je acht iPhone- und iPad-Screenshots nach Neuladen
  vorhanden, verarbeitet und korrekt geordnet
- lokales iPad-Archiv: acht JPEG-Dateien, je 2048 x 2732, RGB ohne Alpha
- App Check: App Attest und DeviceCheck in Firebase registriert
- Cloud Messaging: APNs-Authentifizierungsschluessel fuer Entwicklung und
  Produktion hinterlegt
- sensible Apple-, Android- und Firebase-Admin-Dateien: von Git ausgeschlossen
- App Check Enforcement: nicht aktiviert

## UI-Bereinigung nach Hauptnavigation

- Suchen: Laender-, Regions-, Kennzeichen-, Status- und Ergebniskarten sind
  flach begrenzt; keine alten aeusseren Kartenlichter.
- Profil und Startseite: Umschalter, Storyleiste, Beitraege, Fahrzeugdaten und
  Informationskarten verwenden dieselben flachen Flaechen.
- Chats und Anfragen: Tabs, Listen, Leerzustaende, Composer und normale Dialoge
  besitzen keine alten aeusseren Glows.
- Melden: Kategorien, Laender, Region, Kennzeichen und Status verwenden den
  einheitlichen Kartenstil.
- Einstellungen: gemeinsam genutzte Bereichskarten, Hinweise, Schalter und
  Aktionsflaechen verwenden den dunklen plaqa-Kartenstil ohne aeussere Glows.

Kennzeichenrelief sowie Overlays direkt auf Fotos, Videos, Storys und dem
Fahrzeugbild bleiben bewusst erhalten. Sie liegen innerhalb des Medieninhalts
und sichern Lesbarkeit beziehungsweise die Kennzeichendarstellung.

## Theme

plaqa verwendet aktuell ausschliesslich das abgestimmte dunkle Design. Die
fruehere Auswahl `System`, `Hell` und `Dunkel` wurde nach der visuellen Pruefung
zurueckgenommen. In `App-Komfort` wird kein unfertiges helles Design angeboten.
Die blauen plaqa-Akzente und die dunklen Kontraste bleiben unveraendert.

## Veroeffentlichungsstatus

- Firebase App Check/Cloud-Messaging-Konfiguration: vorbereitet
- Firebase Deploy: nein
- App Check Enforcement: nein
- App Store Connect App-Eintrag: Metadaten und persoenlich bestaetigte Angaben
  als Entwurf gespeichert; finaler Build-Abgleich offen
- App Store Upload: nein
- TestFlight: nein
- oeffentliche Veroeffentlichung: nein

## Git-Ausgangsstand

- Basis vor dieser Aktualisierung: `8ec13b1`
- Branch: `main`
- Der Abschlusscommit wird erst nach Diff-, Secret- und Statuskontrolle erstellt.
