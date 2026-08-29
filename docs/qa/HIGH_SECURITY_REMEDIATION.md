# plaqa High Security Remediation

Stand: 2026-08-29
Ausgangscommit: `67f7b28b3400a13aab6d806cad4c37484c4de7df`
Status: **5/5 HIGH-Befunde lokal behoben und regressionsgetestet**

## Behobene Befunde

| ID | Schutz | Technischer Nachweis |
|---|---|---|
| SEC-001 | Standortschutz bei Kennzeichensuchen | App Check, 20 Suchen pro Konto und 24 Stunden, 24-Stunden-Sperre je Konto/Kennzeichen, 8 Suchen pro Ziel und 24 Stunden sowie eine ungefaehr 3 km grosse Standortzelle statt exakter Distanz. |
| SEC-002 | Begrenzung kostenpflichtiger KI-Bilder | App Check, transaktionales Kontolimit von 6 Versuchen pro 24 Stunden und bestehendes Fahrzeuglimit von 3 Versuchen pro 24 Stunden; fehlgeschlagene kostenpflichtige Versuche werden nicht erstattet. |
| SEC-003 | Schutz vor unbegrenzten Storage-Uploads | Serverseitige Uploadreservierung mit festem Pfad, Eigentum, MIME-Typ und exakter Bytezahl; 100 Reservierungen und 1 GiB reservierte Bytes pro Konto/Tag sowie 2 GiB erfasster Live-Speicher pro Konto. Finalisierung, Loeschtracking und Bereinigung verwaister Reservierungen sind serverseitig abgesichert. |
| SEC-004 | Vollstaendige Kontoloeschung sozialer Daten | Likes, Reaktionen und Meldungen unter fremden Beitraegen werden geloescht; Kommentare und Antworten werden irreversibel anonymisiert und geleert. Fuenf Collection-Group-Indizes und deterministische Seiten mit hoechstens 200 Dokumenten machen die Verarbeitung gebuendelt, wiederholbar und nach einem Fehler fortsetzbar. |
| SEC-005 | Vollstaendige Loeschung gespiegelter Fahrzeugbegegnungen | Beide oeffentlichen Begegnungsspiegel werden aus den Teilnehmerdaten abgeleitet und vor dem Top-Level-Dokument geloescht. Wiederholte Ausfuehrung bleibt idempotent. |

## Upload-Schutzbereiche

Die Reservierung wird fuer Chatbilder, Dokumente, Sprachnachrichten, Videos,
Story-Medien, Meldungsanhange, Social-Post-Medien und Fahrzeuggalerien verwendet.
Deterministische Profilfoto- und Verifizierungsdateien bleiben durch feste
Dateinamen, Pfade und Dateianzahlen begrenzt.

Eine reservierte Datei kann clientseitig erst geloescht werden, nachdem die
Finalisierung die exakt reservierte Groesse bestaetigt hat. Damit ist auch eine
Loeschen-und-neu-hochladen-Umgehung der Reservierung geschlossen.

## Testnachweise

- Flutter Analyze: keine Befunde
- Flutter Unit-/Widget-Regression: 237/237 bestanden
- Cloud Functions: 113/113 bestanden
- Firestore-/Storage-Regeln: 111/111 bestanden
- SEC-004 Firestore-Emulator: 425 Social-Dokumente ueber mehrere Seiten,
  Anonymisierung, Social-Report-Loeschung und Erhalt eines Moderationsreports
  bestanden
- Security-Diff-Scan: `0f935310-dca6-4856-ba34-a4d8c9591041`
- Der Diff-Scan fand in einem Zwischenstand zwei Umgehungsmoeglichkeiten:
  fehlendes zielweites Kennzeichenkontingent und eine Storage-Loeschen-/
  Neuhochladen-Race. Beide wurden anschliessend geschlossen und erneut getestet.

## Verbleibende Grenzen

Es wurde nichts deployt, veroeffentlicht oder produktiv erzwungen. Die sechs
mittleren Befunde SEC-006 bis SEC-011 bleiben offen. Vor einem Release muessen
ausserdem App Check auf signierten Builds, Firebase-/Provider-Budgets, produktive
Rules und Functions sowie die externen Store-, Push-, iOS- und Betriebsnachweise
real geprueft werden.
