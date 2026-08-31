# Release-Checkliste Verifizierung V1

## Lokale Gates

- [x] Formatcheck gruen
- [x] `flutter analyze` gruen
- [x] alle Flutter Unit- und Widgettests gruen
- [x] 240 synthetische Parser-Matrixfaelle gruen
- [x] Functions-Tests gruen
- [x] Firestore- und Storage-Rules-Tests im Emulator gruen
- [x] Integrationstest auf Android gruen
- [x] Android Release AAB erfolgreich gebaut
- [x] Security-Diff-Scan ohne Critical/High
- [x] keine Dokumentbilder, Signaturen, Secrets oder personenbezogene Fixtures im Git-Diff
- [x] Migration und Legacy-Methode geprueft

Nachweis: 306 Flutter-Tests bestanden, ein Android-spezifischer ML-Kit-Test
unter Windows uebersprungen, 173 Functions-Tests, 113 Rules-Tests und 240
Parser-Matrixfaelle bestanden. Das AAB wurde mit 85,6 MB erzeugt. Der
Security-Diff-Scan meldet einen Low-Befund zur fehlenden kryptografischen
Bindung lokaler OCR-Werte, aber keine Critical-, High- oder Medium-Befunde.

Der korrigierte Redmi-Rerun ist abgeschlossen: 19/19 Szenarien bestanden,
einschliesslich der nativen Android-ML-Kit-Bruecke und der 18 deterministischen
End-to-End-Szenarien. Die aktuelle Debug-App wurde anschliessend erfolgreich
auf dem Redmi installiert und gestartet.

## Externe Gates - niemals automatisch abhaken

- [ ] echte Geraete-Kamera-Matrix inklusive Blitz, Fokus, Lifecycle und Retry
- [ ] reale/anonymisierte Dokumenttests pro freizugebender Generation
- [ ] juristische Pruefung der Eigenerklaerung
- [ ] Datenschutz-, AGB- und Store-Datenangaben geprueft

## Device Smoke Test

1. Kamera-Berechtigung erstmalig und nach Ablehnung pruefen.
2. ID/Pass/Fahrzeugrahmen, Portrait und Fahrzeug-Querformat pruefen.
3. Tap-to-focus und Blitz testen.
4. App waehrend Live-Kamera und Verarbeitung in Hintergrund/Vordergrund.
5. Capture, Preview, Neu aufnehmen und Foto verwenden.
6. Unscharf, dunkel, zu hell und abgeschnitten kontrolliert ablehnen.
7. OCR-Erfolg, Retry, Halter und Nicht-Halter bis zum Abschluss.
8. Temp-Verzeichnis nach Erfolg, Fehler und Abbruch kontrollieren.
