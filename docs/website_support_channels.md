# Website-Supportkanaele

Stand: 25. August 2026

## Entscheidung

plaqa verwendet fuer die oeffentlichen Kontaktwege ein Hybridmodell:

- Support, Datenschutz, Partnerschaften und Meldestelle erhalten jeweils ein
  eigenes Webformular.
- Die jeweils zustaendige E-Mail-Adresse bleibt sichtbar und als Fallback
  direkt erreichbar.
- Die Formulare benoetigen keine Anmeldung und erlauben keine Anhaenge.
- Eine zentrale HTTPS-Function validiert und versendet alle Formulare. Der
  Browser darf weder Empfaenger noch SMTP-Daten vorgeben.
- Die erste Version speichert keine vollstaendigen Nachrichten, E-Mail-Adressen
  oder IP-Adressen in Firestore. Das zustaendige Postfach bleibt das
  Bearbeitungssystem.

Diese Datei beschreibt die verbindliche technische Richtung. Backend und die
vier sichtbaren Formulare sind lokal implementiert und getestet, aber nicht
deployt. Auf der oeffentlichen Website bleiben dadurch weiterhin nur die
bisherigen, bereits veroeffentlichten Kontaktwege aktiv.

## Aktueller Zustand

| Bereich | Oeffentliche Seite | Aktueller Versand | Bereits vorhandener App-Fluss | Automatische Antwort |
| --- | --- | --- | --- | --- |
| Support | `/support/` | Lokales Webformular; sichtbarer `mailto:support@plaqa.de`-Fallback | Angemeldete Nutzer schreiben private Dokumente unter `users/{uid}/support_requests/{requestId}`. | `processSupportMailboxAutoReplies` ist live und antwortet auf direkte externe E-Mails. |
| Datenschutz | `/datenschutz/` und `/konto-loeschen/` | Lokales Webformular; sichtbarer `mailto:privacy@plaqa.de`-Fallback | Datenexport und Kontoloeschung bleiben getrennte, angemeldete App-Ablaufe. | `processPrivacyMailboxAutoReplies` ist live und antwortet auf direkte externe E-Mails. |
| Partnerschaften | `/partner/` | Lokales Webformular; sichtbarer `mailto:partners@plaqa.de`-Fallback | Kein App-Datenmodell. | `processPartnersMailboxAutoReplies` ist live und antwortet auf direkte externe E-Mails. |
| Meldestelle | `/meldestelle/` | Lokales Webformular; sichtbarer `mailto:support@plaqa.de`-Fallback | Fahrzeughinweise und In-App-Meldungen sind angemeldete, getrennt abgesicherte Fluesse. | Direkte E-Mails werden durch den Support-Autoresponder bestaetigt. |

Der Live-Abgleich bestaetigt die drei Postfach-Scheduler in `europe-west3` als
aktive Node.js-22-Functions. `submitWebsiteContact` ist lokal exportiert, aber
nicht veroeffentlicht. Die vier lokalen Seiten binden die gemeinsame
Formularoberflaeche ein, aktivieren den Online-Versand aber ausschliesslich auf
`localhost` beziehungsweise `127.0.0.1`. Auf `plaqa.de` wird kein lokaler oder
unveroeffentlichter Endpunkt als funktionsfaehig dargestellt.

## Zustaendigkeiten

| Kanal | Empfaenger | Zweck |
| --- | --- | --- |
| `support` | `support@plaqa.de` | Technische Probleme, Kontohilfe und allgemeine Produktunterstuetzung |
| `privacy` | `privacy@plaqa.de` | Datenschutz- und Betroffenenanfragen; keine unaufgeforderten Nachweise |
| `partners` | `partners@plaqa.de` | Kooperationen und geschaeftliche Partnerschaften |
| `report` | `support@plaqa.de` | Meldungen zu Inhalten, Profilen oder Verhalten; keine Notfallstelle |

Der Empfaenger wird ausschliesslich serverseitig anhand des erlaubten Kanals
bestimmt. Ein vom Browser uebermitteltes Empfaengerfeld wird nicht akzeptiert.

