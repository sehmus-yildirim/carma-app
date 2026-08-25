# plaqa Firebase Deploy Plan

Stand: 2026-08-25 CEST
Zielprojekt: `carma-a84e4`
Android-App: `plaqa`, Paket `de.plaqa.app`, Version `1.0.0+1`
iOS-App: `plaqa`, Bundle-ID `de.plaqa.app`, Version `1.0.0+1`
Play Store: sichtbare Version `1.0.0`, Versionscode `1`, interner Release
`1 (1.0.0)` aktiv
Functions: Cloud Functions 2nd Gen, Node.js 22, globale Region `europe-west3`

## Zweck und Statusregeln

Dieser Plan trennt den lokalen Quellstand vom nachweisbaren Live-Stand. Er ist
keine Deploy-Freigabe. Am 2026-08-25 wurden nach ausdruecklicher Freigabe die
drei gebrandeten Auth-E-Mail-Functions, die drei Postfach-Antwort-Functions und
der vollstaendige aktuelle Hosting-Stand gezielt deployt. Die vier benoetigten
E-Mail-Secrets sind sicher angebunden. Es wurden keine Rules oder Indexes
deployt, keine Builds hochgeladen und keine App veroeffentlicht.

- **Live bestaetigt**: Name und grundlegender Ressourcentyp wurden zuletzt am
  2026-08-25 direkt mit der Firebase-CLI, Firebase Console oder per HTTPS
  geprueft.
- **Live-Version offen**: Die Ressource existiert, ihre inhaltliche Gleichheit
  mit dem lokalen Code ist aber nicht belegt.
- **Lokal fertig**: Code und zuletzt dokumentierte lokale Pruefungen sind
  vorhanden; die Ressource ist nicht live gelistet.
- **Live-Status erneut pruefen**: Die Firebase-CLI kann den Inhalt oder die
  Console-Einstellung nicht verlaesslich vergleichen.
- **Blaze erforderlich**: Erstellen oder Aktualisieren einer Function erfordert
  einen aktiven Billing-/Blaze-Plan. Ein vorhandener Live-Name beweist nicht,
  dass ein erneuter Deploy ohne Blaze moeglich ist.

## Nachweise vom 2026-08-25

