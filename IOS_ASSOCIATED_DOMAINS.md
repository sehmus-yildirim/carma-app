# plaqa iOS Associated Domains

Stand: 2026-08-24

## Entscheidung

Associated Domains wird fuer plaqa verwendet. Geteilte Profil-, Beitrags- und
Auth-Links sollen spaeter auf einem installierten iPhone direkt in der App
oeffnen und ohne installierte App auf die HTTPS-Webseite zurueckfallen.

## Vorbereitet

- Apple-App-ID: `de.plaqa.app`
- Apple-Capability Associated Domains: aktiviert
- Runner-Entitlement: `applinks:plaqa.de`
- Android-, Firebase- und Web-Konfiguration: nicht veraendert

## Vor der Freigabe noch erforderlich

1. Routen fuer Profil, Beitrag und Auth-Link im Flutter-Client festlegen.
2. `apple-app-site-association` ohne Dateiendung unter
   `https://plaqa.de/.well-known/apple-app-site-association` bereitstellen.
3. In der AASA-Datei nur die benoetigten Pfade und die echte Apple-App-ID
   freigeben; Team-ID nicht in diesem Repository-Dokument wiederholen.
4. Xcode-Signing und neu erzeugtes Provisioning Profile gegen das Entitlement
   pruefen.
5. Installierte App, nicht installierte App und Web-Fallback auf echtem iPhone
   testen.

Bis diese Punkte bestanden sind, darf Universal Links nicht als fertige
Produktionsfunktion beworben werden. In diesem Schritt wurde keine Hosting-
Datei deployt und keine Website-Konfiguration veraendert.
