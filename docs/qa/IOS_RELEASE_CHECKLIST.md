# plaqa iOS Release Checklist

Stand: 2026-08-29
Windows-Basis: `main` / `3ad20157b0930e613235e112528d21c35e1860e7`
Bundle-ID: `de.plaqa.app`
Version: `1.0.0+1`

## Gate-7-Urteil

Die unter Windows zuverlässig ausführbare iOS-Release-Vorbereitung ist
abgeschlossen. Die native Konfiguration ist konsistent, die fehlenden Push-,
Background- und App-Attest-Einstellungen wurden ergänzt und 126 dauerhafte
Konfigurationsprüfungen bestehen.

Der iOS-Build ist noch nicht als Store-Artefakt freigegeben. Xcode, Apple
Signing, Provisioning, ein echtes iPhone und TestFlight erfordern macOS und
bleiben deshalb ausdrücklich `MANUAL REQUIRED`. Es wurde nichts zu Apple oder
Firebase hochgeladen, keine App-Check-Erzwingung aktiviert und nichts
veröffentlicht.

## Unter Windows abgeschlossen

| ID | Prüfung | Ergebnis | Status |
|---|---|---|---|
| IOS-ID-001 | Bundle-ID und App-Name | `de.plaqa.app`, `plaqa` | PASS |
| IOS-VERSION-001 | App-Version | `1.0.0+1` | PASS |
| IOS-TARGET-001 | Mindestversion | Podfile, Xcode und Flutter Framework auf iOS 15.0 | PASS |
| IOS-FIREBASE-001 | Firebase-Zuordnung | Bundle-, Projekt-, App-, Sender- und OAuth-Client-ID konsistent | PASS |
| IOS-URL-001 | Google-Anmelde-URL-Scheme | stimmt mit `REVERSED_CLIENT_ID` überein | PASS |
| IOS-PRIVACY-001 | Native Berechtigungstexte | Kamera, Standort, Mikrofon, Fotos lesen/schreiben vorhanden | PASS |
| IOS-PUSH-001 | Push-Konfiguration | APNs-Entitlement, Push-Capability, Background fetch und Remote notifications vorhanden | PASS WINDOWS |
| IOS-SWIZZLE-001 | Firebase Messaging | Method Swizzling nicht deaktiviert | PASS |
| IOS-APPLE-001 | Apple-Anmeldung | Entitlement, Xcode-Capability und FlutterFire-Provider vorhanden | PASS WINDOWS |
| IOS-APPCHECK-001 | App Check | App-Attest-Entitlement `production`; App Attest mit DeviceCheck-Fallback im Release-Code | PASS WINDOWS |
| IOS-LIFECYCLE-001 | Flutter iOS Lifecycle | AppDelegate, Pluginregistrierung und SceneDelegate konsistent | PASS |
| IOS-ICON-001 | App-Icons | 19/19 Slots, exakte Pixelmaße, einschließlich 1024 px ohne Alpha | PASS |
| IOS-SECRET-001 | Signiermaterial | keine `.p8`, `.p12`, Profile, Zertifikate oder privaten Schlüssel im iOS-Baum | PASS |
| IOS-TEAM-001 | Apple-Team | kein fremdes Team fest im Repository verdrahtet | PASS |
| IOS-CONFIG-001 | Dauerhafter Validator | `npm run test:ios:windows`, 126/126 Prüfungen | PASS |
| IOS-FLUTTER-001 | Flutter-Gesamtregression | 237/237 Tests | PASS |
| IOS-ANALYZE-001 | Flutter Analyze | keine Befunde in 172,8 Sekunden | PASS |
| IOS-FUNCTIONS-001 | Functions-Regression | 100/100 Tests | PASS |
| IOS-RULES-001 | Firestore-/Storage-Rules | 109/109 Tests; Emulatorports danach frei | PASS |
| IOS-WEB-001 | Website-Regression | 30/30 Tests | PASS |

## Auf dem Mac auszuführen

Diese Reihenfolge ist verbindlich. Ein Schritt erhält erst nach tatsächlicher
Ausführung `PASS`.

1. Aktuelles Xcode und CocoaPods installieren; `flutter doctor -v` ohne
   iOS-Toolchainfehler abschließen.
2. `ios/Runner.xcworkspace` öffnen, das eigene Apple-Developer-Team wählen und
   Automatic Signing für `de.plaqa.app` aktivieren. Keine Team-ID ins
   Repository schreiben, wenn sie nur lokal benötigt wird.