| Bereich | Nachweis | Ergebnis |
|---|---|---|
| Git | `git status`, Branch und Upstream read-only | `main` und `origin/main` zeigen vor dieser Dokumentaktualisierung auf `9db509fb93ab48ffb64a547bf01d558eb60cae4c`; der Arbeitsbaum war sauber |
| Projekt | `.firebaserc`, `firebase.json` | Zielprojekt exakt `carma-a84e4`; Functions, Firestore, Storage und Hosting korrekt zugeordnet |
| Android | Firebase SDK-Konfiguration read-only | Firebase Android-App fuer `de.plaqa.app` vorhanden; lokale Konfiguration zeigt auf die passende App; Debug- und Release-Zertifikate sind registriert, Werte werden nicht dokumentiert |
| Functions | `firebase functions:list --json` | Alle 29 Exports sind live und aktiv; drei gebrandete Auth-E-Mail-Functions laufen als Callables und drei Postfach-Antwort-Functions als Scheduler, jeweils v2, Node.js 22 in `europe-west3` |
| Indexes | `firebase firestore:indexes` | Alle sechs lokalen Composite Indexes sind live vorhanden, einschliesslich `social_posts` mit `isArchived` |
| Hosting | `firebase hosting:sites:list` und HTTPS | Site `carma-a84e4` live; `plaqa.de` und `auth.plaqa.de` erreichbar |
| Hosting-Inhalt | Inhaltsvergleich lokal gegen HTTPS | Startseite, Datenschutz, Kinderschutz, Community-Richtlinien, Nutzungsbedingungen, Kontoloeschung, Impressum, Meldestelle, Support, Partner und Auth-Action liefern HTTP 200 und stimmen mit den lokalen HTML-Dateien ueberein |
| Rules | CLI-Moeglichkeiten | Firestore-/Storage-Rules sind live in Benutzung, der veroeffentlichte Inhalt ist mit der CLI nicht sicher gegen lokal vergleichbar |
| Auth/App Check | lokaler Code und Firebase Console | Android-App `de.plaqa.app` nutzt Play Integrity; iOS-App `de.plaqa.app` ist mit App Attest und DeviceCheck registriert; Firestore, Storage und Authentication bleiben nicht erzwungen, Functions erzwingen App Check lokal nicht |
| iOS Push | Apple Developer und Firebase Cloud Messaging | Kombinierter Apple-Schluessel fuer APNs/DeviceCheck liegt ausserhalb von Git; APNs-Authentifizierungsschluessel fuer Entwicklung und Produktion hinterlegt; keine Push-Nachricht getestet |
| Auth-E-Mail und Postfaecher | Firebase Authentication, Secret Manager, IONOS und Apple Relay | benutzerdefiniertes SMTP aktiv; tatsaechlicher Auth-Absender `no-reply@plaqa.de`; vier getrennte E-Mail-Secrets angebunden; drei Auth-Functions und drei Postfach-Scheduler live; Testnachrichten im normalen Posteingang und visuell in Outlook geprueft; fruehere IONOS-Textantworten deaktiviert; Apple-Relay-Quelle registriert |
| Play Console | vom Nutzer freigegebene Console-Aktion und anschliessende Geraetebestaetigung | Signierter Release `1 (1.0.0)` mit Versionscode `1` ist ausschliesslich im internen Track aktiv; Liste `plaqa interne Tester` enthaelt einen freigegebenen Tester; Teilnahme-Link und Redmi-Installation sind bestaetigt; keine Produktion |
| App Store Connect | read-only Kontrolle und freigegebene Entwurfsreihenfolge | Version `1.0.0` bleibt in Vorbereitung; je acht iPhone- und iPad-Screenshots verarbeitet und geordnet; Privacy Labels mit 19 Datentypen unveroeffentlicht; kein Build, TestFlight, Review oder Release |

## Letzter dokumentierter lokaler Pruefstand

Aktueller dokumentierter Stand:

- Vollstaendiger Flutter-Testlauf am 2026-08-25, 207 Tests: bestanden.
- `flutter analyze --no-pub` am 2026-08-25: ohne Befund.
- 11 produktive Functions-JavaScript-Dateien: Syntaxcheck bestanden.
- 8 Functions-Testdateien, 86 Tests: bestanden.
- 11 Rules-Testdateien, 14 Suites, 97 Tests: bestanden.
- Debug-APK und signiertes Release-AAB: erfolgreich gebaut.
- AAB-Signatur und Upload-Keystore: erfolgreich abgeglichen.

Vor einem Release sind die statischen Pruefungen nach den letzten
Codeaenderungen erneut auszufuehren.

## Lokales Functions-Inventar

Alle 29 Exports stehen in `functions/index.js`. Die Tabelle und die
Deploy-Gruppen darunter bilden gemeinsam die Deploy-Matrix: jede Function ist
hier einzeln erfasst; Befehl, Abhaengigkeiten, Live-Test, Risiko und Rueckfall
stehen in der referenzierten Gruppe.

