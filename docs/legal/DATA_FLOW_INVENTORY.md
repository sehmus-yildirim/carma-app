# Plaqa Datenfluss-Inventar

Stand: 1. September 2026  
Geltungsbereich: Android-App, vorbereitete iOS-App, Firebase-Backend und plaqa.de  
Verantwortlicher: Sehmus Yildirim, Bremer Strasse 254e, 21077 Hamburg

Dieses Inventar beschreibt den im Repository nachweisbaren technischen Stand. Es ist die Grundlage fuer Datenschutzinformation, Loeschkonzept, Google-Play-Angaben und die externe Rechtspruefung.

## 1. Systeme und technische Empfaenger

| System | Verarbeitete Daten | Zweck | Technische Lage |
|---|---|---|---|
| Firebase Authentication | E-Mail, Provider-ID, Login- und MFA-Metadaten | Konto, Anmeldung, Sitzungen, MFA | Firebase/Google; Auth-Dienste koennen global verarbeitet werden |
| Cloud Firestore | Profil, Fahrzeuge, Kennzeichen, Kontakte, Chats, Feed, Meldungen, Einstellungen, Einwilligungsnachweise | Kernfunktionen der App | Projekt `carma-a84e4`, Functions primaer `europe-west3` |
| Cloud Storage for Firebase | Profilbilder, Fahrzeugbilder, Chat-/Story-Medien, Meldebilder, Verifizierungsunterlagen | Medienfunktionen | Zugriff ueber Storage-Regeln und serverseitige Reservierungen |
| Cloud Functions / Cloud Scheduler | Limits, Suche, Meldungen, Moderation, Loeschung, Benachrichtigungen, Bereinigung | serverseitige Autorisierung und Wartung | Google Cloud/Firebase |
| Firebase Cloud Messaging | Push-Token, Zielkonto, Benachrichtigungsmetadaten | Push-Benachrichtigungen | Google/Firebase; Inhalt auf das Erforderliche begrenzen |
| Firebase App Check | App-/Gerate-Attestierungsdaten | Missbrauchsschutz | Google Play Integrity bzw. Apple App Attest/DeviceCheck |
| Google-Anmeldung | Google-Konto-ID, E-Mail, Anzeigename, Profilbild | alternative Anmeldung | Google Identity/Firebase Auth |
| Google Vertex AI / Gemini | vom Nutzer angeforderte Fahrzeugbeschreibung und notwendige Bilddaten | Fahrzeugbild-Generierung/-Bearbeitung | Google Cloud; keine Verifizierungsdokumente uebermitteln |
| IONOS Mail | Kontakt- und Support-E-Mails | Empfang und Versand von Supportnachrichten | IONOS; IMAP/SMTP in Functions |
| Google Play | App-, Kauf-/Installations-, Diagnose- und Testdaten nach Play-Konfiguration | Distribution, Integritaet, geschlossene Tests | Google Play Console |
| Lokales Endgeraet | Kamera-/Galeriebilder, temporaere OCR-Ergebnisse, lokale Einstellungen | Aufnahme, Zuschnitt und lokale Vorverarbeitung | Dokumentbilder sollen vor Abschluss nicht dauerhaft hochgeladen werden |

Es gibt im Repository keine Werbe-SDKs, keine Drittanbieter-Analytics und keinen Zahlungsdienst. Crash-/ANR-Daten koennen durch Google Play beziehungsweise die Plattform entstehen. Diese Aussage ist vor jedem Release anhand der finalen Abhaengigkeiten erneut zu pruefen.

## 2. Datenkategorien und Fluesse

### Konto und Sicherheit

- E-Mail-Adresse, Auth-Provider, UID, Anmelde- und MFA-Status gehen an Firebase Authentication.
- Push-Token werden nutzerbezogen gespeichert und bei Abmeldung, Tokenwechsel oder Kontoloeschung entfernt.
- Sicherheitsereignisse enthalten Ereignistyp, Zeitpunkt, Plattform und Status; keine Passwoerter, OTP-Codes, IP-Adressen oder Auth-Token.
- Einwilligungsnachweise enthalten Typ, Textversion, Zeitpunkt und Quelle (`registration` oder `renewal`).