3. Im Apple Developer Portal für die App-ID Push Notifications, Sign in with
   Apple und App Attest bestätigen; danach die Provisioning Profiles erneuern.
4. In Xcode unter Signing & Capabilities Push Notifications, Background Modes
   mit Background fetch/Remote notifications, Sign in with Apple und App Attest
   kontrollieren.
5. Eine APNs-Authentifizierungsdatei im Firebase-Projekt hinterlegen. Die
   `.p8`-Datei, Key-ID und Team-ID bleiben außerhalb des Repositorys.
6. Im Firebase-Auth-Bereich den Apple-Provider einschließlich Apple-Schlüssel,
   Team-ID, Key-ID und Service-ID prüfen. Die private E-Mail-Relay-Domain für
   ausgehende Auth-E-Mails kontrollieren.
7. Im Firebase-App-Check-Bereich die iOS-App für App Attest registrieren.
   Erzwingung erst nach erfolgreicher TestFlight-Messung legitimer Tokens und
   separater Freigabe aktivieren.
8. `flutter clean`, `flutter pub get`, `cd ios && pod install`, danach
   `flutter build ios --release` und `flutter build ipa` ausführen.
9. Das Xcode-Archiv validieren: Signatur, endgültige Entitlements,
   Deployment-Ziel, dSYMs, App-Icon, Launch-Screen und eingebettete Frameworks.
10. Den Xcode Privacy Report des Archivs prüfen. Privacy Manifests und Required
    Reason APIs aller eingebetteten Pods müssen im fertigen Archiv valide sein;
    ein leeres oder geratenes `PrivacyInfo.xcprivacy` ist kein zulässiger Ersatz.
11. Den IPA-Upload ausschließlich in eine interne TestFlight-Gruppe vornehmen,
    nachdem der Nutzer ihn ausdrücklich freigegeben hat.

## Echte iPhone-Abnahme

Mindestens ein unterstütztes iPhone mit iOS 15 und ein aktuelles iPhone/iOS
testen. Wenn nur ein Gerät verfügbar ist, erhält die fehlende Kombination den
Status `MANUAL REQUIRED`.

1. Neuinstallation, erster Start, Onboarding, Registrierung, E-Mail-Verifizierung,
   Login, Abmeldung und Session-Wiederherstellung.
2. Sign in with Apple: neuer Nutzer, vorhandener Nutzer, Abbruch, Linken,
   Re-Authentifizierung und Kontolöschung samt Token-Widerruf.
3. Kamera, Fotos lesen/schreiben, Mikrofon, Standort sowie Ablehnung und spätere
   Freigabe in den iOS-Einstellungen.
4. Push im Vordergrund, Hintergrund und nach vollständigem Beenden; Tippen auf
   die Benachrichtigung muss jeweils zum korrekten Inhalt navigieren.
5. APNs-/FCM-Token bei erster Zustimmung, App-Neustart, Neuinstallation und
   Tokenwechsel; keine Registrierung vor vorhandenem APNs-Token.
6. App-Check-Token auf echtem Gerät und gültige Firebase-Metriken nachweisen,
   bevor irgendeine Erzwingung erwogen wird.
7. Kernreise mit zwei künstlichen Konten: Fahrzeug, Suche, Anfrage, Annahme,
   Chat, Medien, Blockierung, Story/Beitrag, Meldung und Kontolöschung.
8. Offline/Online, Hintergrund/Vordergrund, Speicherwarnung, Prozessbeendigung,
   Dark Mode, große Schrift und VoiceOver-Grundbedienung.
9. Kaltstart, Scroll-/Animationsruckler, Speicher, Netzwerkfehler, Crash- und
   ANR-Äquivalente mit Xcode Instruments und Geräteprotokollen prüfen.

## App Store Connect

- App-Datenschutzangaben und Datenschutzerklärung fachlich/rechtlich abnehmen
- Altersfreigabe, Kategorie, Länder, Support- und Marketing-URL bestätigen
- iPhone-/iPad-Screenshots und Store-Texte in allen Sprachen prüfen
- Export-Compliance, Verschlüsselung, Content-Rechte und Review-Hinweise klären
- internen TestFlight-Bericht dokumentieren
- öffentlicher Rollout erst in Gate 8 und nur nach ausdrücklicher Freigabe

## Abschlusskriterium

Gate 7 ist im vereinbarten Windows-Umfang `PASS WINDOWS`. Die vollständige
iOS-Geräte- und Store-Abnahme wird erst `PASS`, wenn alle Mac-, Portal-, iPhone-
und TestFlight-Punkte oben mit realen Nachweisen abgeschlossen sind.
