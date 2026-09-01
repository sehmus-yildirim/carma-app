# Legal-Pruefstellen-Inventar

Stand: 2026-09-01

Dieses Inventar dokumentiert die fachliche Bereinigung der sichtbaren
Rechts-Pruefmarker in plaqa. Es ersetzt keine Rechtsberatung. Aussagen wurden
nur dann konkretisiert, wenn sie durch den aktuellen App-Code, die vorhandene
Firebase-Konfiguration oder bereits freigegebene Betreiberangaben belegt sind.

## Ergebnis der Bestandsaufnahme

- In der In-App-Fassung wurden anfangs 93 sichtbare, eckig geklammerte
  Pruefmarker gefunden: 17 in den Nutzungsbedingungen, 63 in der
  Datenschutzerklaerung und 13 in den Community-Richtlinien.
- Zusaetzlich enthielt die oeffentliche Nutzungsbedingungen-Seite einen
  sichtbaren Hinweis auf eine noch erforderliche rechtliche Endfassung.
- Ein weiterer sichtbarer Entwicklungshinweis zu noch nicht individuell
  einschraenkbaren Anfragegruenden wurde sachlich auf den aktuellen Stand
  umgestellt.
- Alle sichtbaren Marker wurden entfernt oder durch belegbare, nutzerfreundliche
  Angaben ersetzt.
- Offene persoenliche oder rechtliche Entscheidungen bleiben bewusst in diesem
  internen Inventar und werden nicht als scheinbar fertige Zusagen angezeigt.
- Gepruefte und bereinigte sichtbare/provisorische Fundstellen: 95.
- Bewusst offene persoenliche oder externe Rechtspruefpunkte: 12.

## Bearbeitete Bereiche

Doppelte Marker derselben Rechtsfrage sind gruppiert; die Anzahl nennt die
tatsaechlichen Vorkommen.

| Anzahl | Datei/Fundstelle | Bisheriger Text oder Zustand | Rechtsbereich | Sichtbarkeit | Faktisch belegbar | Persoenliche Bestaetigung | Externe Rechtspruefung | Korrektur | Status |
| ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 17 | `lib/features/settings/presentation/settings_screen.dart`, In-App-Nutzungsbedingungen | Geklammerte Marker wie `RECHTLICH PRUEFEN` und fehlende Releaseentscheidungen | Vertrags-/Plattformregeln | Oeffentlich in der App | Teilweise | Teilweise | Ja | Nur technisch belegte Nutzung, Mindestalter, Moderation, Suche, Loesch- und Beschwerdewege konkretisiert | Behoben; Rechtspruefung offen |
| 63 | `lib/features/settings/presentation/settings_screen.dart`, In-App-Datenschutzerklaerung | Geklammerte Marker fuer Datenarten, Empfaenger, Fristen, Rechtsgrundlagen und Loeschung | Datenschutz | Oeffentlich in der App | Teilweise | Teilweise | Ja | Code, Berechtigungen, Firebase-Dienste, Dokumente und Loeschprozess abgeglichen; unbekannte Fristen nicht erfunden | Behoben; Rechtspruefung offen |
| 13 | `lib/features/settings/presentation/settings_screen.dart`, Community-Richtlinien | Geklammerte Marker zu Mindestalter, Moderation, Beschwerde und Kinderschutz | Plattform-/Kinderschutz | Oeffentlich in der App | Ja, soweit technisch | Nein | Ja | Melde-, Blockier-, Moderations- und Kinderschutzwege auf den echten App-Stand gebracht | Behoben; Rechtspruefung offen |
| 1 | `hosting/nutzungsbedingungen/index.html` | Sichtbarer Hinweis `Rechtliche Endfassung noch erforderlich` | Nutzungsbedingungen | Oeffentliche Website | Teilweise | Teilweise | Ja | Konsistente, sachliche Kurzfassung mit echten App-Pfaden und Kontakten erstellt | Behoben; Rechtspruefung offen |
| 1 | `lib/features/settings/presentation/settings_screen.dart`, Anfragegruende | Sichtbarer Entwicklungshinweis auf eine spaetere Einschraenkung | Datenschutz/Einstellungen | Oeffentlich in der App | Ja | Nein | Nein | Aktuellen Funktionsumfang ohne Release-Versprechen beschrieben | Behoben |
| intern | `docs/legal_release_inputs.md` | Veraltete Liste unbeantworteter Release-Fragen | Release-Dokumentation | Nur intern | Ja | Teilweise | Ja | Durch belegten Ist-Stand und klar getrennte Freigaben ersetzt | Behoben |
| intern | `RELEASE_CHECKLIST.md` | Veraltete Anzahl von 74 Markern und offener Sammelpunkt | Release-Dokumentation | Nur intern | Ja | Nein | Nein | Auf 93 In-App-Marker und dieses Inventar aktualisiert | Behoben |
| 3 | `hosting/datenschutz/index.html`, `hosting/community-richtlinien/index.html`, `hosting/kinderschutz/index.html` | Stand 21. August 2026 trotz aktueller Konsistenzpruefung | Datenschutz/Community/Kinderschutz | Oeffentliche Website | Ja | Nein | Nein | Dokumentstand auf 22. August 2026 vereinheitlicht | Behoben |

