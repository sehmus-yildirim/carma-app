# Rechtlicher Release-Stand

Stand: 2026-09-01

Diese Datei fasst den fachlich belegten Stand der In-App-Rechtstexte und der
oeffentlichen plaqa-Seiten zusammen. Offene Punkte sind keine sichtbaren
Platzhalter mehr, sondern kontrollierte Release-Aufgaben. Eine externe
Rechtspruefung bleibt vor der Produktionsveroeffentlichung erforderlich.

Das vollstaendige Fundstellen- und Freigabeinventar steht in
`LEGAL_PLACEHOLDER_INVENTORY.md`.

## 1. Anbieter und Kontakte

Aktuell verwendet:

- Produktname: plaqa
- Website: https://plaqa.de
- Allgemeiner Kontakt: info@plaqa.de
- Support: support@plaqa.de
- Datenschutz: privacy@plaqa.de
- Automatischer Versand: no-reply@plaqa.de
- Partnerschaften: partners@plaqa.de
- Betreiber: Sehmus Yildirim, auftretend unter der Bezeichnung plaqa; keine
  nicht bestaetigte Rechtsform wird behauptet
- Betreiberstatus und Anschrift am 1. September 2026 bestaetigt: vorerst allein und ohne
  bestaetigte Gesellschafts-, Register- oder Umsatzsteuerangaben

Vor Release erneut bestaetigen:

- Erneute Bestaetigung der ladungsfaehigen Anschrift unmittelbar vor Release
- Rechtsform, Register- und Steuerangaben, falls sich der Betreiberstatus aendert
- Verpflichtung und Teilnahmebereitschaft zur Verbraucherstreitbeilegung; das
  geplante Team bleibt zunaechst unter zehn Personen
- Erforderlichkeit eines Datenschutzbeauftragten; geplant ist ein kleines Team
  mit weniger als 20 Personen, eine moegliche Datenschutz-Folgenabschaetzung
  muss dennoch extern bewertet werden

Fuer die beiden letzten Punkte gilt:
**Nicht abschliessend entschieden, externe Rechtspruefung erforderlich.**

## 2. Tatsaechliche Datenverarbeitung

Im Code und in der Konfiguration belegt:

- Firebase Authentication mit E-Mail/Passwort, Google und optional SMS-MFA
- Firestore fuer Konten, Profile, Fahrzeuge, Kennzeichen, soziale Inhalte,
  Einstellungen, Anfragen, Chats und Sicherheitsdaten
- Cloud Storage fuer Profilbilder, Beitraege, Storys, Chatmedien und
  Verifizierungsdokumente
- Cloud Functions fuer geschuetzte serverseitige Ablaeufe
- App Check ist im Flutter-Client technisch integriert: Release verwendet auf
  Android Play Integrity und auf Apple App Attest mit DeviceCheck-Fallback.
  Produktive Metriken und Erzwingung sind noch nicht abgenommen.
- Standort fuer Kennzeichensuche und standortbezogene App-Funktionen; keine
  Berechtigung fuer Hintergrundstandort
- Kamera, Mikrofon und Medienzugriff nur fuer vom Nutzer gestartete Funktionen
- Kontaktfreigabe ueber System-Picker statt vollstaendigem Adressbuchzugriff

Technisch eingebunden:

- Firebase Cloud Messaging / Push-Token-Verarbeitung; der Android-Live-Test
  wurde vorbereitet und ist im finalen Release-Build erneut zu bestaetigen
- Apple-Anmeldung ueber Firebase Authentication; iOS-Endabnahme bleibt offen

Derzeit nicht aktiv eingebunden:

- Firebase Analytics
- Firebase Crashlytics
- Werbung oder Tracking
- In-App-Kaeufe, Abonnements oder Zahlungs-SDKs

## 3. Verifizierung und Dokumente

Aktueller fachlicher Umfang:

- Identitaetsnachweis: Personalausweis, Reisepass oder Aufenthaltstitel
- Fahrzeugnachweis: Fahrzeugschein mit eindeutiger Fahrzeugzuordnung
- Kein Fuehrerschein und kein Selfie im aktuellen Prozess
- Einzelne beanstandete Nachweise koennen gezielt nachgereicht werden
- Dokumente sind nicht oeffentlich sichtbar
- Eine serverseitige Bereinigung nach 30 Tagen ist vorbereitet

Release-Bedingung:

- `cleanupProfileVerificationDocuments` deployen und live pruefen, bevor die
  Dokumentenverifizierung produktiv freigegeben wird
- Rechtsgrundlage, Schwaerzungsmoeglichkeiten und Verhaeltnismaessigkeit der
  Dokumentkopien extern pruefen lassen

## 4. Suche, Standort und Community

- Serverseitiger Suchradius: maximal 5 km
- Fuer die Suche akzeptierte Standortaktualitaet: maximal 60 Minuten
- Keine Nutzung der App fuer Notfaelle; Polizei, Feuerwehr und Rettungsdienste
  werden nicht ersetzt