| Ressource | Typ / lokaler Trigger | Quelle / lokaler Test | Live-Status 2026-08-25 | Blaze | Console / App Check | Gruppe |
|---|---|---|---|---|---|---|
| `syncProfilePhotoReferences` | Firestore Update `public_profiles/{userId}` | `profile_photo_sync.js` / Test vorhanden | live und aktiv; Firestore-Update-Trigger bestaetigt | Ja | kein App-Check-Token bei Event-Trigger | F1 |
| `syncProfileVisibilityReferences` | Firestore Write `users/{userId}/settings/visibility` | `profile_vehicle_management.js` / Test vorhanden | live und aktiv; Firestore-Write-Trigger bestaetigt | Ja | kein App-Check-Token bei Event-Trigger | F1 |
| `searchPlate` | Callable | `plate_search.js` / Test vorhanden | live, Versionsgleichheit offen | Ja | App Check vor Erzwingung testen | F2 |
| `recordProfileView` | Callable | `index.js` / kein eigener Function-Test | live und aktiv | Ja | App Check vor Erzwingung testen | F3 |
| `submitPlateHint` | Callable | `report_submission.js` / Rules-Tests, kein eigener Function-Test | live und aktiv | Ja | Storage/Rules und App Check abgleichen | F3 |
| `requestAccountDeletion` | Callable | `account_security.js` / Test vorhanden | live, Versionsgleichheit offen | Ja | Auth-Reauth und App Check pruefen | F4 |
| `revokeAccountSessions` | Callable | `account_security.js` / Test vorhanden | live, Versionsgleichheit offen | Ja | Auth-Reauth und App Check pruefen | F4 |
| `sendBrandedPasswordResetEmail` | Callable | `branded_email.js` / Test vorhanden | live und aktiv; v2, Node.js 22, `europe-west3`; Secret-Version 1 | Ja | SMTP-Secret; App Check bleibt Monitoring | F10 |
| `sendBrandedEmailVerification` | Callable | `branded_email.js` / Test vorhanden | live und aktiv; v2, Node.js 22, `europe-west3`; Secret-Version 1 | Ja | SMTP-Secret; Auth erforderlich; App Check bleibt Monitoring | F10 |
| `sendBrandedEmailChangeVerification` | Callable | `branded_email.js` / Test vorhanden | live und aktiv; v2, Node.js 22, `europe-west3`; Secret-Version 1 | Ja | SMTP-Secret; frische Reauth; App Check bleibt Monitoring | F10 |
| `submitProfileVerification` | Callable | `profile_verification.js` / Test vorhanden | live und aktiv | Ja | Admin-/Dokumentenprozess und App Check | F5 |
| `reviewProfileVerification` | Callable | `profile_verification.js` / Test vorhanden | live und aktiv | Ja | vertrauenswuerdiger Admin-Claim erforderlich | F5 |
| `saveProfileVehicle` | Callable | `profile_vehicle_management.js` / Test vorhanden | live und aktiv | Ja | App Check vor Erzwingung testen | F6 |
| `setPrimaryProfileVehicle` | Callable | `profile_vehicle_management.js` / Test vorhanden | live und aktiv | Ja | App Check vor Erzwingung testen | F6 |
| `deactivateProfileVehicle` | Callable | `profile_vehicle_management.js` / Test vorhanden | live und aktiv | Ja | App Check vor Erzwingung testen | F6 |
| `updatePrimaryVehicleLocation` | Callable | `profile_vehicle_management.js` / Test vorhanden | live und aktiv | Ja | Standort- und App-Check-Konfiguration | F6 |
| `requestMfaRecovery` | Callable | `mfa_recovery.js` / Test vorhanden | live, Versionsgleichheit offen | Ja | `enforceAppCheck: false`; Admin-/Recovery-Prozess | F7 |
| `getMfaRecoveryStatus` | Callable | `mfa_recovery.js` / Test vorhanden | live, Versionsgleichheit offen | Ja | `enforceAppCheck: false` | F7 |
| `listMfaRecoveryCases` | Callable | `mfa_recovery.js` / Test vorhanden | live, Versionsgleichheit offen | Ja | Admin-Claim; `enforceAppCheck: false` | F7 |
| `openMfaRecoveryCase` | Callable | `mfa_recovery.js` / Test vorhanden | live, Versionsgleichheit offen | Ja | Admin-Claim; `enforceAppCheck: false` | F7 |
| `markMfaRecoveryIdentityVerified` | Callable | `mfa_recovery.js` / Test vorhanden | live, Versionsgleichheit offen | Ja | Admin-Claim; Vier-Augen-Prozess offen | F7 |
| `reviewMfaRecovery` | Callable | `mfa_recovery.js` / Test vorhanden | live, Versionsgleichheit offen | Ja | Admin-Claim; `enforceAppCheck: false` | F7 |
| `requestVehicleHeroImage` | Callable | `index.js` / kein eigener Function-Test | live, Versionsgleichheit offen | Ja | Google-AI-/Vertex-AI-API, Budget, App Check | F8 |
| `maintainChatStories` | Scheduler, jede Minute UTC | `index.js` / kein eigener Function-Test | live als Scheduler; Zeitplanversion erneut pruefen | Ja | Cloud Scheduler/API und Budget | F9 |
| `maintainPlateHints` | Scheduler, alle 60 Minuten UTC | `report_cleanup.js` / Rules-Tests, kein eigener Function-Test | live und aktiv; Scheduler-Trigger bestaetigt | Ja | Cloud Scheduler/API und Storage | F3 |
| `cleanupProfileVerificationDocuments` | Scheduler, taeglich 04:30 Europe/Berlin | `profile_verification.js` / Test vorhanden | live und aktiv; Scheduler-Trigger bestaetigt | Ja | Cloud Scheduler/API; Dokumentenfreigabe haengt davon ab | F5 |
| `processSupportMailboxAutoReplies` | Scheduler, alle 5 Minuten | `mailbox_auto_reply.js` / Test vorhanden | live und aktiv; v2, Node.js 22, `europe-west3` | Ja | Secret `PLAQA_SUPPORT_MAILBOX_PASSWORD`; Scheduler/IMAP/SMTP | F11 |
| `processPrivacyMailboxAutoReplies` | Scheduler, alle 5 Minuten | `mailbox_auto_reply.js` / Test vorhanden | live und aktiv; v2, Node.js 22, `europe-west3` | Ja | Secret `PLAQA_PRIVACY_MAILBOX_PASSWORD`; Scheduler/IMAP/SMTP | F11 |
| `processPartnersMailboxAutoReplies` | Scheduler, alle 5 Minuten | `mailbox_auto_reply.js` / Test vorhanden | live und aktiv; v2, Node.js 22, `europe-west3` | Ja | Secret `PLAQA_PARTNERS_MAILBOX_PASSWORD`; Scheduler/IMAP/SMTP | F11 |