## Technisch belegte Kernaussagen

- Mindestalter: 16 Jahre; das Geburtsdatum wird in der App dynamisch geprueft.
- Anmeldung: E-Mail/Passwort, Google und optional SMS-MFA; Apple-Anmeldung ist
  derzeit nicht aktiv.
- Kennzeichensuche: maximal 5 km Suchradius und Standortaktualitaet von maximal
  60 Minuten auf der Serverseite.
- Storys: regulaere Sichtbarkeit fuer 24 Stunden mit vorbereitetem
  Bereinigungsprozess.
- Standort: keine Android-Berechtigung fuer Hintergrundstandort.
- Kontakte: Auswahl ueber den System-Picker, kein pauschaler Zugriff auf das
  gesamte Adressbuch.
- Push-Mitteilungen sind ueber Firebase Cloud Messaging aktiv eingebunden.
  Firebase Analytics, Crashlytics, Werbung, Tracking, In-App-Kaeufe und
  Zahlungs-SDKs sind aktuell nicht aktiv eingebunden.
- Dokumentenverifizierung: Identitaetsdokument und Fahrzeugschein; kein
  Fuehrerschein und kein Selfie. Die geplante Dokumentbereinigung nach 30 Tagen
  muss vor Live-Freigabe deployt und getestet werden.
- Kontoloeschung: Auth-Konto und nutzerbezogene private Daten werden entfernt;
  gemeinsam genutzte Chat- und Sicherheitskontexte koennen fuer andere
  Beteiligte pseudonymisiert bestehen bleiben.
- Datenexport: Ein geschuetzter Exportauftrag kann angefordert werden; die
  vollstaendige automatisierte Auslieferung ist noch nicht umgesetzt.

## Offene persoenliche Bestaetigungen

Persoenliche Angaben bestaetigt am 1. September 2026:

| Thema | Bestaetigter Ist-Stand | Verbleibende Entscheidung | Sichtbarer Platzhalter | Release-Blocker |
| --- | --- | --- | --- | --- |
| Anschrift | `Bremer Strasse 254e, 21077 Hamburg` wurde aktuell bestaetigt | Ladungsfaehigkeit unmittelbar vor Release erneut bestaetigen | Nein | Ja |
| Verbraucherstreitbeilegung | Das geplante Team bleibt zunaechst unter zehn Personen | Teilnahmebereitschaft und moegliche gesetzliche Verpflichtung rechtlich pruefen; nicht abschliessend entschieden | Nein | Ja |
| Datenschutzbeauftragter | Geplant ist ein kleines Team mit weniger als 20 Personen; die genaue Teamgroesse steht noch nicht fest | Erforderlichkeit insbesondere wegen einer moeglichen Datenschutz-Folgenabschaetzung extern pruefen; nicht abschliessend entschieden | Nein | Ja |
| Betreiberstatus | plaqa wird vorerst allein als Privatperson ohne bestaetigte Gesellschafts- oder Registerangaben betrieben | Status vor Release erneut kontrollieren und nur tatsaechlich vorhandene Rechtsform-, Register- oder Steuerangaben ergaenzen | Nein | Bei Aenderung des Status |

