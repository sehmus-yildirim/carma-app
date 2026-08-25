# Website-URL-Vertrag

Stand: 25. August 2026

## Zweck

Diese Datei ist der verbindliche technische Vertrag fuer die oeffentlichen
plaqa-URLs. Ein spaeteres Website-Neudesign darf Layout, Inhalte und interne
Dateistruktur aendern, aber die hier festgelegten Routen nicht unbemerkt
entfernen oder umbenennen.

Firebase Hosting verwendet `cleanUrls: true` und `trailingSlash: false`.
Deshalb ist die kanonische Schreibweise ohne abschliessenden Slash. Bestehende
Links mit abschliessendem Slash bleiben als kompatible Aufrufe funktionsfaehig
und werden vom Hosting auf die kanonische Variante weitergeleitet.

## Indexierbare Routen

| Kanonische URL | Kompatibler Aufruf | Quelldatei | Zweck |
| --- | --- | --- | --- |
| `/` | `/index.html` wird nicht beworben | `hosting/index.html` | Oeffentliche Startseite |
| `/community-richtlinien` | `/community-richtlinien/` | `hosting/community-richtlinien/index.html` | Community- und Sicherheitsregeln |
| `/datenschutz` | `/datenschutz/` | `hosting/datenschutz/index.html` | Datenschutzerklaerung und Betroffenenkontakt |
| `/impressum` | `/impressum/` | `hosting/impressum/index.html` | Anbieterkennzeichnung |
| `/kinderschutz` | `/kinderschutz/` | `hosting/kinderschutz/index.html` | Oeffentliche Kinderschutzstandards |
| `/konto-loeschen` | `/konto-loeschen/` | `hosting/konto-loeschen/index.html` | Oeffentliche Anleitung zur Kontoloeschung |
| `/meldestelle` | `/meldestelle/` | `hosting/meldestelle/index.html` | Oeffentliche Meldestelle |
| `/nutzungsbedingungen` | `/nutzungsbedingungen/` | `hosting/nutzungsbedingungen/index.html` | Nutzungsbedingungen |
| `/partner` | `/partner/` | `hosting/partner/index.html` | Partnerschaftsanfragen |
| `/support` | `/support/` | `hosting/support/index.html` | Support und Hilfe |

Die zehn kanonischen URLs sind in `hosting/sitemap.xml` enthalten. Jede Seite
setzt eine passende kanonische HTTPS-URL unter `https://plaqa.de`.

## Nicht indexierbare Systemrouten

| Route | Quelldatei | Vertrag |
| --- | --- | --- |
| `/auth/action` | `hosting/auth/action/index.html` | Muss fuer Firebase-E-Mail-Aktionen dauerhaft erreichbar bleiben, wird aber nicht indexiert und steht nicht in der Sitemap. |
| `/404.html` | `hosting/404.html` | Wird nur als Hosting-Fehlerdokument verwendet, liefert fuer unbekannte URLs HTTP 404 und wird nicht indexiert. |
| `/email-templates/` | `hosting/email-templates/` | Technische Vorlagen, nicht fuer Suchmaschinen oder Navigation bestimmt. |

## Auth-Aktionsvertrag

`/auth/action` verarbeitet Firebase-Aktionslinks. Folgende Parameter duerfen
beim Neudesign nicht verloren gehen:

- `mode`
- `oobCode`
- `continueUrl`
- `preview` ausschliesslich fuer lokale beziehungsweise kontrollierte
  Designpruefungen

Die Seite muss E-Mail-Bestaetigung, E-Mail-Aenderung, Wiederherstellung einer
E-Mail-Adresse und Passwort-Zuruecksetzung weiterhin behandeln. Eine
`continueUrl` ist nur zulaessig, wenn sie HTTPS verwendet und auf `plaqa.de`
oder eine Subdomain von `plaqa.de` zeigt. Unbekannte externe Ziele werden
verworfen.

## Weiterleitungsregeln

- Kanonische Inhaltsseiten verwenden keinen abschliessenden Slash.
- Bestehende Links mit Slash bleiben kompatibel.
- Alte `.html`-Adressen sind kein oeffentlich beworbener Vertrag.
- Eine kuenftige Umbenennung benoetigt vorab eine permanente Weiterleitung,
  einen aktualisierten Sitemap-Eintrag und einen Test fuer Alt- und Neuroute.
- Auth-, Store-, App- und E-Mail-Vorlagenlinks werden vor jeder
  Routenveraenderung separat abgeglichen.
- Unbekannte Routen werden niemals still auf die Startseite umgeleitet,
  sondern zeigen die plaqa-404-Seite mit echtem HTTP-Status 404.

## Schutz vor Regressionen

Die automatisierten Website-Tests pruefen:

- jede kanonische Route,
- jeden kompatiblen Slash-Aufruf,
- interne Links und Fragmente,
- Sitemap und Robots-Regeln,
- die nicht indexierbare Auth-Aktionsroute,
- eine unbekannte URL samt 404-Status,
- Desktop- und Smartphone-Breite ohne horizontalen Overflow.

Der Vertrag ist erst dann geaendert, wenn Dokumentation, Tests, Sitemap und
betroffene App-/Store-/Firebase-Verweise gemeinsam aktualisiert wurden.
