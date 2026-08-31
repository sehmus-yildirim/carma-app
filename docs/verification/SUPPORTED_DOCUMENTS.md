# Unterstuetzte Dokumente

Stand: 2026-08-31

## Ehrliche Zusammenfassung

- Production validated profiles: **0**
- Implemented, needs real-document validation: **25 profiles** in **24
  country/document combinations**
- Explicitly unsupported combinations: **60**

Die zweite Zahl ist groesser als die Anzahl Kombinationen, weil fuer den
deutschen Personalausweis zwei Generationen registriert sind.

## Identitaetsdokumente

| Land | Dokument | Generation | Parserstatus | MRZ | Production validated |
|---|---|---|---|---|---|
| DE | Personalausweis | DEU-BO-02004 (2021) | implemented_needs_real_validation | TD1 parser vorhanden, Vorderseite visuell | Nein |
| DE | Personalausweis | DEU-BO-02001 (2010) | implemented_needs_real_validation | TD1 parser vorhanden, Vorderseite visuell | Nein |
| DE | Aufenthaltstitel | eAT card family v1 | implemented_needs_real_validation | TD1 parser vorhanden, Vorderseite visuell | Nein |
| DE | Reisepass | ICAO TD3 v1 | implemented_needs_real_validation | TD3 | Nein |
| TR | Reisepass | ICAO TD3 v1 | implemented_needs_real_validation | TD3 | Nein |
| UA | Reisepass | ICAO TD3 v1 | implemented_needs_real_validation | TD3 | Nein |
| SY | Reisepass | ICAO TD3 v1 | implemented_needs_real_validation | TD3 | Nein |
| RO | Reisepass | ICAO TD3 v1 | implemented_needs_real_validation | TD3 | Nein |
| PL | Reisepass | ICAO TD3 v1 | implemented_needs_real_validation | TD3 | Nein |
| IT | Reisepass | ICAO TD3 v1 | implemented_needs_real_validation | TD3 | Nein |
| AF | Reisepass | ICAO TD3 v1 | implemented_needs_real_validation | TD3 | Nein |
| BG | Reisepass | ICAO TD3 v1 | implemented_needs_real_validation | TD3 | Nein |
| HR | Reisepass | ICAO TD3 v1 | implemented_needs_real_validation | TD3 | Nein |
| GR | Reisepass | ICAO TD3 v1 | implemented_needs_real_validation | TD3 | Nein |
| XK | Reisepass | ICAO TD3 v1 | implemented_needs_real_validation | TD3 | Nein |
| IN | Reisepass | ICAO TD3 v1 | implemented_needs_real_validation | TD3 | Nein |
| RU | Reisepass | ICAO TD3 v1 | implemented_needs_real_validation | TD3 | Nein |
| RS | Reisepass | ICAO TD3 v1 | implemented_needs_real_validation | TD3 | Nein |
| AT | Reisepass | ICAO TD3 v1 | implemented_needs_real_validation | TD3 | Nein |
| BA | Reisepass | ICAO TD3 v1 | implemented_needs_real_validation | TD3 | Nein |
| ES | Reisepass | ICAO TD3 v1 | implemented_needs_real_validation | TD3 | Nein |
| FR | Reisepass | ICAO TD3 v1 | implemented_needs_real_validation | TD3 | Nein |
| NL | Reisepass | ICAO TD3 v1 | implemented_needs_real_validation | TD3 | Nein |
| CH | Reisepass | ICAO TD3 v1 | implemented_needs_real_validation | TD3 | Nein |

Nationale ID-Karten und Aufenthaltstitel ausserhalb Deutschlands sind in V1
`unsupported`, bis pro Generation belastbare Layoutdaten und reale Testmuster
vorliegen.

## Fahrzeugdokumente

| Land | Dokument | Generation | Parserstatus | Felder | Production validated |
|---|---|---|---|---|---|
| DE | Zulassungsbescheinigung Teil I | DEU-GO-01001 v1 | implemented_needs_real_validation | A, C.1.1, C.1.2 | Nein |

Fahrzeugdokumente der weiteren 20 Laender sind `unsupported`. Die UI sperrt
den automatischen Scan und zeigt eine klare Meldung; es gibt keinen Fallback,
der Felder oder Layouts erraten wuerde.
