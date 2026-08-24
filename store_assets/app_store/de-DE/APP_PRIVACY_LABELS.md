# plaqa App Privacy Labels (de-DE)

Stand: 2026-08-24

Technische Quelle: `IOS_PRIVACY_DATA_MATRIX.md`. Die Auswahl muss vor der
Einreichung in App Store Connect anhand des dann eingereichten Builds erneut
kontrolliert werden.

## Tracking

- Werden Daten fuer Tracking verwendet? **Nein**
- Werbung oder Drittanbieter-Werbenetzwerke? **Nein**
- IDFA/ATT-Nutzung? **Nein**

## Voraussichtlich anzugebende Datenkategorien

### Kontaktinformationen

- Name
- E-Mail-Adresse
- Telefonnummer, nur bei optionalem MFA beziehungsweise bewusster Angabe
- Sonstige Kontaktinformationen, soweit Nutzer sie aktiv hinterlegen

Zwecke: App-Funktion, Kontoverwaltung, Kommunikation und Sicherheit. Mit der
Identitaet verknuepft; nicht fuer Tracking.

### Standort

- Genauer Standort bei aktiv genutzten Standortfunktionen
- Gegebenenfalls daraus abgeleitete ungefaehre Region

Zwecke: App-Funktion und Sicherheit. Optional, mit der Identitaet oder dem
geteilten Inhalt verknuepft; nicht fuer Tracking.

### Benutzerinhalte

- Fotos und Videos
- Audio-/Sprachnachrichten
- E-Mails oder Textnachrichten innerhalb von Chats
- Beitraege, Storys, Kommentare, Antworten und Meldungen
- Support-Inhalte
- Sonstige Benutzerinhalte, insbesondere Fahrzeug-, Kennzeichen- und
  Verifizierungsdaten

Zwecke: App-Funktion, Nutzerkommunikation, Support und Sicherheit. Mit der
Identitaet verknuepft; nicht fuer Tracking.

### Kennungen

- Benutzer-ID
- Technische Geraete-/App-Kennung, insbesondere FCM-Token und
  App-Check-Attestierung

Zwecke: App-Funktion, Kontoverwaltung, Push, Sicherheit und
Betrugspraevention. Mit dem Konto beziehungsweise Geraet verknuepft; nicht fuer
Tracking.

### Nutzungsdaten

- Produktinteraktion wie Folgen, Likes, Kommentare, Kontaktanfragen,
  Sichtbarkeiten und Einstellungen
- Such- beziehungsweise Anfragevorgaenge, soweit fuer die Funktion und
  Missbrauchspraevention gespeichert

Zwecke: App-Funktion und Sicherheit. Mit der Identitaet verknuepft; nicht fuer
Tracking.

### Sensible Informationen

- Ausweis- und Fahrzeugdokumente ausschliesslich bei freiwilliger erweiterter
  Verifizierung

Zwecke: App-Funktion sowie Sicherheit/Betrugspraevention. Optional, mit der
Identitaet verknuepft; nicht fuer Tracking.

### Diagnostik und Sicherheitsdaten

- Konto-, Sitzungs-, MFA-, Blockier-, Melde- und Sicherheitsereignisse
- Keine Firebase-Analytics-, Crashlytics- oder Werbe-ID-Erfassung im aktuellen
  Code

Zwecke: Sicherheit, Betrugspraevention und Support. Nicht fuer Tracking.

## Loeschung und Sicherheit

- Kontoloeschung ist in der App und unter
  `https://plaqa.de/konto-loeschen/` beschrieben.
- Datenuebertragung erfolgt ueber HTTPS/TLS der verwendeten Firebase-/Apple-
  Dienste.
- Keine unabhaengige Sicherheitszertifizierung angeben.
- Gemeinsame Chattexte und erforderliche Sicherheits-/Rechtsdaten gemaess der
  technischen Loeschmatrix differenziert angeben; keine pauschale
  Sofortloeschung behaupten.
