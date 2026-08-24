# plaqa iOS-Datenschutz-Datenmatrix

Stand: 2026-08-24

Diese Matrix bildet den statisch geprueften Flutter-, Firebase- und iOS-Code
ab. Sie ist eine technische Grundlage fuer App Privacy in App Store Connect,
keine abschliessende Rechtsberatung. Es wird kein Tracking-SDK und kein
Werbe-SDK verwendet.

## Grundsaetze

- Daten werden mit dem plaqa-Konto verknuepft, wenn dies fuer die jeweilige
  Funktion erforderlich ist.
- Oeffentliche oder kontaktbezogene Sichtbarkeit richtet sich nach der vom
  Nutzer gewaehlten Profil-, Fahrzeug-, Beitrags-, Story- und
  Kontakteinstellung.
- Firebase/Google Cloud und Apple verarbeiten technische Daten als
  Infrastruktur- beziehungsweise Store-Anbieter. Das ist kein Verkauf von
  Daten und wird nicht als Werbe-Tracking verwendet.
- Standort, Kamera, Mikrofon, Fotomediathek, Dokumente und Push werden nur nach
  einer bewussten Aktion beziehungsweise Systemfreigabe verwendet.
- Die App ist fuer Personen ab 16 Jahren vorgesehen.

## Datenarten

| Apple-Datenkategorie | Konkrete Daten | Erhoben | Mit Identitaet verknuepft | Tracking | Erforderlich / optional | Zweck | Loeschung / Aufbewahrung |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Kontaktinformationen | E-Mail-Adresse | Ja | Ja | Nein | Erforderlich fuer E-Mail-Konten; bei Apple-Relay kann eine Relay-Adresse verwendet werden | Konto, Anmeldung, Sicherheit, Kommunikation | Mit dem Konto loeschbar; sicherheits- oder rechtlich erforderliche Nachweise koennen begrenzt aufbewahrt oder anonymisiert werden |
| Kontaktinformationen | Anzeigename, Vor- und Nachname | Ja, wenn angegeben | Ja | Nein | Anzeigename fuer soziale Funktionen; Klarnamensfelder optional | Profil, Kommunikation, Verifizierung | Mit Profil/Konto loeschbar |
| Kontaktinformationen | Telefonnummer | Nur bei SMS-MFA oder bewusster Angabe | Ja | Nein | Optional | Kontosicherheit, MFA | Mit MFA/Konto entfernbar; Sicherheitsereignisse koennen begrenzt aufbewahrt werden |
| Kontaktinformationen | Anschrift/Region | Region optional; Anschrift nur soweit in persoenlichen oder rechtlichen Daten vorgesehen | Ja | Nein | Optional | Profil, Fahrzeugbezug, rechtliche Ablaeufe | Mit Profil/Konto loeschbar, soweit keine Pflicht entgegensteht |
| Kontakte | Aktiv ausgewaehlter Kontaktname und Telefonnummer | Nur bei bewusster Chatfreigabe auf unterstuetzten Geraeten | Ja, als Nachrichteninhalt | Nein | Optional | Nutzer-zu-Nutzer-Kommunikation | Mit Nachricht/Chat nach dem echten Loeschprozess; bei gemeinsamen Chats kann Text pseudonymisiert erhalten bleiben |
| Standort | Exakte Koordinaten und Genauigkeit | Nur bei aktiver Standortfunktion | Ja | Nein | Optional | Kennzeichensuche, Fahrzeugstandort, Chat-/Story-Standort, Meldung | Suchstandorte werden zeitlich begrenzt als aktuell behandelt; geteilte Inhalte bis zur Loeschung des jeweiligen Inhalts/Kontos |
| Benutzerinhalte | Profilbild, Fahrzeugbilder, Fotos und Videos | Nur bei Upload/Aufnahme | Ja | Nein | Optional | Profil, Fahrzeuge, Beitraege, Storys, Chat, Meldung | Mit jeweiligem Inhalt oder Konto loeschbar; Medienverweise gemeinsamer Chats werden bei Kontoloeschung entfernt |
| Benutzerinhalte | Audio-/Sprachnachrichten | Nur bei bewusster Aufnahme | Ja | Nein | Optional | Chat-Kommunikation | Mit Nachricht/Chat/Konto nach dem echten Loeschprozess |
| Benutzerinhalte | Texte, Chats, Beitraege, Storys, Kommentare, Antworten, Likes | Ja bei Nutzung | Ja | Nein | Optional | Community und Kommunikation | Eigene Inhalte loeschbar; gemeinsame Chattexte koennen bei Kontoloeschung pseudonymisiert fuer Teilnehmer erhalten bleiben |
| Benutzerinhalte | Support-, Melde- und Sicherheitsinhalte | Nur bei Meldung/Support | Ja | Nein | Optional | Support, Moderation, Sicherheit, Rechtsdurchsetzung | Loeschung beziehungsweise zweckgebundene Aufbewahrung; keine feste Frist ohne externe Rechtspruefung behauptet |
| Benutzerinhalte | Fahrzeugdaten, Kennzeichen, Ausstattung, Umbauten, Timeline | Nur bei Anlage | Ja | Nein | Optional; fuer Fahrzeugfunktionen erforderlich | Fahrzeugprofil, Suche, Kontaktanfragen | Mit Fahrzeug oder Konto loeschbar; Sichtbarkeit nach Nutzereinstellung |
| Sensible Informationen | Ausweis- und Fahrzeugdokumente sowie Pruefstatus | Nur bei freiwilliger erweiterter Verifizierung | Ja | Nein | Optional | Identitaets-/Fahrzeugbestaetigung, Missbrauchsschutz | Dokumente nach Pruef- und Cleanup-Prozess; genaue rechtliche Restaufbewahrung extern pruefen |
| Kennungen | Firebase User-ID, externe Auth-Anbieter-ID | Ja | Ja | Nein | Erforderlich | Konto, Authentifizierung, Sicherheit | Mit Auth-Konto loeschbar; Sicherheitsnachweise gegebenenfalls pseudonymisiert |
| Kennungen | FCM-Registrierungstoken | Erst nach aktivierter Mitteilungsberechtigung | Ja | Nein | Optional | Push-Zustellung | Bei Tokenwechsel, Abmeldung und Kontoloeschung entfernt beziehungsweise ersetzt |
| Kennungen | App-Check-Attestierung und technische App-/Geraetesignale | Ja bei Firebase-Anfragen nach Aktivierung | Technisch dem App-/Anfragekontext zuordenbar | Nein | Fuer Schutz der Backendzugriffe | Sicherheit und Betrugspraevention | Nach Vorgaben des Infrastruktur-Anbieters; keine eigene Werbenutzung |
| Nutzungsdaten | Folgen, Follower, Kontaktanfragen, Sichtbarkeiten, Einstellungen | Ja bei Nutzung | Ja | Nein | Teilweise fuer gewaehlte Funktion erforderlich | App-Funktion, Personalisierung durch den Nutzer | Mit Konto beziehungsweise jeweiliger Einstellung loeschbar |
| Nutzungsdaten | Kennzeichen-Such- und Interaktionsvorgaenge | Ja, soweit fuer Anfrage, Sicherheit oder Missbrauchsschutz gespeichert | Ja | Nein | Fuer die ausgelöste Funktion | App-Funktion, Sicherheit | Entsprechend Funktions-/Sicherheitszweck; keine feste Frist erfunden |
| Diagnostik/Sicherheit | Sitzungen, Login-, MFA-, Blockier-, Moderations- und Loeschereignisse | Ja | Ja beziehungsweise pseudonymisiert | Nein | Fuer Sicherheit erforderlich | Kontosicherheit, Betrugspraevention, Support | Zweckgebunden; rechtliche Dauer extern pruefen |
| Diagnostik | Crashlytics/Analytics/Werbe-ID | Nein | Nein | Nein | Nicht verwendet | Nicht zutreffend | Nicht zutreffend |

