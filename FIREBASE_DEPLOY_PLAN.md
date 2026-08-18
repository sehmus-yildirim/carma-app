# plaqa Firebase Deploy Plan

Stand: 2026-08-19 01:33 CEST
Zielprojekt: `carma-a84e4`  
Functions-Region: `europe-west3`  
Functions-Runtime: Node.js 22, Cloud Functions 2nd Gen

## Statische Abschlusspruefung

Am 2026-08-18 wurde der lokale Codebestand zunächst ohne Emulatoren, Builds oder
Deploys geprueft:

- 31 Flutter-Testdateien mit insgesamt 169 Tests: bestanden.
- 9 produktive JavaScript-Dateien: `node --check` bestanden.
- 6 Functions-Testdateien mit insgesamt 68 Tests: bestanden.
- 23 Function-Exports, globale Region `europe-west3` und Node.js 22 bestaetigt.
- Functions-Modul lokal in rund 5,1 Sekunden geladen; keine top-level
  Netzwerk- oder KI-Anfrage gefunden. Der fruehere Deploy-Analyse-Timeout
  bleibt bis zum naechsten gezielten Deploy als Betriebsrisiko dokumentiert.
- `flutter analyze --no-pub`: keine Probleme gefunden.
- Oeffentliche und private Profildaten sowie Settings-Serialisierung statisch
  getrennt und durch vorhandene Tests abgesichert.
- App Check wird in den Functions noch nicht erzwungen und bleibt ein
  ausdruecklicher Releasepunkt.


## Emulator- und Build-Abschluss

Am 2026-08-19 wurde der lokale Abschluss aus Punkt 3 vollständig durchgeführt. Es wurde dabei nichts deployed und es wurden keine Live-Daten verändert.

- OpenJDK 21.0.10 aus Android Studio verwendet.
- Alle 11 Firestore-/Storage-Rules-Testdateien seriell ausgeführt.
- 14 Test-Suites mit insgesamt 97 Rules-Tests: 97 bestanden, 0 fehlgeschlagen.
- Debug-APK erfolgreich erzeugt.
- Release-AAB erfolgreich erzeugt (pp-release.aab, ca. 69,6 MB).
- Release-Signatur erfolgreich verifiziert; jarsigner Exit-Code 0.
- SHA-256 des AAB-Signaturzertifikats stimmt mit ndroid/upload-keystore.jks überein:
  77:A1:A1:05:35:61:8B:1F:C6:81:E5:AF:97:82:31:7A:00:1C:7B:C2:29:DE:E7:20:F3:1A:03:76:33:63:C7:BC.
- Build-Metadaten geprüft: App-Name plaqa, Paket com.carma.app, Launcher-Icons und Splash-Ressourcen vorhanden.
- Build-Artefakte blieben außerhalb von Git.
## Statusregeln

- **Bereits veröffentlicht**: Name, Region und Runtime wurden mit `firebase functions:list` oder der Hosting-Site read-only bestätigt. Die inhaltliche Versionsgleichheit mit dem lokalen Code ist damit nicht bewiesen.
- **Benötigt Blaze**: Die Ressource existiert nur lokal und benötigt für den erstmaligen Functions-Deploy einen aktiven Billing-/Blaze-Plan.
- **Rules-Deploy erforderlich**: Der lokale Stand ist laut Handoff neuer; Veröffentlichung erst nach vollständigem Emulatorlauf.
- **Status noch nicht sicher feststellbar**: Lokal vorhanden, aber der aktuelle Produktionsstand konnte mit der Firebase CLI nicht verlässlich verglichen werden.

## Projektzuordnung

| Bereich | Lokaler Wert | Bewertung |
|---|---|---|
| `.firebaserc` | `carma-a84e4` | korrekt |
| Android Firebase App | `carma-a84e4`, Paket `com.carma.app` | korrekt; technische ID beibehalten |
| Dart Firebase Options | `carma-a84e4` | korrekt |
| Functions | `functions`, Node.js 22 | korrekt |
| Firestore Rules | `firestore.rules` | lokal vorhanden |
| Storage Rules | `storage.rules` | lokal vorhanden |
| Firestore Indexes | `firestore.indexes.json` | vier lokale Composite Indexes |
| Hosting | Site `carma-a84e4`, Ordner `hosting` | live erreichbar |

## Functions-Inventar

Alle Functions verwenden über `setGlobalOptions` die Region `europe-west3`, `maxInstances: 1` und 2nd Gen. Jeder neue oder aktualisierte Functions-Deploy setzt Blaze/Billing voraus. Scheduler benötigen zusätzlich Cloud Scheduler; `requestVehicleHeroImage` benötigt außerdem die konfigurierte Google-AI-/Vertex-AI-Nutzung.