Fuer Datenschutzbeauftragten und Verbraucherstreitbeilegung gilt ausdruecklich:
**Nicht abschliessend entschieden, externe Rechtspruefung erforderlich.**

## Extern rechtlich zu pruefen

1. Anbieterkennzeichnung nach DDG, insbesondere bei Gruendung oder Aenderung
   (https://www.gesetze-im-internet.de/ddg/__5.html).
2. AGB-Klauseln zu Haftung, Sperrung, Kuendigung, Aenderungen und Gerichtsstand.
3. Rechtsgrundlagen und Verhaeltnismaessigkeit vollstaendiger Identitaets- und
   Fahrzeugdokumentkopien, einschliesslich Schwaerzungs- und Pruefkonzept
   (DSGVO: https://eur-lex.europa.eu/eli/reg/2016/679/oj).
4. Feste Aufbewahrungs- und Loeschfristen fuer Chats, Kontaktanfragen, Support,
   Sicherheitsereignisse, Meldungen und Backups (insbesondere DSGVO Artikel 5,
   13 und 17: https://eur-lex.europa.eu/eli/reg/2016/679/oj).
5. Einordnung der Plattform und Pflichten nach DSA, insbesondere interne
   Beschwerden, Behoerdenmeldungen und aussergerichtliche Streitbeilegung
   (DSA: https://eur-lex.europa.eu/eli/reg/2022/2065/oj).
6. Auftragsverarbeitungsvertraege, internationale Datentransfers und
   Risikobewertung fuer Google/Firebase sowie weitere Dienstleister
   (https://firebase.google.com/support/privacy).
7. Vollstaendige technische und organisatorische Massnahmen sowie internes
   Verzeichnis der Verarbeitungstaetigkeiten (BfDI DSGVO/BDSG-Information:
   https://www.bfdi.bund.de/SharedDocs/Downloads/DE/Broschueren/INFO1.pdf).
8. Marken- und Namenspruefung fuer `plaqa` (DPMAregister:
   https://register.dpma.de/DPMAregister/Uebersicht).

## Release-Regeln

- Keine offenen internen Pruefnotizen oder eckig geklammerten Marker in der
  produktiven App oder auf oeffentlichen Seiten anzeigen.
- Fachlich bereinigte Texte nicht mit einer abgeschlossenen anwaltlichen
  Pruefung gleichsetzen.
- Rechtliche Aenderungen immer zwischen App, Hosting-Seiten und Play Console
  abgleichen.
- Dokumentenverifizierung erst freigeben, wenn die serverseitige Bereinigung
  deployed und live verifiziert wurde.

## Offizielle Referenzen

- DSGVO bei EUR-Lex: https://eur-lex.europa.eu/eli/reg/2016/679/oj
- BfDI, DSGVO/BDSG-Information:
  https://www.bfdi.bund.de/SharedDocs/Downloads/DE/Broschueren/INFO1.pdf
- Digital Services Act bei EUR-Lex:
  https://eur-lex.europa.eu/eli/reg/2022/2065/oj
- DDG Paragraph 5: https://www.gesetze-im-internet.de/ddg/__5.html
- Firebase Datenschutz und Sicherheit: https://firebase.google.com/support/privacy
- Firebase Projektstandorte: https://firebase.google.com/docs/projects/locations
- Google Play User Data Policy:
  https://support.google.com/googleplay/android-developer/answer/10144311
- Google Play Anforderungen zur Kontoloeschung:
  https://support.google.com/googleplay/android-developer/answer/13327111