### Funktionsabdeckung

- **Vollstaendige Kontoloeschung** und **Sitzungswiderruf**: F4. Die Functions
  sind live gelistet; vollstaendige Datenwirkung und Token-Widerruf brauchen
  ein ausdruecklich freigegebenes Testkonto.
- **MFA-Recovery und Admin-Prozess**: F7. Live gelistet, aber App Check ist
  bewusst aus und Vier-Augen-/Admin-Betrieb bleibt organisatorisch offen.
- **Profilbild- und Anzeigenamen-Synchronisierung**: F1. Beide Functions sind
  live; der Firestore-Trigger von `syncProfilePhotoReferences` ist bestaetigt.
- **Dokumenten-Ablauferinnerungen 30/14/3 Tage**: Bestandteil von F5 und durch
  `cleanupProfileVerificationDocuments` angestossen; Function ist live, der
  Datenwirkungs-Livetest bleibt offen.
- **Social Posts, Likes, Kommentare und Antworten**: keine eigene Function;
  Firestore Rules und die sechs Live-Indexes sichern den Datenpfad. Ein
  Mehrkonten-Livetest bleibt offen.
- **Sicherheits- und Kinderschutzmeldungen**: Firestore-/Storage-Rules,
  Supportpfade sowie F3 (`submitPlateHint`/Cleanup). Callable und Cleanup sind
  live; der ausdruecklich freigegebene Live-Test bleibt offen.
- **Gebrandete Postfach-Antworten**: F11. Die drei Scheduler sind live und ihre
  Vorlagen wurden visuell geprueft; reale Eingangsmail, Thread-Zuordnung,
  Deduplizierung und wiederholter Schedulerlauf bleiben Ende-zu-Ende zu testen.

## Deploy-Gruppen und Rueckfallplan

Die Befehle sind Referenz. F10 und F11 wurden am 2026-08-25 nach sicherer
Secret-Einrichtung und gesonderter Freigabe ausgefuehrt. Alle 29 Functions sind
live; die funktionalen Auth- und Postfach-Livetests bleiben getrennt offen.

