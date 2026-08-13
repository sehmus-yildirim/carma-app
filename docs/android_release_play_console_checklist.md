# Android Release / Play Console Checkliste

Stand: 2026-07-03

## Technischer Stand

- Package ID: `com.carma.app`
- Firebase Android App: `plaqa Android`
- Version: `1.0.0+1`
- Release Bundle: `build/app/outputs/bundle/release/app-release.aab`
- App Icon: vorbereitet
- Splash Screen: vorbereitet
- Upload-Keystore: lokal erstellt, nicht im Git
- `flutter analyze`: sauber

## Android Permissions

Aktuell im AndroidManifest:

- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `CAMERA`
- `INTERNET`
- `RECORD_AUDIO`

Noch nicht im Manifest:

- Kontakte-Berechtigung. Falls echte Telefonkontakte direkt aus der Kontaktliste gelesen werden sollen, muss später geprüft werden, ob `READ_CONTACTS` nötig ist. Wenn nur ein System-Picker genutzt wird, kann es eventuell ohne diese Berechtigung bleiben.
- Benachrichtigungen. Für Push Notifications ab Android 13 wird später `POST_NOTIFICATIONS` relevant.
- Medien/Speicher. Aktuell nutzt die App Picker/Kamera; vor einer Play-Einreichung muss final geprüft werden, ob Android 13+ Medienberechtigungen nötig sind.

## Play Console: Datenschutzangaben vorbereiten

Voraussichtlich anzugeben, weil die App diese Daten für MVP-Funktionen nutzt oder speichern kann:

- Standort: ungefährer und genauer Standort
- Personenbezogene Daten: Name/Anzeigename, E-Mail-Adresse, Nutzer-ID, optional Telefonnummer
- Nachrichten: Chatnachrichten, Story-Antworten, Hinweise
- Fotos/Videos: Profilbild, Chatbilder, Storymedien, Meldefotos
- Audio: Sprachnachrichten
- Dateien/Dokumente: Chatdokumente, Profil-/Verifizierungsdokumente
- App-Aktivität: App-Interaktionen, Such-/Anfrage-Aktionen, Status von Hinweisen/Anfragen
- Geräte- oder andere IDs: Firebase/Auth/Installations-IDs

Voraussichtlich Zwecke:

- App-Funktionalität
- Kontoverwaltung
- Betrugsprävention, Sicherheit und Compliance
- Entwicklerkommunikation, falls Push/Support später aktiv wird

Voraussichtlich Sicherheitsangaben:

- Daten werden per Firebase/HTTPS verschlüsselt übertragen.
- Nutzer können Konto-/Datenlöschung in den Einstellungen anstoßen.
- Datenschutztext muss final zur tatsächlichen Datennutzung passen.

## Play Console: Store Listing

Noch vorzubereiten:

- App-Name final wegen Namenskonflikt prüfen
- Kurzbeschreibung
- Vollständige Beschreibung
- Kategorie
- Kontakt-E-Mail
- Datenschutz-URL
- Screenshots
- Feature Graphic
- App Icon final prüfen

## Closed Testing

Empfohlener Ablauf:

1. Internen Test starten.
2. `app-release.aab` hochladen.
3. Tester-E-Mail-Liste anlegen.
4. Feedback-E-Mail oder Feedback-Link eintragen.
5. Opt-in-Link an Tester schicken.
6. Testcheckliste durchgehen:
   - Registrierung/Login
   - Profil speichern
   - Kennzeichen-Suche
   - Melden
   - Chat
   - Story
   - Einstellungen
7. Erst nach stabiler interner Runde in Closed Testing gehen.

## Offene Release-Risiken

- Story speichern hat noch bekannten Firebase/Firestore-Blocker.
- Testchat/Chat-Sichtbarkeit ist noch nicht final gelöst.
- Rechtstexte sind noch nicht final juristisch geprüft.
- App-Name/Branding ist wegen bestehender Apps mit ähnlichem Namen noch offen.
- Push Notifications sind noch nicht final.

## Nächste technische Schritte

1. Release-App auf Gerät testen.
2. Bekannte Story-/Chat-Blocker fixen.
3. Play Console Store Listing vorbereiten.
4. Datenschutzangaben final mit echten Rechtstexten abgleichen.
5. Internen Test veröffentlichen.