## Formularvertrag

### Gemeinsame Regeln

- Request-Format: ausschliesslich `application/json`.
- Maximale Gesamtgroesse: 16 KiB.
- Freitext wird getrimmt und bei Zeilenenden vereinheitlicht, aber nicht
  inhaltlich umgeschrieben.
- E-Mail-Adressen werden getrimmt, kleingeschrieben und auf maximal 254 Zeichen
  begrenzt. Zeilenumbrueche und Steuerzeichen sind unzulaessig.
- Kategorien und Anfragearten stammen aus serverseitigen Allowlists.
- Alle HTML-Ausgaben werden kontextgerecht maskiert.
- Es werden keine Anhaenge, Passwoerter, Anmeldecodes, Ausweise,
  Fahrzeugnachweise oder Verifizierungsdokumente angenommen.
- Ein leeres Honeypot-Feld und ein plausibler Formular-Startzeitpunkt gehoeren
  zu jeder Anfrage. Beide Signale ersetzen kein serverseitiges Rate Limit.

### Support

| Feld | Pflicht | Regel |
| --- | --- | --- |
| Kategorie | Ja | Server-Allowlist, maximal 60 Zeichen |
| E-Mail-Adresse | Ja | Gueltige Adresse, maximal 254 Zeichen |
| Betreff | Ja | 5 bis 120 Zeichen |
| Nachricht | Ja | 20 bis 5.000 Zeichen |
| App-Version | Nein | Maximal 40 Zeichen |
| Geraet/Plattform | Nein | Maximal 120 Zeichen |

Das Formular fragt niemals nach Passwort, Anmeldecode oder Dokumenten.

### Datenschutz

| Feld | Pflicht | Regel |
| --- | --- | --- |
| Anfrageart | Ja | Server-Allowlist, maximal 60 Zeichen |
| E-Mail-Adresse | Ja | Gueltige Adresse, maximal 254 Zeichen |
| Nachricht | Ja | 20 bis 5.000 Zeichen |

Die Seite verweist fuer die Kontoloeschung weiterhin auf den bestehenden
offiziellen App-Ablauf und `/konto-loeschen/`. Identitaetsnachweise werden nicht
ueber das oeffentliche Formular angefordert oder hochgeladen.

### Partnerschaften

| Feld | Pflicht | Regel |
| --- | --- | --- |
| Name | Ja | 2 bis 100 Zeichen |
| Unternehmen/Organisation | Nein | Maximal 160 Zeichen |
| E-Mail-Adresse | Ja | Gueltige Adresse, maximal 254 Zeichen |
| Art der Partnerschaft | Ja | Server-Allowlist, maximal 60 Zeichen |
| Nachricht | Ja | 20 bis 5.000 Zeichen |

### Meldestelle

| Feld | Pflicht | Regel |
| --- | --- | --- |
| Meldekategorie | Ja | Server-Allowlist, maximal 60 Zeichen |
| Inhalt-/Profilbezug | Nein | Maximal 300 Zeichen |
| Beschreibung | Ja | 20 bis 5.000 Zeichen |
| Kontaktadresse | Nein | Gueltige E-Mail-Adresse, maximal 254 Zeichen |

Ohne Kontaktadresse wird nur eine Bestaetigung auf der Seite angezeigt. Die
Seite weist gut sichtbar darauf hin, dass akute Gefahren an Polizei,
Rettungsdienst oder andere zustaendige Stellen gemeldet werden muessen.
Eingereichte Meldungen sind niemals oeffentlich sichtbar.

## Technische Verarbeitung

### Lokal implementierter Endpunkt

Alle vier lokalen Formulare verwenden dieselbe lokal implementierte
v2-HTTPS-Function:

`submitWebsiteContact`

Der Body enthaelt einen der festen Kanaele `support`, `privacy`, `partners`
oder `report`. Die Function teilt die Verarbeitung intern in vier Handler auf,
verwendet aber eine gemeinsame Validierungs-, Rate-Limit- und Mail-Schicht.
Damit bleiben Sicherheitsregeln und Fehlermeldungen konsistent, ohne vier
oeffentliche Implementierungen zu duplizieren.