## Drittanbieter-SDKs und Dienste

| Dienst / SDK | Technischer Zweck | Relevante Daten | Tracking |
| --- | --- | --- | --- |
| Firebase Authentication | Konto, E-Mail/Passwort, Google-/Apple-Anmeldung, MFA | Konto- und Sicherheitsdaten | Nein |
| Cloud Firestore | Profile, Fahrzeuge, soziale Inhalte, Einstellungen, Sicherheitsvorgaenge | App-Inhalte und Metadaten | Nein |
| Cloud Storage | Bilder, Videos, Audio und Dokumente | Nutzerdateien | Nein |
| Cloud Functions | Serverseitige App-, Sicherheits-, Verifizierungs- und Loeschablaeufe | Funktionsbezogene Daten | Nein |
| Firebase App Check | Schutz legitimer App-Anfragen | Attestierungs- und App-Signale | Nein |
| Firebase Cloud Messaging | Optionale Push-Zustellung | Registrierungstoken und Nachrichtenrouting | Nein |
| Google Sign-In | Optionale Kontoanmeldung | Anbieter-ID, E-Mail, Name, Profilbild | Nein |
| Sign in with Apple | Optionale datensparsame Anmeldung | Anbieter-ID, E-Mail/Relay-E-Mail, Name einmalig | Nein |
| Geolocator / Apple Core Location | Aktiver Standortzugriff | Koordinaten und Genauigkeit | Nein |
| Kamera, Image Picker, Photo Manager, File Picker | Aufnahme und bewusste Medien-/Dateiauswahl | Vom Nutzer gewaehlte Dateien | Nein |
| Share Plus / URL Launcher | System-Teilen und externe Links | Vom Nutzer zum Teilen ausgewaehlter Inhalt | Nein |

## Kontoloeschung

- In-App-Pfad: `Einstellungen > Konto und Sicherheit > Konto loeschen`.
- Oeffentliche Anleitung: `https://plaqa.de/konto-loeschen/`.
- Erneute Anmeldung und ausdrueckliche Bestaetigung schuetzen den Vorgang.
- Konto-, Profil-, Fahrzeug-, Beitrags-, Story-, Medien- und Einstellungsdaten
  werden nach dem implementierten Loeschprozess entfernt.
- Gemeinsame Chattexte koennen fuer den anderen Teilnehmer pseudonymisiert als
  Inhalt eines geloeschten Kontos erhalten bleiben; Medienverweise werden
  entfernt.
- Sicherheits-, Melde- oder Rechtsdaten koennen nur soweit erforderlich
  anonymisiert oder aufbewahrt werden. Eine konkrete Frist bleibt Teil der
  externen Rechtspruefung.

## Offene Freigabepunkte

- App-Privacy-Antworten vor Einreichung extern rechtlich abgleichen.
- APNs, Apple App Check, Apple-Anmeldung und Private Email Relay auf einem Mac
  beziehungsweise im aktivierten Apple-Developer-Konto abschliessen.
- Keine Aussage zu einer unabhaengigen Sicherheitszertifizierung machen.
