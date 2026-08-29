# Android Release / Play Console Checkliste

Stand: 2026-08-29

## Technischer Stand

- Package ID: `de.plaqa.app`
- Firebase Android App: `plaqa Android`
- Version: `1.0.0+1`
- Release Bundle: `build/app/outputs/bundle/release/app-release.aab`
- AAB-SHA-256: `1382A293107CCD27193CD0D3FFFD01A5B11BE5E5679FCD4CE89827E730B786C6`
- App Icon: vorbereitet
- Splash Screen: vorbereitet
- Upload-Keystore: lokal erstellt, nicht im Git
- R8 und Resource Shrinking: aktiviert
- `bundletool`, APK-Signatur und 16-KiB-Zip-Alignment: bestanden
- Release-Smoke-Test auf Redmi/Android 13: bestanden
- `flutter analyze`: sauber; 234/234 Flutter-Tests bestanden

## Android Permissions

Im zusammengeführten Release-Manifest geprüft:

- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `CAMERA`
- `INTERNET`
- `RECORD_AUDIO`
- `POST_NOTIFICATIONS`
- ausgewählte Android-13-Medienberechtigungen für die implementierten Medienpfade

Eine direkte Kontakte-Berechtigung ist nicht enthalten. Die endgültigen
Play-Erklärungen werden gegen die tatsächlich genutzten System-Picker und
App-Funktionen abgeglichen.

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

- Rechtstexte und Data-Safety-Angaben sind noch nicht final fachlich/juristisch geprüft.
- App-Name/Branding muss vor Store-Einreichung markenrechtlich freigegeben sein.
- Produktive Push-Zustellung und App-Check-Metriken benötigen einen ausdrücklich
  freigegebenen Staging-/Live-Gerätetest.
- iOS- und finaler RC-Gate stehen noch aus.

## Nächste technische Schritte

1. Play Console Store Listing vorbereiten.
2. Datenschutzangaben final mit den tatsächlichen Funktionen und Rechtstexten abgleichen.
3. AAB nach ausdrücklicher Freigabe in die interne Testspur hochladen.
4. Play App Signing und Upload-Zertifikat kontrollieren.
5. Interne Testgruppe ausrollen und Rückmeldungen dokumentieren.

Der lokale Android-RC-Gate ist bestanden. Es wurde noch nichts in die Play
Console hochgeladen oder veröffentlicht. Der vollständige Nachweis steht in
`docs/qa/ANDROID_RELEASE_CHECKLIST.md`.
