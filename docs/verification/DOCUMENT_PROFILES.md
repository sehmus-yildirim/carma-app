# Dokumentprofile

## Registry-Vertrag

Jedes `DocumentProfile` enthaelt Land, Dokumentart, Generation, benoetigte
Seiten, Sprachen, Schriften, Anker und Aliase, normalisierte Feldregionen,
MRZ-Konfiguration, Normalisierungs- und Validierungsregeln,
Confidence-Schwellwerte, Status und Quellen.

`productionValidated` darf erst nach dokumentierter Real-Dokument- und
Geraeteabnahme gesetzt werden. PRADO weist selbst darauf hin, dass seine
Datenbank nicht vollstaendig ist. Fehlende Layoutinformationen werden deshalb
nicht geraten.

## Belastbare Quellen

- ICAO Doc 9303: https://www.icao.int/publications/doc-series/doc-9303
- PRADO Laendersuche: https://www.consilium.europa.eu/prado/en/search-by-document-country.html
- DE Personalausweis 2021: https://www.consilium.europa.eu/prado/en/DEU-BO-02004/index.html
- DE Personalausweis 2010: https://www.consilium.europa.eu/prado/en/DEU-BO-02001/index.html
- DE Zulassungsbescheinigung Teil I: https://www.consilium.europa.eu/prado/en/DEU-GO-01001/index.html
- EU-Richtlinie 1999/37/EG: https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:31999L0037

## Parserprinzipien

- Positionsdaten und Label-Anker werden gemeinsam ausgewertet.
- Mehrdeutige Kandidaten werden nicht geraten.
- TD1, TD2 und TD3 validieren Geburts- und Ablaufdatums-Pruefziffern.
- MRZ ist ein strukturierter Extraktionskanal, kein Echtheitsnachweis.
- Originalwert und konservativer Vergleichswert bleiben getrennt.
- Nicht-lateinische visuelle Dokumentseiten werden erst nach einem
  belastbaren, quellengestuetzten Profil freigeschaltet. Reisepass-MRZ bleibt
  lateinisch/transliteriert nach ICAO.
