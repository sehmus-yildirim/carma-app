# plaqa Kinderschutzprozess

Stand: 21. August 2026

Dieses interne Dokument beschreibt den nachweisbaren technischen Stand und die
vor einer Veröffentlichung noch verbindlich festzulegenden Arbeitsschritte.
Es ist keine Rechtsberatung und wird nicht öffentlich verlinkt.

## 1. Geltungsbereich

Der Prozess gilt für Hinweise auf sexuellen Missbrauch oder sexuelle
Ausbeutung von Kindern und Jugendlichen (CSAE), entsprechende Darstellungen
(CSAM), Grooming, sexuelle Erpressung, sexuelle Kontaktanbahnung sowie andere
akute Gefährdungen Minderjähriger in Profilen, Beiträgen, Storys, Kommentaren,
Chats und Medien.

plaqa ist ab 16 Jahren vorgesehen. Die Altersgrenze ersetzt diesen Prozess
nicht.

## 2. Vorhandene Meldewege

- Chats können durch Teilnehmende gemeldet und blockiert werden.
- Kommentare und Antworten können durch berechtigte Nutzer gemeldet werden.
- Sicherheitsbedenken zu Profilen, Beiträgen, Storys oder sonstigen Bereichen
  können über `Einstellungen > Hilfe & Rechtliches > Support >
  Sicherheitsproblem melden` beschrieben werden.
- `support@plaqa.de` ist der allgemeine Sicherheitskontakt. Mutmaßlich
  rechtswidrige Dateien dürfen nicht über normale E-Mails angefordert oder
  weitergeleitet werden.

Meldungen werden in zugriffsgeschützten Firestore-Dokumenten gespeichert. Die
App erlaubt dem meldenden Nutzer keine nachträgliche Bearbeitung der Meldung.
Andere normale Nutzer erhalten keinen Zugriff auf den internen Meldungsinhalt.

## 3. Eingang und Priorisierung

1. Die zuständige Person prüft nur Metadaten und die sachliche Beschreibung,
   die für eine erste Einordnung erforderlich sind.
2. Hinweise auf eine aktuelle Gefahr für Leib oder Leben werden als akut
   priorisiert. Nutzer werden darauf hingewiesen, den örtlichen Notruf oder die
   Polizei unmittelbar zu kontaktieren; plaqa ist kein Notrufdienst.
3. Hinweise auf mögliche CSAE- oder CSAM-Inhalte werden getrennt von normalen
   Supportanfragen behandelt und nicht in gewöhnliche Tickets, E-Mails oder
   Chatverläufe kopiert.
4. Der Zugriff wird auf ausdrücklich zuständige Personen begrenzt.

## 4. Prüfung und Maßnahmen

Eine Entscheidung darf nur auf den verfügbaren Informationen und einer
dokumentierten Begründung beruhen. Je nach Ergebnis kommen folgende Maßnahmen
in Betracht:

- Meldung als unbegründet schließen;
- betroffenen Inhalt sperren oder entfernen;
- Kontakt- oder Kommunikationsfunktionen einschränken;
- Konto vorübergehend oder dauerhaft sperren;
- sicherheitsrelevante Metadaten nur im rechtlich zulässigen Umfang sichern;
- den Fall nach rechtlicher Prüfung an die zuständige Stelle eskalieren.

Jede Maßnahme wird mit Zeitpunkt, betroffenem Objekt, Begründung und
verantwortlicher Person dokumentiert. Illegale Medien werden nicht in normale
Arbeitsdokumente, E-Mails, Bildschirmfotos oder Logs übernommen.

## 5. Behörden und rechtliche Eskalation

Vor einer Play-Store-Selbstzertifizierung müssen schriftlich festgelegt werden:

- die für den Betreiberstandort zuständige Meldestelle oder Behörde;
- die Voraussetzungen für eine gesetzlich erforderliche Meldung;
- der sichere Übermittlungsweg;
- zulässige Sicherungs- und Löschfristen;
- die vertretungsberechtigte und geschulte Kontaktperson.

Bis diese Punkte rechtlich geprüft und organisatorisch eingerichtet sind, darf
nicht behauptet werden, dass ein automatischer oder vollständig operativer
Behördenmeldeprozess besteht.

## 6. Datenschutz und Zugriff

- Nur die für Sicherheit und Moderation zuständigen Personen dürfen Meldungen
  prüfen.
- Meldeinhalte dürfen nicht für Werbung, Profilbildung oder öffentliche
  Statistiken verwendet werden.
- Namen, Kennzeichen, Standortdaten und Kontaktdaten werden nur verarbeitet,
  soweit sie für Prüfung, Schutzmaßnahmen oder gesetzliche Pflichten
  erforderlich sind.
- Aufbewahrungs- und Löschfristen werden vor Veröffentlichung rechtlich
  festgelegt. Bis dahin werden keine festen Fristen öffentlich zugesagt.
- Zugriffe und Maßnahmen müssen nachvollziehbar protokolliert werden, ohne den
  gemeldeten Inhalt in Logs zu kopieren.

## 7. Technischer Ist-Stand

Vorhanden:

- serverseitig geschützte Chatmeldungen;
- serverseitig geschützte Kommentar- und Antwortmeldungen;
- Chat-Blockierung mit Schreib- und Anhangssperre;
- zugriffsgeschützte Supportanfragen;
- vorbereitete Modelle für Verwarnung, Einschränkung und Sperrung;
- öffentliche Community-Richtlinien mit ausdrücklichem CSAE-/CSAM-Verbot.

Noch nicht vollständig vorhanden:

- vertrauenswürdige Moderationsoberfläche für alle Meldungsarten;
- verbindlicher Bereitschafts- und Vertretungsplan;
- bestätigter Behörden-Eskalationsprozess;
- technisch erzwungene Bearbeitungsfristen;
- zentraler Prüfverlauf für jede Meldungsart;
- Live-Nachweis, dass die aktuell lokalen Rules und der neue Sicherheitsmeldeweg
  veröffentlicht sind.

## 8. Freigabekriterien

Die Google-Play-Erklärung darf erst persönlich bestätigt werden, wenn:

1. die öffentliche Seite `https://plaqa.de/kinderschutz/` erreichbar ist;
2. der Sicherheitsmeldeweg mit veröffentlichten Firestore Rules funktioniert;
3. eine konkrete verantwortliche Person und ein überwachtetes Postfach
   benannt sind;
4. der Behörden-Eskalationsprozess rechtlich geprüft und praktisch ausführbar
   ist;
5. die verantwortliche Person die Google-Play-Angaben selbst geprüft hat.
