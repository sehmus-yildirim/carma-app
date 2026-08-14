# plaqa Codex handoff

Stand: 14. August 2026

## Projekt

- Lokaler Projektpfad auf diesem Laptop: `C:\Projects\plaqa`
- Git-Branch: `main`
- GitHub-Remote: `https://github.com/sehmus-yildirim/carma-app.git`
- Firebase-Projekt: `carma-a84e4`
- Produktname: `plaqa`
- Domain: `plaqa.de`
- Kontakt: `info@plaqa.de`

Die alten technischen GitHub- und Firebase-IDs wurden noch nicht migriert. Nicht allein wegen des alten Namens ein neues Firebase-Projekt anlegen.

## Aktueller Arbeitsbereich

Einstellungen -> Profil & Verifizierung -> Dokumente hochladen.

Fertig umgesetzt:

- Drei Dokumentgruppen mit insgesamt sechs Seiten:
  - Ausweis Vorder- und Rückseite
  - Führerschein Vorder- und Rückseite
  - Fahrzeugnachweis Vorder- und Rückseite
- Fahrzeugzuordnung ist direkt in der Fahrzeugkarte integriert.
- `0 von 6 Nachweisen vollständig` bleibt einzeilig; Status-Badge ist kompakter.
- Sichtbare `Fehlt`-Hinweise wurden entfernt.
- Datenschutzblock enthält `UNBEDINGT LESEN!`.
- Ausweis und Führerschein benötigen ein manuelles Ablaufdatum im Format `TT.MM.JJJJ`.
- Der Fahrzeugschein benötigt bewusst kein Ablaufdatum.
- Ablaufdaten werden privat als Firestore-Timestamps gespeichert und serverseitig erneut geprüft.
- Der frühere Termin aus Ausweis und Führerschein bestimmt das Verifizierungsende.
- Die tägliche Wartung setzt abgelaufene oder zu lange offene Prüfungen auf `expired`, entzieht den Verifiziert-Status und fordert aktuelle Nachweise an.
- Das Nutzerkonto wird bei Ablauf nicht gelöscht oder deaktiviert.

## Letzte Prüfungen

- `flutter test test\profile_verification_ui_test.dart`: 3/3 bestanden
- `node --test functions\profile_verification.test.js`: 12/12 bestanden
- Firestore-/Storage-Emulatortests: 10/10 bestanden
- `flutter analyze --no-pub`: keine Probleme
- `git diff --check`: bestanden

## Noch nicht veröffentlicht

Vor einem Deploy zuerst den aktuellen Firebase-Stand prüfen. Für die neuen Verifizierungsänderungen sind voraussichtlich gezielt erforderlich:

- Firestore Rules
- Storage Rules aus dem sechsseitigen Dokumenten-Upload
- `submitProfileVerification`
- `reviewProfileVerification`
- `cleanupProfileVerificationDocuments`

Keine weiteren Functions oder Dienste ungeprüft mitdeployen. Es wurde in diesem Arbeitsschritt kein Firebase-Deploy durchgeführt.

## Sinnvolle nächste Schritte

1. Den Dokumentenbereich auf dem Redmi visuell testen: kleine Anzeige, Tastatur, Datumsformat und Einzeiligkeit.
2. Gezielt Rules und die drei Verifizierungs-Functions deployen, erst nach ausdrücklicher Freigabe.
3. Mit einem freigegebenen Testkonto Upload, Einreichung, Prüfung und Ablauf simulieren.
4. Danach mögliche Erweiterungen entscheiden:
   - Erinnerungen 30/14/3 Tage vor Ablauf
   - gezielte Nachreichung nur betroffener Dokumente
   - Gültig-bis-Anzeige
   - Aufnahmequalitätsprüfung

## Start am anderen Rechner

```powershell
git clone https://github.com/sehmus-yildirim/carma-app.git C:\Projects\plaqa
cd C:\Projects\plaqa
git switch main
git pull --ff-only origin main
flutter pub get
```

Falls das Repository dort bereits vorhanden ist, nur `git pull --ff-only origin main` ausführen. Anschließend Codex bitten, zuerst `CODEX_HANDOFF.md` zu lesen und an diesem Stand weiterzumachen.
