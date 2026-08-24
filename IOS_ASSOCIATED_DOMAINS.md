# plaqa iOS Associated Domains

Stand: 2026-08-25

## Entscheidung

Associated Domains bleibt fuer die erste App-Store-Version deaktiviert. Der
aktuelle Flutter-Client erzeugt teilbare Profil- und Beitrags-URLs, besitzt aber
noch kein eingehendes Deep-Link-Routing. Eine AASA-Datei ist ebenfalls noch
nicht veroeffentlicht. Das Entitlement ohne funktionsfaehige Gegenstelle wuerde
daher keinen produktiven Nutzen liefern.

## Vorbereitet

- Apple-App-ID: `de.plaqa.app`
- Apple-Capability Associated Domains: fuer Version 1 deaktiviert
- Runner-Entitlement `applinks:plaqa.de`: entfernt
- Sign in with Apple und Push Notifications: unveraendert aktiv
- Android-, Firebase-, Auth- und Web-Konfiguration: nicht veraendert

## Fuer eine spaetere Einfuehrung erforderlich

1. Routen fuer Profil und Beitrag im Flutter-Client festlegen. Firebase-
   Auth-Aktionslinks bleiben davon getrennt unter `auth.plaqa.de`.
2. `apple-app-site-association` ohne Dateiendung unter
   `https://plaqa.de/.well-known/apple-app-site-association` bereitstellen.
3. In der AASA-Datei nur die benoetigten Pfade und die echte Apple-App-ID
   freigeben; Team-ID nicht in diesem Repository-Dokument wiederholen.
4. Associated Domains in der Apple-App-ID und im Xcode-Target wieder aktivieren.
5. Xcode-Signing und ein danach erzeugtes Provisioning Profile gegen das
   Entitlement pruefen.
6. Installierte App, nicht installierte App und Web-Fallback auf echtem iPhone
   testen.

Bis diese Punkte bestanden sind, darf Universal Links nicht als fertige
Produktionsfunktion beworben werden. Die Deaktivierung fuer Version 1 hat keine
Firebase-Auth-Domain, Rechtsseite oder bestehende HTTPS-Funktion veraendert. Es
wurde keine Hosting-Datei deployt.