Der Browser schreibt niemals direkt in Firestore. Die bestehenden privaten
App-Pfade `support_requests`, `data_rights_requests` und `reports` werden nicht
fuer anonyme Website-Anfragen wiederverwendet.

Die Implementierung liegt in `functions/website_contact.js`, wird in
`functions/index.js` exportiert und verwendet ein separates HMAC-Secret
`PLAQA_WEBSITE_CONTACT_RATE_LIMIT_KEY`. Dieses Secret ist lokal nur als
Abhaengigkeit definiert und muss vor einem spaeteren Deploy kontrolliert in
Secret Manager angelegt werden.

### Zustellung

1. Die Function validiert und normalisiert die Anfrage.
2. Eine interne Nachricht wird von `no-reply@plaqa.de` an das fest verdrahtete
   Zielpostfach geschickt. Falls eine Kontaktadresse vorhanden ist, wird sie
   ausschliesslich als `Reply-To` gesetzt.
3. Bei Support, Datenschutz und Partnerschaften erhaelt der Absender eine
   gebrandete Bestaetigung von `no-reply@plaqa.de`. `Reply-To` zeigt auf das
   zustaendige Postfach.
4. Bei einer Meldung ohne Kontaktadresse wird keine E-Mail-Bestaetigung
   versendet.
5. SMTP-Zugangsdaten stammen ausschliesslich aus Secret Manager. Fuer den
   Formularversand wird das vorhandene No-Reply-Secret verwendet.

### Schutz vor doppelten Antworten

Die interne Weiterleitung kommt von `no-reply@plaqa.de`. Die vorhandenen
Postfach-Scheduler ignorieren Absender der Domain `plaqa.de` und weitere
automatische Nachrichten. Dadurch loest die interne Formularnachricht keine
zweite Postfach-Antwort aus.

- Webformular: genau eine Formularbestaetigung von `no-reply@plaqa.de`.
- Direkte externe E-Mail: genau eine vorhandene Postfach-Antwort vom jeweiligen
  Postfach.
- Deduplizierung: gleicher Kanal und gleicher normalisierter Inhalt werden in
  einem kurzen Zeitfenster nur einmal zugestellt.
- Mail-Header enthalten `Auto-Submitted`, `Precedence` und
  `X-Auto-Response-Suppress`, damit keine Antwortschleifen entstehen.

## Speicherstrategie

In Version 1 werden vollstaendige Formulardaten nur an das zustaendige Postfach
uebertragen. Es entsteht keine zweite Inhaltskopie in Firestore.

Firestore darf ausschliesslich minimale technische Metadaten enthalten:

- zufaellige Anfrage-ID und Kanal,
- HMAC-basierter IP-Hash und, falls vorhanden, E-Mail-Hash,
- Zeitstempel, Rate-Limit-Zaehler und Deduplizierungsfingerabdruck,
- Versandstatus und technische Fehlerkategorie ohne Nachrichteninhalt.

Roh-IP, E-Mail-Adresse, Name, Betreff und Nachricht werden weder in diesen
Metadaten noch in Logs gespeichert. Lokal werden dafuer ausschliesslich die
serverinternen Sammlungen `_system_website_contact_rate_limits`,
`_system_website_contact_duplicates` und
`_system_website_contact_submissions` verwendet. Der HMAC-Schluessel wird als
separates Secret erwartet. Die Implementierung setzt TTL-Felder mit einer
technischen Vorschlagsdauer von 48 Stunden; diese Dauer ist weder live noch
rechtlich freigegeben. Eine Firestore-TTL-Policy darf erst nach dieser
Freigabe eingerichtet werden.

Falls fuer die Meldestelle spaeter eine nachvollziehbare Fallbearbeitung
rechtlich erforderlich ist, erhaelt sie ein separates, nicht oeffentlich
lesbares Fallmodell mit eigener Zugriffs-, Loesch- und Aufbewahrungspruefung.
Diese Entscheidung wird nicht durch das erste Formular vorweggenommen.

