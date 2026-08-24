# plaqa iOS Windows Audit

Stand: 2026-08-24
Branch: `main`

## Zweck

Dieser Audit dokumentiert den unter Windows vorbereiteten iOS-Stand. Er trennt
vollstaendig umgesetzte plattformneutrale Arbeit von Aufgaben, die technisch nur
mit Apple Developer Portal, macOS, Xcode oder einem echten iPhone abgeschlossen
werden koennen. Unter Windows wurde kein iOS-Build erzeugt und nichts bei Apple
hochgeladen oder veroeffentlicht.

## Identitaet und Mindeststand

| Bereich | Stand | Status |
| --- | --- | --- |
| App-Name | `plaqa` | Erfuellt |
| Runner Bundle-ID | `de.plaqa.app` | Erfuellt |
| RunnerTests Bundle-ID | `de.plaqa.app.RunnerTests` | Erfuellt |
| Sichtbare Version | `1.0.0` | Erfuellt |
| Buildnummer | `1` | Erfuellt |
| iOS Deployment Target | `15.0` | Erfuellt |
| iPhone-Ausrichtung | nur Hochformat | Erfuellt |
| iPad-Ausrichtung | systemgerecht, vor Store-Freigabe pruefen | Vorbereitet |

`pubspec.yaml` bleibt technisch bei `1.0.0+1`: `1.0.0` ist die sichtbare
Version und `1` die interne Buildnummer.

## Firebase und Anmeldung

- Die Firebase-iOS-App fuer `de.plaqa.app` ist registriert.
- `ios/Runner/GoogleService-Info.plist` gehoert zur neuen Bundle-ID und ist im
  Runner-Target eingebunden.
- `lib/firebase_options.dart` enthaelt die passende iOS-Clientkonfiguration.
- Die Android-Konfiguration blieb auf `de.plaqa.app` unveraendert.
- Google Login besitzt das aus Firebase erzeugte iOS-URL-Scheme.
- Sign in with Apple ist in Dart fuer Anmeldung, Kontoverknuepfung,
  Reauthentifizierung und Token-Widerruf bei Kontoloeschung vorbereitet.
- Das Sign-in-with-Apple-Entitlement ist fuer den Runner hinterlegt.

Offen bleiben die Aktivierung und Schluesselzuordnung im Apple Developer Portal
sowie die abschliessende Provider-Konfiguration und der Test auf einem iPhone.
Die Private-Email-Relay-Quelle `no-reply@plaqa.de` kann erst nach vollstaendig
aktivierter Apple-Developer-Mitgliedschaft registriert werden.

## App Check

Der Flutter-Startcode aktiviert App Check auf Android und iOS:

- iOS Debug: `AppleDebugProvider`
- iOS Profile/Release: App Attest mit DeviceCheck-Fallback
- Android Debug: `AndroidDebugProvider`
- Android Profile/Release: Play Integrity
- automatische Token-Aktualisierung ist aktiv
- Tokens werden weder protokolliert noch gespeichert

Firebase bleibt fuer alle Dienste im Monitoring-Modus. Es wurde keine
Erzwingung aktiviert. Ein iOS-Debug-Token und reale App-Attest-Metriken benoetigen
spaeter einen kontrollierten iPhone-Lauf.

## Push-Benachrichtigungen

`firebase_messaging` ist plattformuebergreifend eingebunden. Vorbereitet sind:

- ausdrueckliche Berechtigungsanfrage
- iOS-Vordergrunddarstellung fuer Hinweis, Badge und Ton
- Verarbeitung im Hintergrund
- Navigation nach Antippen und nach beendetem App-Start
- FCM-Tokenanlage, Tokenwechsel und Entfernung bei Abmeldung
- APNs-Token-Pruefung vor iOS-FCM-Synchronisierung
- private, eigentuemergebundene Firestore-Pfade fuer Push-Tokens

APNs-Key, Push-Capability, Background Mode und Signing muessen auf dem Mac bzw.
im Apple Developer Portal final bestaetigt werden. Ohne diese Apple-Schritte ist
der Dart-Pfad vorbereitet, aber es werden noch keine echten iOS-Pushs zugestellt.

## Berechtigungen und iOS-Oberflaeche

Die folgenden deutschen Nutzungstexte sind in `Info.plist` vorhanden:

- Kamera
- Fotomediathek lesen
- Fotomediathek erweitern
- Mikrofon
- Standort waehrend der Nutzung

