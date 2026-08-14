# plaqa Codex handoff

Stand: 15. August 2026

## Projekt

- Lokaler Projektpfad auf diesem Rechner: `C:\Users\Postkiosk am ZOB\Documents\ChatGPT\plaqa`
- Veröffentlichter Arbeitsbranch: `codex/document-verification`
- GitHub-Remote: `https://github.com/sehmus-yildirim/carma-app.git`
- Firebase-Projekt: `carma-a84e4`
- Produktname: `plaqa`
- Domain: `plaqa.de`
- Kontakt: `info@plaqa.de`

Die alten technischen GitHub- und Firebase-IDs wurden noch nicht migriert. Nicht allein wegen des alten Namens ein neues Firebase-Projekt anlegen.

## Aktueller Arbeitsbereich

Einstellungen -> Profil & Verifizierung -> Dokumente hochladen.

## Umgesetzter Stand

- Der Ladefehler beim Tippen auf Ablaufdatum oder `UNBEDINGT LESEN!` wurde behoben. Der eingebettete Verifizierungsbildschirm behält jetzt seinen State.
- Ablauf-Erinnerungen sind für 30, 14 und 3 Tage vor Ablauf vorbereitet:
  - private In-App-Benachrichtigungen
  - private FCM-Geräteregistrierung
  - tägliche Serverfunktion mit idempotenter Zustellung
- Status pro Dokumentseite: hochgeladen, in Prüfung, bestätigt, abgelehnt und abgelaufen.
- Ablehnungsgründe werden pro Dokumentseite angezeigt.
- Gezielte Nachreichung ist möglich; bereits bestätigte Nachweise bleiben gesperrt und erhalten.
- Sichere private Dokumentvorschau aus Firebase Storage, ohne öffentliche Download-URL und ohne dauerhafte Galerieablage.
- Verifizierungsverlauf zeigt Einreichung, Prüfung, Gültigkeit, erneute Prüfung und Dokumentlöschung, aber keine internen Prüferdaten.
- Ausweistypen:
  - Personalausweis: Vorder- und Rückseite
  - Reisepass: nur Datenseite
  - Aufenthaltstitel: Vorder- und Rückseite
- Fahrzeugnachweise sind eindeutig dem ausgewählten Fahrzeug zugeordnet.
- Entwürfe und zuletzt bearbeiteter Abschnitt werden gespeichert und nach einem App-Neustart fortgesetzt.
- Datenschutzübersicht erklärt Prüfzugriff, Speicherung, Löschung und öffentlich übernommene Daten.
- Bei abgelehnten Nachweisen kann ein technisch zugeordneter Supportfall ohne Dokumentbild angelegt werden.
- Interne Verifizierungsstufen: Identität, Führerschein, Fahrzeug und vollständig verifiziert. Öffentlich bleibt nur das einfache Verifiziert-Badge.
- Private Dokumentdateien werden nach der Aufbewahrungsfrist gelöscht; Prüfstatus und Verlauf bleiben erhalten.
- Firestore- und Storage-Regeln schützen bestätigte Dokumentseiten, Gerätetokens, private Stufen und Support-Verknüpfungen.

## Letzte Prüfungen

- `flutter analyze --no-pub`: keine Probleme
- Gesamte Flutter-Testsuite: 145/145 bestanden
- Gesamte Cloud-Functions-Testsuite: 59/59 bestanden
- Gezielte Firestore-/Storage-Verifizierungstests: 13/13 bestanden
- Der danach gestartete gemeinsame Lauf aller zehn Regeltestdateien blieb beim Emulator-Aufräumen hängen und wurde beendet. Der neu ergänzte einzelne Support-Verknüpfungstest sollte beim nächsten Arbeitsschritt noch separat ausgeführt werden.
- `git diff --check`: bestanden
- Es wurde kein Firebase-Deploy durchgeführt.

## Vor Produktivbetrieb erforderlich

Nach ausdrücklicher Freigabe gezielt prüfen und deployen:

- Firestore Rules
- Storage Rules
- `submitProfileVerification`
- `reviewProfileVerification`
- `cleanupProfileVerificationDocuments`
- `expireProfileVerifications`
- `sendProfileVerificationExpirationReminders`

Zusätzlich Firebase Cloud Messaging für Android/iOS im Projekt prüfen. Keine weiteren Functions oder Dienste ungeprüft mitdeployen.

## Sinnvolle nächste Schritte

1. Den neuen Support-Regeltest separat im Firebase-Emulator ausführen.
2. Die App auf dem Redmi komplett neu starten und den Dokumentenbereich visuell prüfen.
3. Upload, Vorschau, Entwurf-Fortsetzung, gezielte Nachreichung und Supportfall mit einem Testkonto testen.
4. Danach Rules und Verifizierungs-Functions erst nach ausdrücklicher Freigabe deployen.

## Stand auf einem anderen Rechner übernehmen

Wenn das Repository dort bereits vorhanden ist:

```powershell
Set-Location "C:\Pfad\zum\plaqa-Projekt"
git fetch origin
git switch codex/document-verification
git pull --ff-only origin codex/document-verification
flutter pub get
```

Beim ersten Herunterladen:

```powershell
git clone --branch codex/document-verification https://github.com/sehmus-yildirim/carma-app.git C:\Projects\plaqa
Set-Location "C:\Projects\plaqa"
flutter pub get
```

Anschließend Codex bitten, zuerst `CODEX_HANDOFF.md` zu lesen und an diesem Stand weiterzumachen.
