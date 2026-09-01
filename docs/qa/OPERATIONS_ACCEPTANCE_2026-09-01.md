# Plaqa Betriebs- und Sicherheitsabnahme

Stand: 1. September 2026
Projekt: `carma-a84e4`
Verantwortlich: Sehmus Yildirim

## Ergebnis

Die technische Betriebsgrundlage fuer den spaeteren Android-Testbetrieb ist
eingerichtet. Budgetwarnungen, produktive Fehleralarme, ein verifizierter
E-Mail-Kanal, ein Produktionsdashboard und eine reversible Rollbackuebung sind
nachgewiesen. Die externe verschluesselte Sicherung bleibt bis zum Vorliegen des
Datentraegers offen.

## Kostenkontrolle

- Monatsbudget: 25 EUR
- Warnungen Ist-Ausgaben: 5 EUR, 10 EUR, 20 EUR und 25 EUR
- Prognosewarnung: erwartete 25 EUR
- Empfaenger: `yildirim.sehmus4747@gmail.com`
- Hinweis: Das Warnbudget ist keine technische Ausgabensperre.

## Monitoring

- E-Mail-Kanal: `Plaqa Betrieb und Sicherheit`, `VERIFIED`, aktiv
- Alarm: `Plaqa Produktion - Functions Fehler`
- Alarm: `Plaqa Produktion - Scheduler Fehler`
- Rate Limit: eine Nachricht je Richtlinie und 15 Minuten
- Auto-Close: 24 Stunden ohne neuen Treffer
- Dashboard: `Plaqa Produktionsbetrieb`
- Dashboard-ID: `0db9a447-2230-4769-8700-e8ce70aaca5e`

## Incident-Uebung

- Drill-ID: `OPS-2026-09-01-01`
- Ausloeser: klar gekennzeichneter `ERROR`-Testlog auf der aktiven
  `requestvehicleheroimage`-Revision
- Nutzerdaten: nicht gelesen oder veraendert
- Produktionsfunktion: nicht absichtlich zum Fehlschlag gebracht
- Monitoring-Filter: getroffen
- Fehler am E-Mail-Kanal: keiner protokolliert
- Menschlicher Zustellnachweis: durch Sehmus Yildirim bestaetigt

## Rollback-Uebung

1. Keine Anfragen im 30-Minuten-Fenster vor der Uebung bestaetigt.
2. Traffic von `requestvehicleheroimage-00014-gap` vollstaendig auf
   `requestvehicleheroimage-00013-jec` geroutet.
3. Produktiven Routingstand unabhaengig ausgelesen.
4. Traffic vollstaendig auf `requestvehicleheroimage-00014-gap`
   wiederhergestellt.
5. Aktuelle Revision und 100-Prozent-Routing unabhaengig bestaetigt.

Ergebnis: PASS, keine Daten- oder Nutzerbeeintraechtigung.

## App Check

- Functions ab finalem Redmi-Fenster: 22 `VALID`, 0 `INVALID`, 0 `MISSING`
- Storage: 8 `VALID`, 0 ungueltig/unbekannt
- Firestore: 9.896 `VALID`, 2.177 ungueltig/unbekannt
- Authentication: 35 `VALID`, 2 ungueltig/unbekannt
- Sicherheitskritische Callable Functions erzwingen App Check bereits.
- Serviceweite Modi fuer Firestore, Storage und Authentication bleiben bis zur
  geschlossenen Android-Testspur auf `UNENFORCED`.

Diese Entscheidung verhindert, dass unbekannte legitime Verwaltungs- oder
Testpfade vor ihrer Ursachenanalyse ausgesperrt werden. Die Aktivierung ist ein
separates kontrolliertes Change mit Vorher-/Nachher-Metriken und Rollbackplan.

## Release-Entscheidung Profil-Verifizierung

Die vorhandene Implementierung bleibt fuer Weiterentwicklung und gezielte
Debug-Tests erhalten. Normale Release-Builds bieten den derzeit unzuverlaessigen
Dokument-Verifizierungsablauf nicht an. Eine spaetere Aktivierung erfolgt nur
explizit mit `PLAQA_PROFILE_VERIFICATION_ENABLED=true` und nach erneuter
Regression, Datenschutzpruefung und dokumentierter Produktfreigabe.

Damit blockiert der bekannte Erkennungsfehler den uebrigen Android-Testbetrieb
nicht und wird Nutzern nicht als verlaessliche Funktion versprochen.

## Technische Regression und Build

- `flutter analyze`: 0 Befunde
- Flutter Unit-/Widget-Regression: 311 bestanden, 0 fehlgeschlagen,
  1 bewusst uebersprungen
- Release-Gate-Tests bei deaktivierter Profil-Verifizierung: 35 bestanden,
  0 fehlgeschlagen
- Firebase Functions: 174 bestanden, 0 fehlgeschlagen
- Firestore-/Storage-Regeln im Emulator: 114 bestanden, 0 fehlgeschlagen
- Android Release-APK: `build/app/outputs/flutter-apk/app-release.apk`
- APK-Groesse: 117.039.397 Byte
- APK-Signatur: gueltige APK Signature Scheme v2, ein RSA-2048-Signer
- Signer-Zertifikat SHA-256:
  `77A1A10535618B1FC681E5AF9782317A001C7BC229DEE720F31A03763363C7BC`
- SHA-256:
  `7DCE7FAD583700A36232A9323D57DB1F0D8FC7FE8835CD28837A3E2AE9CFFAA2`

## Verantwortlichkeiten

- Incident-Leitung: Sehmus Yildirim
- Mobile/Backend: Sehmus Yildirim
- Firebase und Cloud-Kosten: Sehmus Yildirim
- Datenschutz/Recht: Sehmus Yildirim, externe Rechtsfreigabe ausstehend
- Moderation/Kinderschutz: Sehmus Yildirim
- Support: Sehmus Yildirim, `support@plaqa.de`
- Store: Sehmus Yildirim
- Technische Stellvertretung: nach Abstimmung mit dem Programmierer einzutragen

## Bewusst offene externe Nachweise

- verschluesselte Sicherung und Wiederherstellungsprobe auf externem Datentraeger
- Name und Kontakt der technischen Stellvertretung
- rechtsverbindliche externe Freigabe des vorbereiteten Anwaltspakets
- App-Check-Enforcement nach ausreichender geschlossener Testspur

Diese Punkte sind externe beziehungsweise bewusst nachgelagerte Release-Gates.
Sie sind nicht durch technische Behauptungen ersetzbar.