## Sicherheitskonzept

- Serverseitige Feldtypen, Pflichtfelder, Laengen und Allowlists werden vor
  jeder weiteren Verarbeitung geprueft.
- CR/LF in E-Mail-, Betreff- und Headerwerten wird abgelehnt, um Header
  Injection zu verhindern.
- Benutzereingaben werden nie als unmaskiertes HTML gerendert.
- Produktions-CORS erlaubt nur `https://plaqa.de`. Fuer lokale Tests sind
  ausschliesslich `http://localhost:5000` und `http://127.0.0.1:5000`
  freigegeben; Wildcards sind unzulaessig.
- Rate Limits gelten sowohl fuer den HMAC-IP-Hash als auch fuer den
  HMAC-E-Mail-Hash. Lokal gelten pro IP maximal 8 Anfragen in 15 Minuten und
  30 pro Tag sowie pro Kontaktadresse maximal 4 Anfragen in 15 Minuten und
  12 pro Tag. Identische normalisierte Anfragen werden 10 Minuten lang
  dedupliziert. Positive und negative Tests belegen diese Grenzen.
- Honeypot, Mindest-Ausfuellzeit, Deduplizierung und generische Antworten
  erschweren automatisierten Spam, ohne interne Erkennungsdetails offenzulegen.
- App Check oder reCAPTCHA Enterprise wird als zusaetzliche Schutzschicht
  vorbereitet, aber weder kostenpflichtig aktiviert noch erzwungen, bevor
  Kosten, Datenschutztext und Fehlerrisiko gesondert freigegeben sind.
- Erfolgs- und Fehlerantworten legen weder SMTP-, Firebase-, Secret-Manager-
  noch Serverdetails offen.
- Logs enthalten nur Anfrage-ID, Kanal, Ergebnis, Dauer und allgemeine
  Fehlerkategorie. Personenbezogene Formulardaten werden nicht protokolliert.
- Secrets stehen niemals im Browsercode, Repository, Build-Artefakt oder Log.

## Gemeinsame Formularoberflaeche

Die wiederverwendbare Browserlogik liegt in `hosting/contact-form.js`; das
gemeinsame responsive Formulardesign liegt in `hosting/contact-form.css`.
Eingebunden sind beide Dateien auf `/support/`, `/datenschutz/`, `/partner/`
und `/meldestelle/`. Jede Seite uebergibt nur ihren festen Kanal und ihre
kanalspezifischen Felder. Empfaengeradressen, SMTP-Zugangsdaten und Secrets
sind nicht im Browsermodul enthalten.

Die Browserlogik spiegelt die serverseitigen Allowlists und Laengengrenzen,
normalisiert aber keine Rechte oder Empfaenger. Sie bietet Zeichenzaehler,
Inline-Fehler, Fokus auf das erste fehlerhafte Feld, einen gesperrten
Ladezustand, sichere Fehlertexte, Wiederholung sowie einen Erfolgszustand mit
neutraler Anfrage-ID. Formularinhalte werden weder in Local Storage noch in
Session Storage gespeichert und nicht protokolliert.

## UX-Vertrag

Jede Formularseite benoetigt:

- dauerhaft sichtbare Feldbeschriftungen und eindeutige Pflichtfeldhinweise,
- passende Eingabetypen und mobile Tastaturen,
- Inline-Validierung mit deutscher, handlungsorientierter Meldung,
- einen Ladezustand mit deaktivierter Mehrfachuebermittlung,
- einen Erfolgszustand mit neutraler Anfrage-ID,
- einen generischen Fehlerzustand mit sicherer Wiederholungsmoeglichkeit,
- einen verstaendlichen Rate-Limit-Hinweis ohne technische Interna,
- einen Datenschutzkurztext vor dem Absenden,
- eine sichtbare Fallback-Adresse als `mailto`-Link,
- Fokussteuerung, `aria-live` fuer Statusmeldungen und vollstaendige
  Tastaturbedienbarkeit,
