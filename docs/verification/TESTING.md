# Teststrategie

## Automatisierte Ebenen

- Domain-Tests: Normalisierung, Datum, MRZ-Pruefziffern, Registry, Confidence,
  Statusautomat, Parser, Matching und Temp-Dateien
- Synthetische Matrix: `golden_dataset.json` expandiert 21 Laender,
  implementierte Dokumentfamilien und zehn Aufnahmebedingungen in 240
  deterministische Parserfaelle
- Widgettests: Dokumentauswahl, Kamera-/Galerieauswahl, Read-only-Ergebnis, Fehler,
  Relationen, Datenschutz, Erklaerung, Checkbox, Unterschrift und A11y
- Integrationstest: 18 deterministische End-to-End-Szenarien fuer Halter,
  Nicht-Halter, Ablauf, Alter, Plate-Mismatch, unscharfe Aufnahme, unbekanntes
  Dokument, ungueltige MRZ, Kameraabbruch, Doppel-Submit und sichtbare
  Serverfehler
- Android-ML-Kit-Test: zur Laufzeit erzeugtes, deutlich als ungueltig
  markiertes Testbild prueft die echte native OCR-Bruecke; auf Windows wird
  dieser Test bewusst uebersprungen
- Functions-Tests: App Check, Nonce, Replay, Rate-Limit, Profil-Allowlist,
  Match, Declaration-PDF, Race Conditions, Widerruf und Ablauf
- Firebase-Emulatortests: eigene/fremde Daten, verbotene Statuswrites,
  Declaration- und Storage-Schutz

## Synthetische Fixtures

Alle Fixtures sind dauerhaft mit `PLAQA TEST DOCUMENT`, `SAMPLE` und
`NOT VALID` gekennzeichnet und enthalten nur fiktive Daten. Sie simulieren
Parserstruktur; sie sind keine echten Ausweise und kein Ersatz fuer reale
ML-Kit-Kameraabnahmen. Falsche Extraktion ist schwerwiegender als Ablehnung:
Precision hat Vorrang vor Recall.

## Reale Pre-Release-Matrix

Keine echten Dokumentbilder werden committed. Rechtmaessig verwendete oder
anonymisierte Beispiele werden nur in einer geschuetzten Testumgebung geprueft:

1. jede als freigabefaehig markierte Generation
2. mindestens zwei Android-Geraeteklassen und mehrere Lichtbedingungen
3. lange/mehrteilige Namen, Bindestrich, Apostroph und relevante Schriften
4. abgelaufen, abgeschnitten, unscharf, Reflexion und unbekannte Generation
5. Ergebnis gegen manuell kontrollierte Ground Truth

Erst ein protokollierter Durchlauf darf `productionValidated` aendern.

## Lokale Befehle

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
node --test --test-concurrency=1 functions/*.test.js
npx firebase-tools emulators:exec --project carma-a84e4 --only firestore,storage "node --test --test-concurrency=1 test/rules/*.test.cjs"
flutter test integration_test/verification_v1_flow_test.dart -d <device>
flutter build appbundle --release
```

## Ergebnis des finalen lokalen Laufs

- `flutter analyze`: 0 Befunde
- `flutter test`: **306 bestanden**, **1 Android-spezifischer ML-Kit-Test auf
  Windows uebersprungen**, 0 fehlgeschlagen
- Parsermatrix: **240/240** bestanden
- Functions: **173/173** bestanden
- Firestore/Storage Rules: **113/113** in 16 Suites bestanden
- Android-V1-Flow auf dem Redmi: **19/19** bestanden, bestehend aus der nativen
  ML-Kit-Bruecke und den 18 deterministischen End-to-End-Szenarien
- Android Release AAB: erfolgreich, 85,6 MB unter
  `build/app/outputs/bundle/release/app-release.aab`

Der erste Redmi-Lauf installierte und startete erfolgreich. 11 Szenarien
bestanden; 5 deckten auf, dass Serverfehler am oberen Ende der Scrollansicht
nicht sichtbar waren. Der Fehler wurde behoben. Der anschliessende korrigierte
Hardware-Rerun bestand alle **19/19** Szenarien, einschliesslich der nativen
ML-Kit-Bruecke. Die aktuelle Debug-App wurde danach erneut erfolgreich auf dem
Redmi installiert und gestartet.

Der Security-Diff-Scan fand keine Critical-, High- oder Medium-Befunde. Ein
Low-Risiko bleibt dokumentiert: Client-OCR-Werte sind nicht kryptografisch an
die Aufnahme gebunden. Das Verfahren bleibt daher strikt
`document_data_match` und darf keine staerkere Vertrauenszusage darstellen.