| Gruppe | Geplanter Befehl | Abhaengigkeiten | Anschliessender Live-Test | Risiko / Rueckfall |
|---|---|---|---|---|
| F1 Profilreferenzen | `firebase deploy --project carma-a84e4 --only functions:syncProfilePhotoReferences,functions:syncProfileVisibilityReferences` | Blaze, Firestore API; Live-Trigger ist bestaetigt | Profilbild, Anzeigename und Sichtbarkeit mit zwei Testkonten aendern; Posts, Likes, Kommentare, Chats, Storys und Fahrzeuge pruefen | Fan-out-Schreibfehler; Logs begrenzt pruefen, bei Regression vorherigen Git-Stand der Functions einzeln redeployen |
| F2 Kennzeichensuche | `firebase deploy --project carma-a84e4 --only functions:searchPlate` | Blaze, Rules, Fahrzeugdaten, Standort | zwei Konten, 5-km-Radius, Standort max. 60 Minuten, Sichtbarkeit | Suche blockiert oder Datenleck; vorherige Function-Version einzeln redeployen |
| F3 Statistik und Meldungen | `firebase deploy --project carma-a84e4 --only functions:recordProfileView,functions:submitPlateHint,functions:maintainPlateHints` | Blaze, Rules/Storage, Scheduler API; eigene Tests fuer alle drei vervollstaendigen | Aufrufzaehler, Meldung mit/ohne Bild, Rate-Limit, Ablauf/Cleanup | Zaehler-/Meldungsfehler oder verwaiste Medien; betroffene Function einzeln auf vorherigen Commit zuruecksetzen |
| F4 Konto und Sitzungen | `firebase deploy --project carma-a84e4 --only functions:requestAccountDeletion,functions:revokeAccountSessions` | Blaze, Auth/Admin SDK, Rules/Storage, freigegebenes Testkonto | Reauth fuer E-Mail/Google, vollstaendige Datenmatrix, erneute Anmeldung nach Token-Widerruf | irreversible Testkontoloeschung; nur Testkonto, bei Codefehler vorherige Function-Version redeployen |
| F5 Profilverifizierung | `firebase deploy --project carma-a84e4 --only functions:submitProfileVerification,functions:reviewProfileVerification,functions:cleanupProfileVerificationDocuments` | Blaze, Rules/Storage, Scheduler API, Admin-Claim, rechtliche Dokumentenfreigabe | Upload, Einreichung, Ablehnung, Nachreichung, 30/14/3-Erinnerungen, Ablauf, 30-Tage-Cleanup | sensible Dokumente oder zu fruehe Loeschung; Testdaten, Scheduler bei Fehler deaktivieren und vorherige Version redeployen |
| F6 Fahrzeuge | `firebase deploy --project carma-a84e4 --only functions:saveProfileVehicle,functions:setPrimaryProfileVehicle,functions:deactivateProfileVehicle,functions:updatePrimaryVehicleLocation` | Blaze, Rules, Search-Indexdaten, Standortberechtigung | zwei Fahrzeuge getrennt speichern, Hauptfahrzeug, Deaktivierung, alle aktiven Kennzeichen suchen | Profil-/Suchprojektion inkonsistent; Schreibtests stoppen und vorherige Function-Version redeployen |
| F7 MFA-Recovery | `firebase deploy --project carma-a84e4 --only functions:requestMfaRecovery,functions:getMfaRecoveryStatus,functions:listMfaRecoveryCases,functions:openMfaRecoveryCase,functions:markMfaRecoveryIdentityVerified,functions:reviewMfaRecovery` | Blaze, Identity Platform/SMS-MFA, Admin-Claims, vertrauenswuerdige Admin-Umgebung, App Check im Monitoring | Antrag, Pruefung, Genehmigung/Ablehnung, Token-Widerruf, Audit | Konto-Uebernahme-Risiko; App Check nicht blind erzwingen, Recovery sperren und vorherige Version redeployen |
| F8 KI-Fahrzeugbild | `firebase deploy --project carma-a84e4 --only functions:requestVehicleHeroImage` | Blaze, Google-AI-/Vertex-AI-API, Budget/Quota, Storage Rules | Rate-Limit, Kosten, Bildpfad, Wiederholung und Loeschung | Kosten oder falsche Medien; Function deaktivieren/alte Version redeployen, keine Massenanforderung |
| F9 Story-Cleanup | `firebase deploy --project carma-a84e4 --only functions:maintainChatStories` | Blaze, Scheduler API, Story-Indexes | Ablauf nach 24 Stunden, Backfill, geloeschte Medien/Docs | zu fruehe Loeschung; Scheduler stoppen und vorherige Version redeployen |
| F10 Gebrandete Auth-E-Mails | `firebase deploy --project carma-a84e4 --only functions:sendBrandedPasswordResetEmail,functions:sendBrandedEmailVerification,functions:sendBrandedEmailChangeVerification` | Blaze, Secret `PLAQA_NOREPLY_SMTP_PASSWORD`, IONOS SMTP, Auth-Action-Domain | Reset ohne Kontenoffenlegung, Verifizierung und E-Mail-Wechsel mit freigegebenem Testkonto; Zustellung und Linkwirkung einzeln pruefen | Versandstoerung; App-Client erst nach Function-Deploy ausrollen, bei Fehler vorherigen App-Stand beziehungsweise Firebase-Fallback verwenden |
| F11 Gebrandete Postfach-Antworten | `firebase deploy --project carma-a84e4 --only functions:processSupportMailboxAutoReplies,functions:processPrivacyMailboxAutoReplies,functions:processPartnersMailboxAutoReplies` | Blaze, Scheduler, IONOS IMAP/SMTP und drei getrennte Mailbox-Secrets | Je eine reale externe Eingangsmail, korrekter Antwortthread, Absender, Deduplizierung und erneuter Schedulerlauf | Antwortschleife oder Doppelversand; betroffene Function deaktivieren beziehungsweise vorherigen Stand einzeln redeployen und IONOS-Antwort nicht parallel aktivieren |