- Mindestalter: 16 Jahre
- plaqa richtet sich nicht speziell an Kinder
- Melde-, Blockier-, Support- und Kinderschutzwege sind beschrieben
- Sexualisierte Ausbeutung, Gefaehrdung Minderjaehriger, Belaestigung,
  Falschmeldungen und rechtswidrige Inhalte sind untersagt

## 5. Speicherung und Loeschung

Technisch belegt:

- Storys laufen regulaer nach 24 Stunden ab; ein Bereinigungsprozess ist
  vorbereitet
- Verifizierungsdokumente sollen nach Abschluss der Pruefung serverseitig nach
  30 Tagen bereinigt werden
- Kontoloeschung entfernt das Auth-Konto sowie nutzerbezogene private Profil-,
  Fahrzeug-, Kennzeichen-, Medien-, Story-, Verifizierungs- und Einstellungsdaten
- Gemeinsame Chat- oder Sicherheitskontexte koennen fuer andere Beteiligte
  pseudonymisiert erhalten bleiben
- Nutzer koennen einen geschuetzten Datenexportauftrag anlegen; eine vollstaendig
  automatisierte Auslieferung ist noch nicht umgesetzt

Technisch festgelegt beziehungsweise dokumentiert:

- Storys und fahrzeugbezogene Kurzzeitmeldungen: 24 Stunden
- ausstehende Kontaktanfragen: 48 Stunden
- normale Supportvorgaenge: 365 Tage
- Kinderschutz-/Sicherheits-Supportvorgaenge: 730 Tage
- Sicherheitsaktivitaeten: 365 Tage
- Datenrechts- und Kontoloeschungsnachweise: drei Jahre
- Bearbeitungsprozess des Datenexports ist manuell dokumentiert; eine
  automatische Auslieferung wird nicht behauptet

Noch rechtlich und organisatorisch festzulegen:

- konkrete Fristen fuer aktive Chats, Moderationsbeweise, Backups und
  gesetzliche Sperrfaelle
- Dokumentierte Behandlung gesetzlicher Aufbewahrungspflichten und
  Beweissicherungsfaelle

Es werden keine nicht belegten festen Fristen in der App versprochen.

## 6. Firebase und internationale Verarbeitung

- Functions verwenden die Region `europe-west3`, soweit im Code so konfiguriert
- Nicht jeder Firebase-Dienst ist regional identisch; Firebase Authentication
  ist laut offizieller Firebase-Dokumentation ein global beziehungsweise in den
  USA verarbeiteter Dienst
- Google/Firebase ist als technischer Empfaenger beziehungsweise
  Auftragsverarbeiter zu beschreiben, nicht als Verkauf personenbezogener Daten
- Auftragsverarbeitung, Vertragspartei, internationale Transfers und eine
  erforderliche Risikobewertung muessen vor Release organisatorisch geprueft
  und dokumentiert sein

## 7. Rechtstexte und oeffentliche Seiten

Fachlich bereinigt:

- In-App-Nutzungsbedingungen
- In-App-Datenschutzerklaerung
- In-App-Community-Richtlinien
- In-App-Impressum und Kontaktangaben
- https://plaqa.de/datenschutz/
- https://plaqa.de/konto-loeschen/
- https://plaqa.de/kinderschutz/
- oeffentliche Nutzungsbedingungen im Hosting-Projekt

Vor Release extern pruefen:

- Anbieterkennzeichnung nach DDG
- AGB, insbesondere Haftung, Sperrung, Kuendigung und Gerichtsstand
- Datenschutzerklaerung, Rechtsgrundlagen, Betroffenenrechte und Fristen
- DSA-Einordnung, Moderation und Beschwerdeverfahren
- Marken- und Namensrechte

## 8. Play-Console-Abgleich

Die Play-Console-Angaben muessen bei jeder rechtlichen Aenderung erneut mit App
und Hosting abgeglichen werden:

- Datensicherheit und Datenarten
- Datenschutz- und Kontoloesch-URL
- Zielgruppe ab 16 Jahren
- nutzergenerierte Inhalte, Meldung und Moderation
- Kinderschutzstandard
- Verschluesselung bei der Uebertragung
- Testzugang und zugriffsbeschraenkte Funktionen

Keine rechtliche Endfreigabe aus dem technischen Pruefstatus ableiten.

## Offizielle Referenzen

- DDG Paragraph 5: https://www.gesetze-im-internet.de/ddg/__5.html
- Firebase Datenschutz und Sicherheit: https://firebase.google.com/support/privacy
- Firebase Projektstandorte: https://firebase.google.com/docs/projects/locations
- Google Play User Data Policy:
  https://support.google.com/googleplay/android-developer/answer/10144311
- Google Play Anforderungen zur Kontoloeschung:
  https://support.google.com/googleplay/android-developer/answer/13327111
