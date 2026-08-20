# Android Closed Testing Plan

Stand: 2026-07-03

## Test-Build

- App Bundle: `build/app/outputs/bundle/release/app-release.aab`
- APK für Gerätetest: `build/app/outputs/flutter-apk/app-release.apk`
- Package ID: `de.plaqa.app`
- Version: `1.0.0+1`

## Release Notes für Tester

Erster geschlossener Android-Test von plaqa.

Bitte teste:

- Registrierung, Login und Passwort vergessen
- Profil anlegen und speichern
- Profilbild, Fahrzeugdaten und Kennzeichen
- Kennzeichen-Suche und Kontaktanfrage
- Hinweise melden
- Einstellungen speichern
- Chat und Story, soweit verfügbar

Bekannt:

- Story speichern und Testchat/Chat-Sichtbarkeit sind noch offene Blocker und werden gesondert behoben.
- Der App-Name ist wegen möglicher Namensüberschneidungen noch nicht final.

## Tester-Voraussetzungen

- Android 13 oder neuer bevorzugt
- Standortfreigabe aktivieren
- Kamera/Mikrofon erlauben, wenn abgefragt
- Stabile Internetverbindung
- Testkonto mit echter E-Mail-Adresse

## Testfälle

### 1. App-Start

- App startet ohne Crash.
- Splash Screen erscheint kurz und sauber.
- App Icon sieht im Launcher korrekt aus.
- Navigation reagiert ohne falsche Badge-Zahlen oder sichtbare Touch-Spuren.

### 2. Auth

- Neues Konto registrieren.
- Login mit bestehendem Konto.
- Passwort-zurücksetzen-Mail anfordern.
- Falsche Logindaten zeigen klare deutsche Fehlermeldung.
- Logout und erneuter Login funktionieren.

### 3. Profil

- Anzeigename speichern.
- Profilbild setzen und nach App-Neustart prüfen.
- Fahrzeugmarke, Modell, Farbe und Kennzeichen speichern.
- Kontaktanfragen erlauben aktivieren/deaktivieren.
- Anonyme Hinweise erlauben aktivieren/deaktivieren.
- Verifizierungsdokumente nur mit Testdaten prüfen.

### 4. Kennzeichen-Suche

- Kennzeichen über Stadt/Buchstaben/Zahlen eingeben.
- Spracheingabe testen.
- Suche ohne Treffer prüfen.
- Suche mit vorhandenem Testprofil prüfen.
- Doppelte Anfrage an dasselbe Kennzeichen muss verhindert werden.
- Such-Credits müssen korrekt angezeigt werden.

### 5. Melden

- Kategorie auswählen.
- Kennzeichen eingeben.
- Standort per GPS setzen.
- Adresse manuell setzen.
- Optional Foto hinzufügen.
- Hinweis senden.
- Gesendete Hinweise müssen mit Datum/Uhrzeit sichtbar sein.

### 6. Chat

- Eingehende Anfrage annehmen.
- Chat muss erscheinen und geöffnet werden.
- Textnachricht senden.
- Bild, Dokument, Standort, Kontakt und Sprachnachricht testen.
- Archivieren, Blockieren und Löschen testen.

### 7. Story

- Foto aus Kamera aufnehmen.
- Foto aus Galerie auswählen.
- Text hinzufügen und bewegen.
- Fahrzeug-, Standort- und Status-Sticker testen.
- Story teilen.
- Story ansehen und löschen.

### 8. Einstellungen

- Push-/Benachrichtigungsschalter prüfen.
- Datenschutz-/Rechtstext-Links öffnen.
- Konto-/Datenfunktionen prüfen.
- Speicherung nach App-Neustart prüfen.

## Feedback-Format

Tester sollen pro Fehler möglichst angeben:

- Testkonto/E-Mail
- Gerät und Android-Version
- Uhrzeit
- Bereich der App
- Schritte bis zum Fehler
- Screenshot oder Bildschirmaufnahme
- Fehlermeldung im Wortlaut

## Go/No-Go für Closed Testing

Vor breiterem Closed Testing sollten diese Punkte grün sein:

- App startet als Release-Build stabil.
- Registrierung/Login funktionieren.
- Profil speichern funktioniert.
- Kennzeichen-Suche funktioniert ohne Permission-Fehler.
- Melden funktioniert ohne Permission-Fehler.
- Story-Speichern-Blocker ist behoben oder klar als deaktivierter Testbereich markiert.
- Chat-Testdaten oder echte Anfrage funktionieren zuverlässig.