## Nicht-Function-Ressourcen

| Ressource | Lokale Datei / Stand | Lokaler Test | Live-Status | Blaze | Console / App Check | Geplanter Befehl, Abhaengigkeit, Live-Test und Rueckfall |
|---|---|---|---|---|---|---|
| Firestore Rules | `firestore.rules` | letzter Voll-Lauf in 97 Rules-Tests bestanden | **Live-Status erneut pruefen**; Inhalt nicht per CLI verglichen | Nein | App Check ersetzt keine Rules | `firebase deploy --project carma-a84e4 --only firestore:rules`; vorher Rules-Test wiederholen; danach Eigentuemer/Teilnehmer/Aussenstehende/Admin testen; Rollback ueber vorheriges Rules-Release |
| Storage Rules | `storage.rules` | letzter Voll-Lauf in 97 Rules-Tests bestanden | **Live-Status erneut pruefen**; Inhalt nicht per CLI verglichen | Nein | App Check ersetzt keine Rules | `firebase deploy --project carma-a84e4 --only storage`; vorher Rules-Test wiederholen; danach Profil-, Post-, Chat-, Fahrzeug-, Melde- und Dokumentmedien testen; Rollback ueber vorheriges Rules-Release |
| Firestore Indexes | `firestore.indexes.json`, sechs Definitionen | Query-Abgleich lokal dokumentiert | **alle sechs live bestaetigt** | Nein | keine | aktuell kein Deploy; bei Aenderung `firebase deploy --project carma-a84e4 --only firestore:indexes`; Query testen; additive Indexe nicht vorschnell loeschen |
| Firebase Hosting | `hosting/`, Site `carma-a84e4` | aktueller HTML-Inhaltsvergleich bestanden | Vollstaendiger aktueller Hosting-Stand live; alle geprueften plaqa- und Auth-Ziele liefern HTTP 200 und stimmen mit lokal ueberein | Nein | Custom Domains/DNS in Console | Bei kuenftigen Aenderungen `firebase deploy --project carma-a84e4 --only hosting`; alle URLs/Assets testen; Rollback ueber Hosting-Release-Historie |
| App Check | `firebase_app_check`; Debug nutzt Debug-Provider, Android Release Play Integrity, iOS Release App Attest mit DeviceCheck-Fallback | gezielte Tests und kompletter Flutter-Testlauf bestanden | Android und iOS `de.plaqa.app` registriert; iOS App Attest/DeviceCheck aktiv; Firestore, Storage und Authentication nicht erzwungen; Functions lokal ohne Enforcement | Functions-Aktualisierung: Ja | Android- und iOS-Geraete-/Metriktest bleibt offen | kein CLI-Deploy; Debug-Token, Play Integrity und App Attest/DeviceCheck live pruefen, erst danach pro Produkt erzwingen; bei legitimen Blockaden Enforcement sofort deaktivieren |
| Authentication | E-Mail/Passwort und Google lokal implementiert; Android-App `de.plaqa.app` registriert | statisch vorhanden | Providerstatus erneut in Console pruefen | Nein, Identity-Platform-Funktionen koennen Billing erfordern | Google-Provider, E-Mail-Provider, autorisierte Domains, SHA und OAuth-Branding | Console-Aenderungen einzeln; Registrierung/Login/Reset/Emailwechsel testen; alte Android-Clients bis zum Abschluss behalten |
| SMS-MFA | Enrollment, Login, Entfernen und Recovery lokal implementiert | lokale MFA-Tests vorhanden; Live-Flows frueher begonnen | Identity-Platform-/SMS-MFA-, Quota- und Billingstatus erneut pruefen | voraussichtlich ja fuer produktiven Umfang | SMS-Regionen, Quota, SHA, Testnummern, Datenschutz | kein Firebase-Deploy fuer Provider; alle E-Mail-/Google-MFA-Flows mit Testkonto pruefen; bei Fehler MFA nicht freigeben |
| Auth-E-Mails / Action-Domain | gebrandete HTML-/Textvorlagen und drei Callable Functions; `auth.plaqa.de/auth/action` live erreichbar | Rendering-, Rate-Limit- und Functions-Tests bestanden; fruehere SMTP-Testmail von `no-reply@plaqa.de` zugestellt | Firebase-Custom-SMTP und Action-Domain aktiv; F10 live und an Secret-Version 1 gebunden; Apple-Relay-Quelle registriert | Functions: Ja | jeden Kontofluss mit freigegebenem Testkonto pruefen; App Check bleibt Monitoring | bei Fehler keine neue App-Version ausrollen und den bisherigen Firebase-Versand als Fallback beibehalten |
| Postfach-Antworten | `mailbox_auto_reply.js`, drei HTML-/Textvorlagen und drei Scheduler | Parsing-, Absender-, Thread- und Deduplizierungstests bestanden; Designs mit Testnachrichten geprueft | F11 live und an drei getrennte Mailbox-Secrets gebunden; IONOS-Textantworten deaktiviert | Functions: Ja | reale externe Eingangsmails und Schedulerwirkung pruefen | bei Schleife/Doppelversand betroffene Scheduler-Function deaktivieren; nie IONOS- und Function-Antwort parallel aktivieren |

