# Datenschutz und Datenminimierung

## Lokal verarbeitet

Dokumentfotos, EXIF-/Bilddaten, OCR-Zeilen, Bounding-Boxes und die transienten
Halterfelder werden lokal verarbeitet. Dokumentbilder werden nach Erfolg,
Fehler oder Abbruch bestmoeglich sofort geloescht; ein Start-Cleanup entfernt
verwaiste verwaltete Temp-Dateien. Sie werden nicht in Firebase Storage
hochgeladen.

## Identitaet: dauerhaft

- firstNames
- lastName
- dateOfBirth
- documentExpiryDate
- documentType
- issuingCountryCode (Dokumentmetadatum, nicht Nationalitaet)
- documentProfileVersion und parserVersion
- Status-, Methoden-, Versions- und Zeitstempelmetadaten

Nicht gespeichert werden unter anderem Dokumentnummer, Adresse, Geburtsort,
Nationalitaet als Verifizierungsdatum, Portrait, Unterschrift des Dokuments,
CAN oder kompletter OCR-Rohtext.

## Fahrzeugdokument: dauerhaft

Persistiert werden normalisiertes Kennzeichen, Zulassungsland,
Dokumentprofilversion, Relation und Match-Fakten. Haltername/Firma und
Haltervornamen werden nur im transaktionalen Abgleich verwendet und nicht in
der Verifizierung gespeichert.

## Eigenerklaerung

Nur bei Nicht-Haltern wird ein privates, unveraenderbares PDF erzeugt. Es
enthaelt Declaration-ID, pseudonymisierte Nutzerreferenz, Name, Kennzeichen,
Relation, versionierten Text, Zeitpunkt und Touch-Unterschrift. Storage-Regeln
erlauben keinen Client-Upload oder -Overwrite. Die Touch-Unterschrift wird
nicht als qualifizierte elektronische Signatur bezeichnet.

## Logging

Keine Dokumentbilder, Namen, Geburtstage, Signaturen, Klartextkennzeichen oder
OCR-Rohtexte duerfen in Logs oder Crashreports geschrieben werden. Erlaubt
sind Request-ID, anonymisierte Referenz, Land, Dokumenttyp, Parser-Version,
Fehlercode, Timing und technischer Status.
