# Plaqa Verification V1

Die aktuelle internationale, profilgesteuerte Architektur ist in
[`docs/verification/`](verification/) dokumentiert.

Direkteinstiege:

- [Architektur](verification/ARCHITECTURE.md)
- [Dokumentprofile](verification/DOCUMENT_PROFILES.md)
- [Tatsaechlich unterstuetzte Dokumente](verification/SUPPORTED_DOCUMENTS.md)
- [Datenschutz](verification/PRIVACY.md)
- [Tests](verification/TESTING.md)
- [Release-Checkliste](verification/RELEASE_CHECKLIST.md)

Neue Verifizierungen verwenden:

```text
verificationMethod = on_device_document_ocr_v1
assuranceLevel = document_data_match
```

Die alte Methode `on_device_ocr_front_v1` wird nur noch fuer bestehende
verifizierte Datensaetze waehrend der kontrollierten Migration akzeptiert.
