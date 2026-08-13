# Android Play Console Einreichung

Stand: 2026-07-03

## App-Identität

- App-Name: noch final entscheiden
- Package ID: `com.carma.app`
- Version: `1.0.0+1`
- Build-Datei: `build/app/outputs/bundle/release/app-release.aab`
- Kategorie-Vorschlag: Social oder Lifestyle
- Zielplattform: Android

## Kurzbeschreibung Entwurf

plaqa verbindet Fahrzeughalter geschützt über ihr Kennzeichen.

## Vollständige Beschreibung Entwurf

plaqa hilft Fahrern, über ein Kennzeichen geschützt Kontakt aufzunehmen oder wichtige Hinweise zu senden. Nutzer können ein Profil mit Fahrzeugdaten anlegen, Kontaktanfragen senden, Hinweise melden und nach angenommener Anfrage miteinander chatten.

Wichtige Funktionen:

- Kennzeichen-Suche mit Kontaktanfrage
- Geschützte Kommunikation zwischen Nutzern
- Anonyme Hinweise an Fahrzeughalter
- Profil mit Fahrzeugdaten und Kennzeichen
- Chat mit Medien, Standort, Dokumenten und Sprachnachrichten
- Einstellungen für Sichtbarkeit und Datenschutz

Hinweis: Die finalen Store-Texte müssen vor Veröffentlichung noch rechtlich und markenrechtlich geprüft werden.

## Play Console Datenangaben

### Erhobene oder verarbeitete Daten

- E-Mail-Adresse: Konto, Login, Kommunikation
- Nutzer-ID: Authentifizierung und Datenzuordnung
- Anzeigename/Profilangaben: Profil und Kommunikation
- Kennzeichen/Fahrzeugdaten: Kernfunktion der App
- Standort: Kennzeichen-Suche, Hinweise, Standortanhänge
- Fotos/Videos: Profilbild, Chat, Story, Hinweise
- Audio: Sprachnachrichten
- Dateien/Dokumente: Chat- und Verifizierungsdokumente
- Nachrichten: Chatnachrichten, Story-Antworten, Hinweise
- App-Aktivität: Suchanfragen, Kontaktanfragen, Status von Hinweisen
- Geräte-/Firebase-IDs: App-Funktion, Sicherheit, Auth

### Zweck der Datenverarbeitung

- App-Funktionalität
- Kontoverwaltung
- Nutzerkommunikation
- Sicherheit, Betrugsprävention und Missbrauchsschutz
- Support und Fehleranalyse

### Datenweitergabe

Technisch werden Daten über Firebase/Google Cloud verarbeitet. Ob das in der Play Console als Weitergabe anzugeben ist, muss final mit Datenschutztext und Firebase-Vertrag geprüft werden.

### Sicherheit

- Datenübertragung über HTTPS/Firebase
- Zugriff über Firebase Auth und Security Rules eingeschränkt
- Konto-/Datenlöschung ist in den Einstellungen vorbereitet

## Content Rating / Zielgruppe

Voraussichtlich:

- Keine Glücksspielinhalte
- Keine expliziten Inhalte
- Nutzerkommunikation vorhanden
- Meldungen/Hinweise durch Nutzer möglich
- Moderation/Abuse-Prozess rechtlich und organisatorisch finalisieren

## App-Berechtigungen für Erklärung

Aktuelle Android-Berechtigungen:

- Standort: Suche, Hinweise und Standortanhänge
- Kamera: Profilbild, Chat-/Story-/Hinweisfoto
- Mikrofon: Sprachnachrichten
- Internet: Firebase und App-Funktionen

Später prüfen:

- Benachrichtigungen für Push Notifications
- Kontakte, falls echte Telefonkontakte direkt gelesen werden

## Manuelle Play Console Schritte

1. Neue App in Play Console anlegen.
2. Package ID `com.carma.app` prüfen.
3. App Bundle `app-release.aab` hochladen.
4. Store Listing ausfüllen.
5. App Icon, Screenshots und Feature Graphic hochladen.
6. Datenschutzrichtlinie-URL eintragen.
7. Data Safety Formular ausfüllen.
8. Content Rating Fragebogen ausfüllen.
9. Zielgruppe und App-Inhalte ausfüllen.
10. Internen Test Track erstellen.
11. Tester-Liste einrichten.
12. Opt-in-Link an Tester senden.
13. Testfeedback sammeln.
14. Erst nach stabiler Testphase Closed Testing starten.

## Noch nicht releasebereit

- Story-Speicherfehler muss behoben werden.
- Chat/Testchat-Sichtbarkeit muss behoben werden.
- Rechtstexte müssen final geprüft werden.
- App-Name/Marke muss final entschieden werden.
- Push Notifications sind noch offen.