### Profil, Fahrzeuge und Kennzeichen

- Private Profildaten liegen unter dem Nutzerkonto; oeffentliche Profildaten werden getrennt gespiegelt.
- Fahrzeug- und Kennzeichendaten werden nach Sichtbarkeitseinstellung privat, fuer Kontakte oder oeffentlich bereitgestellt.
- Fahrzeugbilder liegen in Storage. Generative Bildverarbeitung wird nur auf ausdrueckliche Nutzeraktion ausgeloest.
- Kennzeichensuchen werden serverseitig autorisiert, begrenzt und gegen Standort-/Missbrauchsregeln geprueft.

### Standort und Begegnungen

- Standort wird nur fuer die dafuer vorgesehenen Such-/Begegnungsfunktionen und nach Betriebssystemfreigabe verarbeitet.
- Standortdaten duerfen nicht als dauerhafte Bewegungsprofile oder fuer Werbung verwendet werden.
- Gespiegelte Fahrzeugbegegnungen werden bei Kontoloeschung auf beiden Seiten entfernt.

### Kontakt, Chat, Feed und Moderation

- Kontaktanfragen verbinden Konten erst nach dem vorgesehenen Zustimmungsablauf.
- Chattexte und Medien werden zwischen Teilnehmern verarbeitet; geteilte Chatdaten werden bei Kontoloeschung anonymisiert, soweit die andere Seite sie weiterhin benoetigt.
- Feed-Inhalte, Kommentare, Reaktionen und Meldungen koennen je nach Sichtbarkeit anderen Nutzern und Moderation zugaenglich sein.
- Blockierungen, Meldungen und Moderationsentscheidungen werden zur Durchsetzung der Regeln verarbeitet.

### Verifizierung

- Der Verifizierungsbereich ist technisch vorhanden, aber laut Betreiberentscheidung vorerst nicht releasefreigegeben.
- Kamera-/Galeriebilder und OCR-Ergebnisse duerfen nicht in Logs erscheinen.
- Hochgeladene Dokumente sind privat; serverseitige Verifizierungsunterlagen haben eigene Ablauf- und Bereinigungslogik.
- Vor Aktivierung sind Datenschutz-Folgenabschaetzung, Zweck-/Rechtsgrundlagenpruefung und echte End-to-End-Abnahme Pflicht.

### Support, Website und Betroffenenrechte

- App-Supportanfragen liegen privat unter dem Nutzerkonto und enthalten nur die eingegebenen Sachverhalte und optionale Kontakt-E-Mail.
- Website-Formulare speichern kurzlebige Rate-Limit-, Duplikat- und Zustellmetadaten; der Nachrichteninhalt wird an IONOS-Mailfaecher zugestellt.
- Exportanfragen werden als private, unveraenderliche Vorgangsdatensaetze angelegt. Die Auslieferung ist ein manueller Betreiberprozess und derzeit kein vollautomatisches Exportpaket.
- Kontoloeschung erfolgt serverseitig, entfernt eigene Daten und Medien, bereinigt Fremdreferenzen und pseudonymisiert zwingend erhaltene gemeinsame Inhalte.

## 3. Betrieblich offene Nachweise

Vor Produktivfreigabe sind noch extern beziehungsweise organisatorisch zu belegen:

- Rechtsform, gegebenenfalls Register, Umsatzsteuer-ID und gewerbliche Angaben.
- Auftragsverarbeitungsvertraege und aktuelle Unterauftragsverarbeiter von Google/Firebase/Google Cloud und IONOS.
- Drittlandtransfer- und Transfer-Impact-Pruefung, insbesondere fuer Auth-, Push- und KI-Dienste.
- Backup-Loeschzyklen und Wiederherstellungsfristen der eingesetzten Anbieter.
- Benannte Moderationsverantwortliche, Vertretung, Reaktionszeiten und Behoerdeneskalation.
- Rechtliche Bewertung von Kennzeichen-, Standort-, Dokument- und sozialen Daten sowie gegebenenfalls eine DSFA.

