# Website-Testanleitung

Stand: 25. August 2026

## Zweck

Das Testgeruest prueft die technische Hosting-Grundlage ausschliesslich lokal.
Es sendet keine Formularanfrage, ruft keine Cloud Function auf, greift nicht auf
Produktionsdaten zu und veraendert keine Firebase-Ressource.

## Vollstaendiger lokaler Lauf

Im Projektstamm ausfuehren:

```text
npm run test:website
```

Der Befehl benoetigt keine neue npm-Abhaengigkeit. Er startet fuer die
HTTP-Vertragstests einen kurzlebigen Server auf `127.0.0.1` mit einem freien
lokalen Port und beendet ihn nach jedem Test wieder.

## Abdeckung

`test/website_contact_form.test.cjs` prueft:

- sichere Payloads fuer Support, Datenschutz, Partnerschaften und Meldestelle,
- deutsche Validierungs- und Fehlertexte,
- Honeypot, Header-Injection sowie Feld- und Requestgroessen,
- lokale Emulatorziele ohne Produktionsaufruf,
- zugaengliche Formulare und sichtbare E-Mail-Fallbacks,
- keine lokale Speicherung oder Protokollierung von Formulardaten.

`test/website_hosting.test.cjs` prueft:

- alle zehn kanonischen oeffentlichen Routen,
- kompatible Slash-Weiterleitungen,
- eine unbekannte URL mit eigener Seite und HTTP 404,
- Canonical- und Robots-Metadaten,
- die XML-Struktur und exakte URL-Menge der Sitemap,
- `robots.txt`, interne Links, Fragmente, Skripte, Styles und Bilder,
- die nicht indexierbare Auth-Aktionsroute und ihre Query-Parameter,
- den zentralen Store-Status ohne Test- oder Platzhalterlinks,
- die vier Kontaktkanaele.

`test/website_browser.test.cjs` prueft die statischen Darstellungs- und
Interaktionsvertraege:

- Mobile-Viewport auf jeder oeffentlichen Seite und auf der 404-Seite,
- Schutz der Seitenhuelle vor horizontaler Ueberbreite,
- responsive Breakpoints ohne riskante feste Mindestbreiten,
- Anfangs-, Oeffnen- und Schliessen-Vertrag der mobilen Navigation,
- sichere HTTPS-Weiterleitung fuer Firebase-Auth-Aktionen ausschliesslich zu
  `plaqa.de` und dessen Subdomains.

## Gerenderte Browser-QA

Nach Aenderungen an HTML oder CSS wird zusaetzlich ein lokaler Hosting-Server
gestartet und die Website im Browser mindestens mit folgenden Viewports
kontrolliert:

- Desktop: 1280 x 800 Pixel
- Smartphone: 390 x 844 Pixel

Dabei werden Startseite, eine Formularseite, die Auth-Aktionsseite im
Preview-Modus und eine unbekannte URL geprueft. Zu kontrollieren sind sichtbare
Ueberbreite, Navigation, Fokus, Bilder, 404-Status und Browserkonsole. Der
Server und alle vom Test gestarteten Browserfenster werden danach beendet.

Die Kommandozeilen-Headless-Renderer der aktuell installierten
Windows-Chromium-Version sind wegen eines lokalen GPU-Prozessfehlers nicht Teil
des verpflichtenden npm-Laufs. Die gerenderte QA erfolgt deshalb ueber den
Codex-Browser; die reproduzierbaren Quell-, Routing- und Mobilvertraege bleiben
im npm-Lauf automatisiert.

Letzter gerenderter Lauf am 25. August 2026: Startseite, Supportformular,
Auth-Aktionsseite und eigene 404 bestanden auf 1280 x 800 sowie 390 x 844
Pixel. Es gab keinen horizontalen Ueberlauf und keine relevanten Warnungen oder
Fehler in der Browserkonsole. Die mobile Navigation und die lokale
Formularvalidierung wurden interaktiv geprueft.

## Release-Regel

Ein bestandener lokaler Lauf ist keine Deploy-Freigabe. Vor einem spaeteren
Hosting-Deploy sind zusaetzlich der vollstaendige Diff, die Rechtsinhalte, die
Formular-Function, deren Secret, Rate-Limits, TTL-Entscheidung und der
Datenschutzprozess gesondert freizugeben.
