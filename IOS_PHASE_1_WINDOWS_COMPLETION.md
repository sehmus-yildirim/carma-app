# plaqa iOS Phase 1 unter Windows

Stand: 2026-08-24

## Ergebnis

Die unter Windows programmierbaren iOS-Arbeiten sind umgesetzt. Die Apple-
Developer- und Firebase-Konfiguration ist bis auf App Store Connect und echte
Apple-Geraetetests vorbereitet. Es wurde kein iOS-Build hochgeladen, kein
TestFlight gestartet und nichts veroeffentlicht.

## Abgeschlossen

- iOS-App-Identitaet `de.plaqa.app`, Testziel, Version `1.0.0` und Buildnummer 1
- Firebase-iOS-App und Clientkonfiguration
- iOS 15 als Mindestziel und Podfile
- deutsche Kamera-, Foto-, Mikrofon- und Standorttexte
- Apple Login, Linking, Reauthentifizierung und Widerruf im Flutter-Code
- aktive Apple-Developer-Mitgliedschaft und explizite App-ID `de.plaqa.app`
- Apple-Capabilities Sign in with Apple und Push Notifications
- Associated Domains im Apple-Portal und `applinks:plaqa.de` im Entitlement
- iOS App Check mit App Attest und DeviceCheck-Fallback, weiterhin Monitoring
- kombinierter Apple-Schluessel fuer DeviceCheck und APNs ausserhalb von Git
- APNs-Schluessel fuer Entwicklung und Produktion in Firebase Cloud Messaging
- benutzerdefiniertes Firebase-SMTP ueber IONOS mit `no-reply@plaqa.de`
- Apple Private Email Relay mit der tatsaechlichen Absenderquelle
- FCM-Berechtigung, Token-Lebenszyklus, Hintergrund und Benachrichtigungsrouting
- Safe-Area-, Tastatur-, Medien-, Teilen-, Karten- und Link-Pfade statisch
- vollstaendige iOS-Iconvarianten und plaqa-Launch-Screen
- iOS-Datenschutzmatrix, Privacy Labels, Store-Texte, Review- und Screenshotplan
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

Universal Links sind vorbereitet, aber noch nicht funktionsfaehig freigegeben.
Es fehlen die oeffentliche `apple-app-site-association`-Datei, die finale
Routenbehandlung und der Xcode-/Geraetetest.

App Store Connect ist unter Windows erreichbar, verlangt jedoch vor dem ersten
App-Eintrag die persoenliche Annahme neuer Nutzungsbedingungen. Diese rechtlich
bindende Bestaetigung wurde nicht stellvertretend abgegeben. Der komplette
Store-Entwurf liegt lokal vor und kann danach ohne neue inhaltliche Planung
eingetragen werden.

## Verifikation

- `flutter analyze --no-pub`: letzter dokumentierter Lauf ohne Fehler
- vollstaendiger Flutter-Testlauf: letzter dokumentierter Lauf bestanden
- iOS XML- und JSON-Dateien: statisch gueltig
- aktive Bundle-IDs: keine alte `com.example.carma`-Runner-Konfiguration
- App-Icons: alle referenzierten Varianten vorhanden
- Marketing-Icon: 1024 x 1024, RGB, kein Alpha-Kanal
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
- App Store Connect App-Eintrag: durch persoenliche Vereinbarung blockiert
- App Store Upload: nein
- TestFlight: nein
- oeffentliche Veroeffentlichung: nein

## Git-Ausgangsstand

- Basis vor dieser Aktualisierung: `edd93c3`
- Branch: `main`
- Der Abschlusscommit wird erst nach Diff-, Secret- und Statuskontrolle erstellt.
