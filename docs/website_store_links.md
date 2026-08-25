# Website-Store-Links

Stand: 25. August 2026

## Aktueller Zustand

Der oeffentliche Website-Status ist `pre_release`. plaqa besitzt eine interne
Google-Play-Testspur und einen vorbereiteten App-Store-Connect-Eintrag, ist
aber in keinem Store oeffentlich freigegeben.

Die zentrale technische Vorabkonfiguration liegt in
`hosting/store-links.js`:

- `state`: `pre_release`
- `publicLabel`: `Bald verfuegbar`
- `googlePlayUrl`: `null`
- `appStoreUrl`: `null`

Die Datei enthaelt weder Testerlinks noch Zugangsdaten. Ein spaeteres
Neudesign kann diese Konfiguration verwenden, ohne Store-Ziele an mehreren
Stellen zu duplizieren.

## Sichtbares Verhalten vor dem Release

- Die Website darf ehrlich `Bald verfuegbar` oder `In Vorbereitung` anzeigen.
- Ein nicht verfuegbares Store-Element ist kein Link und besitzt kein leeres
  `href` sowie keinen `#`-Platzhalter.
- Ein optisch als Schaltflaeche dargestellter Status wird semantisch als Text
  oder deaktiviertes Element umgesetzt und verspricht keinen Download.
- Interne Google-Play-Testlinks, TestFlight-Links und App-Store-Connect-Links
  duerfen nicht auf der oeffentlichen Website erscheinen.
- Der bestehende Link `Fragen zur App` darf weiterhin auf `/support` fuehren.

## Zustaende

| Zustand | Oeffentliche Darstellung | Erlaubte Ziele |
| --- | --- | --- |
| `pre_release` | Status ohne Downloadaktion | Keine Store-URL |
| `internal_testing` | Weiterhin kein oeffentlicher Download | Testerlinks nur direkt an freigegebene Tester, niemals auf der Website |
| `public_release` | Offizielle Store-Schaltflaechen | Ausschliesslich veroeffentlichte Produktseiten von Google Play und Apple App Store |

## Geplante offizielle Ziele

Die Ziele werden erst nach bestaetigter oeffentlicher Freigabe in der zentralen
Konfiguration aktiviert:

- Google Play: Produktseite fuer Paket `de.plaqa.app`
- Apple App Store: Produktseite fuer App-ID `6804814664`

Vor der Aktivierung wird jede URL im ausgeloggten Browser geprueft. Eine
Console-, Entwurfs-, interne Test- oder Verwaltungs-URL ist niemals ein
zulaessiges oeffentliches Ziel.

## Release-Wechsel

1. Store-Freigabe und oeffentliche Erreichbarkeit bestaetigen.
2. Exakte offizielle HTTPS-Produkt-URL in `hosting/store-links.js` eintragen.
3. Sichtbare Store-Elemente mit `data-store-platform` beziehungsweise der
   etablierten gemeinsamen Komponente verbinden.
4. Tastatur-, Screenreader-, Mobil- und ausgeloggte Linktests ausfuehren.
5. Erst nach separater Hosting-Freigabe deployen.

Bis zu diesem Wechsel bleiben beide URLs bewusst `null`.