- einspaltige, ueberlauffreie mobile Darstellung.

Die Meldestelle benoetigt zusaetzlich den permanenten Notfallhinweis. Die
Datenschutzseite benoetigt den permanenten Verweis auf den offiziellen
Kontoloeschungsablauf.

## Datenschutz und offene Rechtsfragen

Die bestehende Datenschutzerklaerung beschreibt Support-, Datenrechts-,
Melde- sowie technische Sicherheitsdaten bereits grundsaetzlich. Vor dem
oeffentlichen Start der Formulare ist dennoch zu pruefen und gegebenenfalls
fachlich zu ergaenzen:

- konkrete Verarbeitung oeffentlicher Website-Formulare,
- E-Mail-Zustellung und Postfach als Bearbeitungssystem,
- pseudonymisierte Rate-Limit- und Deduplizierungsmetadaten,
- freigegebene Aufbewahrung und Loeschung dieser Metadaten,
- Identitaetspruefung bei Betroffenenanfragen,
- DSA-Einordnung, Beschwerdeweg und Nachweispflichten der Meldestelle,
- getrennte Behandlung von Kinderschutzmeldungen,
- Zustaendigkeit fuer Behoerden- und Notfallmeldungen.

Eine externe rechtliche Endpruefung bleibt erforderlich. Diese technische
Entscheidung ersetzt keine Rechtsberatung.

## Implementierungsstand und naechste Reihenfolge

1. [x] `submitWebsiteContact` mit gemeinsamer Schema-Validierung, harter
   Empfaengerzuordnung, sicherem Mail-Rendering und serverseitigem Rate Limit
   lokal implementiert.
2. [x] Unit-Tests fuer alle Kanaele, Header Injection, HTML-Maskierung,
   Laengen, Honeypot, Deduplizierung, Rate Limits, CORS und Log-Minimierung
   ergaenzt. Alle Functions-Tests bestehen lokal.
3. [x] Firestore-Emulatortest ergaenzt: Die drei internen Metadaten-Sammlungen
   sind weder anonym noch authentifiziert clientseitig les- oder schreibbar.
4. [ ] HMAC-Secret anlegen und die 48-Stunden-Vorschlagsdauer rechtlich sowie
   betrieblich freigeben; erst danach gegebenenfalls eine TTL-Policy anlegen.
5. [x] Die vier Formulare mit gemeinsamer UI-Architektur optisch implementiert
   und lokal gegen einen Testadapter geprueft. Zwoelf UI-/Vertragstests
   bestehen. Browser-QA auf 1280 x 800 und 390 x 844 bestaetigt vollstaendige
   Labels, eindeutige IDs, Fokussteuerung, Fehler- und Erfolgszustaende,
   sichtbare Mail-Fallbacks, fehlenden Horizontal-Overflow und eine fehlerfreie
   Browserkonsole auf allen vier Seiten.
6. [ ] Datenschutztext und Meldestellenprozess extern pruefen sowie einen
   etwaigen CAPTCHA-/App-Check-Einsatz freigeben.
7. [ ] Erst nach separater Zustimmung Function und Hosting gezielt deployen.
   Danach je Kanal Zustellung, Bestaetigung, Deduplizierung und Fehlerfaelle
   mit freigegebenen Testadressen pruefen.

## Abschlusskriterien fuer die spaetere Implementierung

- Alle vier Formulare funktionieren ohne Anmeldung und ohne Anhaenge.
- Browsercode enthaelt weder Empfaengerlogik noch Secrets.
- Direkte E-Mails und Webformulare erzeugen jeweils genau eine Bestaetigung.
- Keine personenbezogenen Formularinhalte erscheinen in Firestore-Metadaten
  oder Logs.
- Positive und negative Backend-, Rules- und UI-Tests bestehen.
- Datenschutz-, Aufbewahrungs- und Meldestellenfragen sind freigegeben.
- Ein gezielter Deploy- und Rollback-Plan liegt vor.
- Die oeffentliche Website bleibt bis zur ausdruecklichen Freigabe unveraendert.