| Function | Trigger | Quelle / Test | Kategorie | Hinweis |
|---|---|---|---|---|
| `syncProfilePhotoReferences` | Firestore `public_profiles/{userId}` updated | `profile_photo_sync.js` / `profile_photo_sync.test.js` | Bereits veröffentlicht | CLI meldet live `https`, lokal ist es ein Firestore-Trigger; Trigger vor Update gezielt prüfen |
| `syncProfileVisibilityReferences` | Firestore `users/{userId}/settings/visibility` written | `profile_vehicle_management.js` / `profile_vehicle_management.test.js` | Benötigt Blaze | nur lokal gefunden |
| `searchPlate` | Callable | `plate_search.js` / `plate_search.test.js` | Bereits veröffentlicht | Versionsgleichheit nicht sicher feststellbar |
| `recordProfileView` | Callable | `index.js` / kein eigener Function-Test | Benötigt Blaze | vor Deploy gezielten Test ergänzen |
| `submitPlateHint` | Callable | `report_submission.js` / Rules-Tests, kein eigener Function-Test | Benötigt Blaze | Storage-/Firestore-Regeln gemeinsam prüfen |
| `requestAccountDeletion` | Callable | `account_security.js` / `account_security.test.js` | Bereits veröffentlicht | vollständige Löschung nur mit freigegebenem Testkonto live prüfen |
| `revokeAccountSessions` | Callable | `account_security.js` / `account_security.test.js` | Bereits veröffentlicht | Token-Widerruf live prüfen |
| `submitProfileVerification` | Callable | `profile_verification.js` / `profile_verification.test.js` | Benötigt Blaze | Dokumenten-Upload und Rules zuerst im Emulator prüfen |
| `reviewProfileVerification` | Callable | `profile_verification.js` / `profile_verification.test.js` | Benötigt Blaze | Admin-Claim und Datenschutz prüfen |
| `saveProfileVehicle` | Callable | `profile_vehicle_management.js` / `profile_vehicle_management.test.js` | Benötigt Blaze | blockiert aktuell echten Fahrzeug-Speicherpfad |
| `setPrimaryProfileVehicle` | Callable | `profile_vehicle_management.js` / `profile_vehicle_management.test.js` | Benötigt Blaze | mehrere Fahrzeuge live prüfen |
| `deactivateProfileVehicle` | Callable | `profile_vehicle_management.js` / `profile_vehicle_management.test.js` | Benötigt Blaze | Suche und Primärfahrzeug nach Deaktivierung prüfen |
| `updatePrimaryVehicleLocation` | Callable | `profile_vehicle_management.js` / `profile_vehicle_management.test.js` | Benötigt Blaze | Standortalter und Suchradius live prüfen |
| `requestMfaRecovery` | Callable | `mfa_recovery.js` / `mfa_recovery.test.js` | Bereits veröffentlicht | App Check ist lokal bewusst noch nicht erzwungen |
| `getMfaRecoveryStatus` | Callable | `mfa_recovery.js` / `mfa_recovery.test.js` | Bereits veröffentlicht | Versionsgleichheit nicht sicher feststellbar |
| `listMfaRecoveryCases` | Callable | `mfa_recovery.js` / `mfa_recovery.test.js` | Bereits veröffentlicht | Admin-Zugriff live prüfen |
| `openMfaRecoveryCase` | Callable | `mfa_recovery.js` / `mfa_recovery.test.js` | Bereits veröffentlicht | Admin-Zugriff live prüfen |
| `markMfaRecoveryIdentityVerified` | Callable | `mfa_recovery.js` / `mfa_recovery.test.js` | Bereits veröffentlicht | Vier-Augen-Prozess bleibt gesonderter Releasepunkt |
| `reviewMfaRecovery` | Callable | `mfa_recovery.js` / `mfa_recovery.test.js` | Bereits veröffentlicht | Token-Widerruf live prüfen |
| `requestVehicleHeroImage` | Callable | `index.js` / kein eigener Function-Test | Bereits veröffentlicht | AI-Kosten, Rate-Limit und Bildpfad live prüfen |
| `maintainChatStories` | Scheduler, jede Minute UTC | `index.js` / kein eigener Function-Test | Bereits veröffentlicht | Scheduler-Kosten und Löschverhalten prüfen |
| `maintainPlateHints` | Scheduler, alle 60 Minuten UTC | `report_cleanup.js` / kein eigener Function-Test | Benötigt Blaze | Cleanup zunächst mit gezieltem Test absichern |
| `cleanupProfileVerificationDocuments` | Scheduler, täglich 04:30 Europe/Berlin | `profile_verification.js` / `profile_verification.test.js` | Benötigt Blaze | Aufbewahrung und Ablauf mit Testdaten prüfen |

