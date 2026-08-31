# Plaqa Dokument- und Fahrzeugverifizierung V1

## Ziel und Zusicherung

V1 ist ein serverautorisierter Dokumentdatenabgleich. Es ist kein Bank-KYC,
keine biometrische Identifizierung und keine amtliche Echtheitspruefung.

```text
verificationMethod = on_device_document_ocr_v1
assuranceLevel = document_data_match
```

Selfie, Gesichtserkennung, Face Match, Liveness und externe KYC-Anbieter sind
nicht Bestandteil des Flows.

## Aktiver Ablauf

1. Der Nutzer waehlt das Ausstellungsland und einen dafuer freigegebenen
   Identitaetsdokumenttyp.
2. `DocumentCameraScreen` nimmt die im Profil definierte Datenseite direkt in
   der App auf. Galerie- und Dateiimport sind im aktiven Flow deaktiviert.
3. `LocalVerificationTemporaryFileService` korrigiert EXIF-Orientierung,
   begrenzt die Bildgroesse und verwaltet ausschliesslich temporaere Dateien.
4. `LocalImageQualityService` prueft Aufloesung, Belichtung, Schaerfe,
   Dokumentgroesse, Beschnitt, Rotation und Perspektivverzerrung in einem
   Isolate.
5. `MlKitDocumentOcrService` liefert Zeilen und Bounding-Boxes. Der komplette
   OCR-Rohtext wird nicht persistiert oder geloggt.
6. Profilgesteuerte Parser und `MrzParser` liefern nur die erlaubten Felder und
   nachvollziehbare Feld-Confidence.
7. Der gleiche lokale Prozess liest das freigegebene Fahrzeugdokument.
8. `VerificationV1Repository` sendet strukturierte Minimaldaten ueber
   App-Check-geschuetzte Callable Functions.
9. Das Backend prueft Nutzer, Fahrzeugbindung, Profil-Allowlist, Session,
   Nonce, Alter, Ablaufdatum, Kennzeichen und gegebenenfalls Halterdaten.
10. Nicht-Halter bestaetigen die zentral versionierte Eigenerklaerung mit
    Checkbox und Touch-Unterschrift. Das Backend erzeugt das private PDF.

## Module

- `document_profiles.dart`: Laender, Generationen, Quellen, Felder und Status
- `document_camera_screen.dart`: Kamera, Fokus, Blitz, Rahmen und Preview
- `document_services.dart`: Capture-, OCR-, Quality- und Temp-File-Ports
- `verification_document_processor.dart`: lokale Quality/OCR/Parse-Pipeline
- `verification_parsers.dart`: profilgesteuerte visuelle Parser
- `mrz_parser.dart`: TD1, TD2 und TD3 mit Datums-Pruefziffern
- `verification_confidence.dart`: signalbasierte HIGH/MEDIUM/LOW-Einstufung
- `verification_state_machine.dart`: expliziter End-to-End-Statusautomat
- `verification_v1_repository.dart`: typisierte Firebase-Grenze
- `functions/verification_v1.js`: serverautoritative Match- und Persistenzlogik

## Trust Boundaries

Der Client kann niemals `verified=true` setzen. Firestore- und Storage-Regeln
verweigern direkte Schreibzugriffe auf private Verifizierungen, Sessions,
Rate-Limits und Erklaerungen. Der Server bindet jede Session an UID, Fahrzeug,
Relation, Nonce, Ablaufzeit und einen einmaligen App-Check-Token. Wiederholte
identische Requests sind idempotent; veraenderte Replays werden abgelehnt.

App Check bestaetigt App- und Anfragekontext, bindet die vom Client gesendeten
OCR-Felder aber nicht kryptografisch an eine konkrete Kameraaufnahme. Deshalb
darf der Status nur als `document_data_match` verwendet und dargestellt
werden. Er darf keine KYC-, Echtheits-, Eigentums- oder amtliche
Identitaetszusage ersetzen und keine hoeher privilegierte Aktion freischalten.

## Migration

Der bestehende Flow wurde migriert, nicht dupliziert. Alte verifizierte Daten
mit `on_device_ocr_front_v1` bleiben waehrend der Kompatibilitaetsphase
wirksam. Neue Verifizierungen schreiben Schema 2 und
`on_device_document_ocr_v1`. Alte Relationswerte werden serverseitig auf die
neuen fuenf Werte normalisiert. Eine erneute Verifizierung schreibt die neuen
Profil- und Match-Metadaten; keine Massenmigration sensibler Daten ist noetig.
