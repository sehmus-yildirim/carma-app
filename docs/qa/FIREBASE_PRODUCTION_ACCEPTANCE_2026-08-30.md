# Firebase-Produktionsabnahme

Stand: 2026-08-30
Projekt: `carma-a84e4`
Region: `europe-west3`
Ergebnis: **PASS mit bewusst fortgesetztem App-Check-Monitoring**

## Umfang

- Firestore- und Storage-Regeln mit dem aktiven Ruleset verglichen
- Firestore-Indizes und TTL-Konfiguration semantisch abgeglichen
- Functions lokal regressionsgetestet und gezielt deployt
- Callable-, HTTP- und Event-Trigger live kontrolliert
- Cloud-Scheduler- und Cleanup-Abläufe geprüft
- App-Check-Konfiguration und Sieben-Tage-Metriken ausgewertet
- Produktionslogs nach Deployment und Smoke-Tests geprüft

Hosting, Store-Artefakte und Store-Releases waren nicht Teil dieses Deployments.

## Regeln und Indizes

Die aktiven Rulesets sind nach Normalisierung bytegleich mit dem Repository:

| Ziel | SHA-256 |
|---|---|
| `firestore.rules` | `4065e51a7e0460860f1f5f607f8c330fafc862548857c32c478c4c7a9eff7cc0` |
| `storage.rules` | `492eca849713d0ddfa6c481e1af5da71568d930a59bc098f8d5911c1973fb5f7` |

Die sieben zusammengesetzten Indizes und sechs Feld-Overrides stimmen
semantisch mit Produktion überein. Der bereits live aktive TTL-Override fuer
`_verification_sessions.expiresAt` wurde in `firestore.indexes.json`
dokumentiert, damit kuenftige Deployments ihn erhalten.

Die vollstaendige Emulator-Suite bestand mit `113/113` Tests.

## Functions

- `40/40` lokale Exporte sind in Produktion vorhanden.
- `40/40` Functions sind `ACTIVE`.
- Alle laufen in `europe-west3` auf Node.js 22.
- Die Functions-Suite bestand unmittelbar vor Deployment mit `172/172` Tests.
- Alle `27` Callable Functions waren erreichbar und lehnten einen sicheren
  leeren, nicht angemeldeten Smoke-Request korrekt ab.
- Der anonyme Passwort-Reset-Pfad wies die leere Testadresse erwartungsgemaess
  als ungueltig zurueck.
- Der Website-Endpunkt akzeptierte den CORS-Preflight von `https://plaqa.de`
  mit HTTP 204 und wies ein leeres Formular mit HTTP 400 zurueck.
- Vier Event-Trigger zeigen auf die erwarteten Firestore-Pfade oder den
  Produktions-Bucket `carma-a84e4.firebasestorage.app`.

Ein beim Deployment sichtbarer Cold-Start-Speicherfehler von
`submitProfileVerification` wurde durch die Anpassung von 128 MiB auf 256 MiB
behoben. Die neue Revision ist aktiv, der geschuetzte Cold-Start-Smoke lieferte
den erwarteten HTTP-401-Status, und danach wurden keine Fehler protokolliert.

## Scheduler und Cleanup

Alle acht im Code definierten Scheduler-Jobs sind in Produktion vorhanden und
`ENABLED`:

- `maintainChatStories`
- `maintainPlateHints`
- `cleanupProfileVerificationDocuments`
- `expireProfileVerificationV1`
- `processSupportMailboxAutoReplies`
- `processPrivacyMailboxAutoReplies`
- `processPartnersMailboxAutoReplies`
- `cleanupMediaUploadReservations`

Die beiden neuen Jobs wurden kontrolliert manuell ausgelöst:

- `cleanupMediaUploadReservations`: HTTP 200, `deletedCount: 0`
- `expireProfileVerificationV1`: HTTP 200, eine Seite, keine faelligen
  Identitaeten oder Fahrzeuge, keine Fortsetzung erforderlich

Damit sind Berechtigung, Ziel, Laufzeit und idempotentes Leerlaufverhalten
nachgewiesen.

## App Check

- Android-App: `1:493803183324:android:c2194a10cc23274c896819`
- Provider: Play Integrity
- Token-Laufzeit: 3600 Sekunden
- Firestore, Storage, Authentication und OAuth bleiben global `UNENFORCED`.
- Sicherheitskritische Callable Functions erzwingen App Check bereits
  funktionsbezogen im Code.
- Reale Android-Aufrufe von `requestVehicleHeroImage` wurden mit
  `app=VALID` und `auth=VALID` protokolliert.

Sieben-Tage-Metrik bei der Abnahme:

| Dienst | gueltig | ungueltig | fehlend/unbekannt |
|---|---:|---:|---:|
| Firestore | 16.028 | 0 | 0 |
| Storage | 3 | 9 | 231 |
| Authentication | 21 | 0 | 0 |

Die globale Storage-Erzwingung wird deshalb noch nicht aktiviert. Zuerst muss
ein signierter Android-Build den gesamten Uploadpfad mit gueltigen Tokens
abdecken. Eine vorzeitige Erzwingung koennte legitime Uploads blockieren.

## Abschluss

Nach Deployment, Scheduler-Smoke und Callable-Smoke zeigten die aktuellen
Cloud-Run-Revisionen keine neuen Fehler. Die Firebase-Produktionsabnahme ist
fuer den aktuellen Backend-Stand abgeschlossen. Die spaetere globale
App-Check-Erzwingung bleibt ein eigener, metrikbasierter Release-Schritt.