## Sichere Reihenfolge

1. Blaze ist aktiv; Billing-Budgetwarnungen, Kosten und benoetigte APIs weiter
   kontrollieren.
2. Alle 29 Functions sind live. F10 und F11 sind an vier geschuetzte
   E-Mail-Secrets gebunden; vor einer App-Freigabe bleiben die drei Auth-Flows
   und drei Postfach-Flows einzeln zu testen.
3. Firestore- und Storage-Rules nach erneutem Emulatorlauf gezielt deployen;
   sechs Indexe sind bereits live und werden nicht erneut deployed.
4. Die live vorhandenen Functions erst mit ausdruecklich freigegebenen
   Testkonten gruppenweise funktional pruefen.
5. App Check fuer Debug und Release weiterhin nur im Monitoring betreiben.
6. Ausschliesslich ausdruecklich freigegebene Testkonten und Testdokumente
   verwenden.
7. Berechtigungs-, Datenwirkungs-, Kosten- und Function-Log-Pruefungen je
   Gruppe abschliessen.
8. App Check erst nach erfolgreichen Geraete- und Mehrkontentests schrittweise
   erzwingen.
9. Der interne Release ist aktiv und auf dem Redmi installiert. Geschlossene
   Testphase, Einreichung und Produktion bleiben getrennte, freizugebende
   Schritte.