Safe Areas werden fuer Hauptnavigation, Dialoge und Bottom Sheets verwendet.
Formulare reagieren auf die Tastatur, vermeiden verdeckte Eingabefelder und
unterstuetzen kontrolliertes Schliessen. Kamera, Galerie, Dateiauswahl, Teilen,
Karten und externe HTTPS-Links besitzen plattformneutrale oder iOS-taugliche
Pfade mit deutschen Fehlerhinweisen. Sichtbare Android-, Play-Store- und
Emulator-Hinweise wurden aus produktiven iOS-Oberflaechen entfernt.

Weiter offen oder bewusst nicht aktiviert:

- Kennzeichen-Spracherkennung auf iOS
- native Sprachmemoaufnahme auf iOS
- Universal Links und Associated Domains
- vollstaendiger Kamera-/Galerie-/Datei-/Tastaturtest auf einem iPhone

Diese offenen Punkte fuehren nicht zu einem ungeschuetzten Android-Channel-Aufruf;
nicht verfuegbare Pfade werden abgefangen oder klar deaktiviert.

## App-Icon und Startbildschirm

- Alle im Assetkatalog referenzierten iPhone-, iPad- und Marketing-Icons sind
  vorhanden.
- Das App-Store-Icon ist 1024 x 1024 Pixel gross und besitzt keinen Alpha-Kanal.
- Die Iconvarianten stammen aus demselben plaqa-q-/Kennzeichen-Motiv.
- Der Launch Screen verwendet adaptive Hintergrundfarben und eine zentrierte
  plaqa-Wortmarke in 1x, 2x und 3x.
- Der fruehere weisse Platzhalter-Startbildschirm wurde entfernt.

Die finale Darstellung bleibt in Xcode und auf echten hellen/dunklen iPhones zu
kontrollieren.

## Datenschutz und App Store

Unter `store_assets/app_store/de-DE/` liegen:

- Store-Texte, Untertitel und Keywords
- App-Privacy-Labels
- Review-Hinweise
- iPhone-Screenshot-Konzept

`IOS_PRIVACY_DATA_MATRIX.md` bildet die tatsaechlich verwendeten Datenarten und
Drittanbieter-SDKs ab. Verwendete URLs:

- Datenschutz: `https://plaqa.de/datenschutz/`
- Support: `https://plaqa.de/support/`
- Kontoloeschung: `https://plaqa.de/konto-loeschen/`

Es werden keine Werbung, kein Verkauf personenbezogener Daten und kein
appuebergreifendes Tracking behauptet. App-Privacy-Angaben muessen vor der
Einreichung noch einmal gegen den dann finalen Produktionscode geprueft werden.

## Pakete und Plattformtrennung

Alle direkten Flutter-Pakete besitzen einen iOS-Pfad oder werden im Code
plattformgerecht abgegrenzt. Der Podfile ist vorhanden, setzt iOS 15 und bindet
Flutter-Pods fuer Runner und RunnerTests ein. CocoaPods kann unter Windows nicht
aufgeloest werden; `pod install` bleibt daher ein Mac-Schritt.

Der native Channel `plaqa/chat_tools` wird auf iOS nicht blind verwendet.
Plattformneutrale Plugins decken Dateiauswahl, URL-Start, Teilen und Karten ab;
Android-spezifische Funktionen besitzen iOS-Fallbacks oder werden als nicht
verfuegbar behandelt.

## Geheimnisse und Git

Von Git ausgeschlossen sind unter anderem:

- `.p8`, `.p12`, `.cer`, Provisioning Profiles und APNs-Schluessel
- Android-Keystores und `android/key.properties`
- Firebase-Admin- und Service-Account-Dateien
- lokale Builds, Logs, Caches und Debug-Tokens

`GoogleService-Info.plist` und `firebase_options.dart` sind Firebase-
Clientkonfigurationen, keine Admin-Schluessel. App-Check-Debug-Tokens werden nur
ueber lokale Build-Defines uebergeben.

## Zwingend spaeter auf einem Mac oder iPhone

1. aktuelles Xcode und CocoaPods verwenden, `pod install` ausfuehren
2. Team, Signing und Provisioning Profiles setzen
3. Sign in with Apple, Push Notifications, App Attest und Background Modes als
   Capabilities bestaetigen
4. APNs-Key in Firebase hinterlegen
5. Private Email Relay fuer `no-reply@plaqa.de` registrieren
6. Debug-/Release-App-Check auf echten Apple-Geraeten beobachten
7. Simulator- und Device-Build, UI-, Auth-, Push-, MFA- und Medien-Livetests
8. App Store Connect, TestFlight und Privacy Labels kontrolliert einrichten

## Sicherheitsgrenzen

App Check wurde nicht erzwungen. Es wurde kein iOS-Build, kein TestFlight-Build,
kein Firebase-Deploy und keine Apple-/Store-Veroeffentlichung durchgefuehrt.