Bestätigt veröffentlicht: 12 von 23.  
Nur lokal bestätigt: 11 von 23.  
Die Versionsgleichheit veröffentlichter Functions mit dem lokalen Quellstand ist nicht sicher feststellbar.

## Rules, Indexes und Hosting

| Ressource | Kategorie | Nachweis / nächster Schritt |
|---|---|---|
| Firestore Rules | Rules-Deploy erforderlich | vollständiger Firestore-/Storage-Emulatorlauf bestanden; 97/97 Rules-Tests erfolgreich; lokaler Stand ist noch nicht gezielt veröffentlicht |
| Storage Rules | Rules-Deploy erforderlich | vollständiger Firestore-/Storage-Emulatorlauf bestanden; lokaler sechsseitiger Dokumenten-Upload ist noch nicht gezielt veröffentlicht |
| Firestore Indexes | Status noch nicht sicher feststellbar | vier lokale Indexes; Emulator- und Build-Prüfung erfolgreich, Produktionsgleichheit und tatsächlicher Query-Bedarf bleiben vor einem Deploy zu bestätigen |
| Firebase Hosting | Bereits veröffentlicht | Site `carma-a84e4`; `/auth/action` liefert über Standarddomain und `auth.plaqa.de` HTTP 200; lokaler Hosting-Stand ist im aktuellen `main` gespeichert |

## Empfohlene Deploy-Reihenfolge

Diese Befehle sind Dokumentation und werden erst nach separater Freigabe ausgeführt.

1. Rules nach bestandenem vollständigem Emulatorlauf:

```powershell
firebase deploy --project carma-a84e4 --only firestore:rules,storage
```

2. Indexes nur bei bestätigtem Bedarf und nach Prüfung der vier Definitionen:

```powershell
firebase deploy --project carma-a84e4 --only firestore:indexes
```

3. Profilverifizierung:

```powershell
firebase deploy --project carma-a84e4 --only functions:submitProfileVerification,functions:reviewProfileVerification,functions:cleanupProfileVerificationDocuments
```

4. Fahrzeugverwaltung:

```powershell
firebase deploy --project carma-a84e4 --only functions:saveProfileVehicle,functions:setPrimaryProfileVehicle,functions:deactivateProfileVehicle,functions:updatePrimaryVehicleLocation
```

5. Sichtbarkeit, Statistik und Hinweise, erst nach ergänzten gezielten Tests:

```powershell
firebase deploy --project carma-a84e4 --only functions:syncProfileVisibilityReferences,functions:recordProfileView,functions:submitPlateHint,functions:maintainPlateHints
```

6. Bereits veröffentlichte Functions nur aktualisieren, wenn ein lokaler Unterschied fachlich bestätigt wurde. Kein pauschaler Functions-Deploy.

7. Hosting nur bei einer absichtlichen Änderung der Auth-Seite oder späteren Website:

```powershell
firebase deploy --project carma-a84e4 --only hosting
```

## Live-Prüfung nach Deploy

- Rules: Eigentümer-, Außenstehender-, Admin- und Teilnehmerzugriffe; Upload und Löschung.
- Verifizierung: Upload, Vorschau, Einreichung, Ablehnung, Nachreichung, Ablauf und Cleanup.
- Fahrzeuge: Erstellen, Aktualisieren, Primärfahrzeug, Deaktivieren, alle Kennzeichen auffindbar.
- Suche: zweites aktives Konto, Standort höchstens eine Stunde alt, maximal 5 km, Sichtbarkeit und Kontaktfilter.
- Hinweise: Upload, Rate-Limit, Cleanup und keine verwaisten Dateien.
- Profilreferenzen: Profilbild und Anzeigename in Posts, Likes, Kommentaren, Chats, Anfragen und Storys.
- MFA-Recovery: Admin-Claims, App Check, Genehmigung/Ablehnung und Token-Widerruf.
- Hosting: Auth-Aktionslinks über `auth.plaqa.de`.

## Offene Risiken

- Blaze ist für neue oder aktualisierte Functions noch nicht aktiv.
- App Check ist im MFA-Recovery-Code bewusst noch nicht erzwungen.
- Andere Callables erzwingen App Check ebenfalls noch nicht durchgaengig; erst
  nach erfolgreichem Provider- und Geraetetest schrittweise aktivieren.
- `syncProfilePhotoReferences` weist zwischen CLI-Anzeige und lokalem Trigger eine ungeklärte Abweichung auf.
- Mehrere Functions besitzen keinen eigenen Function-Test.
- Firestore-/Storage-Produktionsversionen und lokale Versionen sind nicht sicher vergleichbar.
- Keine Produktionsdaten, Backfills oder pauschalen Deploys ohne getrennte Freigabe.