## Erforderliche Live-Tests

- Konto: E-Mail-/Google-Reauth, vollstaendige Loeschmatrix und Token-Widerruf.
- MFA: Enrollment, E-Mail-/Google-Login, Entfernen, Recovery, Admin-Claim und
  Audit; App Check zunaechst nur beobachten.
- Profile: Bild-/Anzeigenamen-/Sichtbarkeitssynchronisierung einschliesslich
  vorhandener Likes, Kommentare und Antworten.
- Fahrzeuge: Speichern, mehrere Fahrzeuge, Hauptfahrzeug, Deaktivierung,
  Standort und Kennzeichensuche.
- Dokumente: Upload/Vorschau, Einreichung, Pruefung, Nachreichung,
  30/14/3-Erinnerungen, Ablauf und Cleanup.
- Social: Feed-Sichtbarkeit, Follow/Unfollow, Likes, Kommentare, Antworten,
  Meldung und Blockierung mit mindestens zwei Konten.
- Medien/Rules: Eigentuemerkontrolle und verweigerte Fremdzugriffe fuer alle
  Storage-Pfade.
- Hosting/Auth: alle Rechtsseiten sowie Verifikation, Passwort-Reset,
  E-Mail-Aenderung und Wiederherstellung ueber `auth.plaqa.de`.
- Postfaecher: reale Eingangsmails an Support, Datenschutz und Partnerschaften,
  Antwortthread, Deduplizierung und wiederholten Schedulerlauf pruefen.

## Release-Risiken und offene Freigaben

- Blaze/Billing ist aktiv; Budgetwarnungen und laufende Kosten bleiben vor
  weiteren Function-Updates zu kontrollieren.
- Firestore- und Storage-Live-Rules sind inhaltlich noch nicht verglichen.
- Der aktuelle Hosting-Stand ist live und lokal gleich; fachliche oder
  rechtliche Textkorrekturen erfordern einen neuen gezielten Hosting-Deploy.
- App Check ist fuer die finalen Android- und iOS-Apps registriert und bleibt im
  Monitoring; Erzwingung darf erst nach Provider-/Geraetetest erfolgen.
- iOS-APNs ist fuer Entwicklung und Produktion konfiguriert; echte Zustellung,
  Tokenrotation und Navigation nach Antippen bleiben ungeprueft.
- Mehrere Functions besitzen keinen eigenen Function-Test.
- Dokumentenverifizierung bleibt bis zum Cleanup-Livetest und zur externen
  Rechtspruefung gesperrt.
- Interner Release `1 (1.0.0)` ist aktiv und auf dem Redmi installiert; dies
  ersetzt weder Funktions-Livetests noch die erforderliche geschlossene
  Testphase mit mindestens 12 Testern ueber mindestens 14 Tage.
- Kein offener oder geschlossener Test und kein Produktionsrelease sind aktiv;
  die App ist nicht oeffentlich veroeffentlicht.
- Keine Produktionsdaten, Backfills, Testloeschungen oder pauschalen
  Functions-Deploys ohne getrennte Freigabe.

## Interne technische Namen

`carma-a84e4` bleibt die interne Firebase-Projekt-ID. Der vorhandene
Keystore-Alias `carma` bleibt als technische Signaturkennung unveraendert.
Beide Werte sind keine sichtbaren Produktnamen und duerfen nicht eigenmaechtig
umbenannt oder neu erzeugt werden.
