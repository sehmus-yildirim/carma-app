# plaqa Release Checklist

Stand: 2026-08-25 CEST
App: `plaqa`
Android-Paket: `de.plaqa.app`
Version: `1.0.0+1`
Firebase-Projekt: `carma-a84e4`

## Statuslegende

- `[x]` nachgewiesen oder vom Nutzer in der zugehoerigen Console bestaetigt
- `[ ]` offen
- `[BLAZE]` benoetigt Billing/Blaze
- `[CONSOLE]` benoetigt eine aktuelle Console-Pruefung oder Konfiguration
- `[LIVE]` nur mit Testkonto, Geraet oder realem Backend pruefbar
- `[LEGAL]` externe rechtliche Pruefung erforderlich
- `[PERSON]` persoenliche Freigabe oder rechtlich bindende Bestaetigung
- `[BLOCKER]` muss vor Produktionsfreigabe erledigt sein

## Aktueller Arbeitsstand

- [x] Aktueller Branch: `main`.
- [x] `main` und `origin/main` zeigen vor dieser Dokumentaktualisierung auf
  Commit `9db509fb93ab48ffb64a547bf01d558eb60cae4c`.
- [x] Der Arbeitsbaum war vor dieser Dokumentaktualisierung sauber.
- [x] Keine History wurde umgeschrieben; kein Force-Push.

## Abgeschlossen

### App, Tests und Build

- [x] Anzeigename `plaqa`, Paket-ID/Namespace `de.plaqa.app` und Version
  `1.0.0+1` lokal bestaetigt.
- [x] Firebase Android-App fuer `de.plaqa.app` registriert; lokale
  `google-services.json` und `firebase_options.dart` zeigen auf die passende
  Android-App.
- [x] Debug- und Release-Zertifikate sind bei der neuen Android-App registriert;
  vollstaendige Fingerprints werden nicht dokumentiert.
- [x] Vollstaendiger Flutter-Lauf am 2026-08-25: 207 Tests bestanden.
- [x] Letzter dokumentierter Analyze-Lauf: `flutter analyze --no-pub` ohne
  Befund.
- [x] Functions-Lauf am 2026-08-25: Syntaxchecks der 11 produktiven
  JavaScript-Dateien und 8 Testdateien mit 86 Tests bestanden.
- [x] Letzter dokumentierter Rules-Lauf: 11 Testdateien, 14 Suites, 97 Tests
  bestanden.
- [x] Debug-APK und signiertes Release-AAB erfolgreich erzeugt.
- [x] AAB-Signatur und Upload-Keystore erfolgreich abgeglichen.
- [x] Neu gebautes Release-AAB am 2026-08-23: Paket `de.plaqa.app`, Version
  `1.0.0` (Code 1), SHA-256
  `987FC325A11A480268E6FE1D1936B451AC306E70AA22430597B8FA60EDAEF663`.
- [x] Build-Artefakte, Keystore und `android/key.properties` sind nicht in Git.

### Lokale Signatursicherung

- [x] Keystore-Kopie ausserhalb des Repositories im lokalen plaqa-Adminordner
  vorhanden.
- [x] Original- und lokale Backup-Datei haben denselben SHA-256-Dateihash.
- [x] `KEYSTORE_RECOVERY.md` ist im lokalen Signing-Backup vorhanden.
- [x] KeePassXC-Datenbank ist lokal eingerichtet; Signing-Eintraege wurden vom
  Nutzer gespeichert.
- [ ] Zweite, unabhaengige und verschluesselte Sicherung auf USB oder einem
  getrennten sicheren Datentraeger erstellen.

### Play Console

- [x] Privates Google-Play-Entwicklerkonto vorhanden und Identitaet bestaetigt.
- [x] App-Eintrag `plaqa` mit Paket `de.plaqa.app` vorhanden.
- [x] Testzugang `plaqa reviewer account` laut Nutzerangabe eingetragen.
- [x] Zielgruppe 16-17 und 18+ als Entwurf festgelegt; App richtet sich nicht
  speziell an Kinder.
- [x] IARC-Altersfreigabe bearbeitet und vom Nutzer akzeptiert.
- [x] Kinderschutzkontakt und Kinderschutz-Selbsterklaerungen vom Nutzer
  bestaetigt; oeffentlicher Standard vorhanden.
- [x] Datensicherheitsdeklaration als Entwurf gespeichert.
- [x] Das gepruefte AAB mit Versionscode `1` wurde am 2026-08-23 als interner
  Release `1 (1.0.0)` bereitgestellt.
- [x] Der interne Track ist aktiv und ausschliesslich fuer die ausgewaehlte
  Liste `plaqa interne Tester` mit aktuell einem freigegebenen Tester
  verfuegbar; die Tester-Adresse wird nicht im Repository dokumentiert.
- [x] Der Teilnahme-Link ist aktiv. Die Installation aus Google Play auf dem
  freigegebenen Redmi wurde vom Nutzer bestaetigt.
- [x] Bis zur ersten Store-Pruefung kann Google Play den temporaeren Namen
  `de.plaqa.app (unreviewed)` anzeigen.
- [x] Kein offener oder geschlossener Test und kein Produktionsrelease sind
  aktiv; die App ist nicht oeffentlich veroeffentlicht.
- [x] Acht freigegebene Smartphone-Screenshots wurden geprueft und am
  2026-08-23 geordnet in den Store-Entwurf hochgeladen.
- [x] Store-Texte, App-Icon, Feature-Grafik und Screenshots wurden gemeinsam
  nur als Entwurf gespeichert; nichts wurde eingereicht oder veroeffentlicht.

### Apple und App Store Connect

- [x] Apple-Developer-Mitgliedschaft als Privatperson ist aktiv.
- [x] Explizite App-ID `de.plaqa.app` ist registriert.
- [x] Sign in with Apple und Push Notifications sind im Apple-Portal aktiv.
- [x] Associated Domains ist fuer Version 1 im Apple-Portal deaktiviert und
  `applinks:plaqa.de` aus dem Runner-Entitlement entfernt; der aktuelle
  Client besitzt noch kein eingehendes Universal-Link-Routing.
- [x] Ein kombinierter Apple-Schluessel fuer DeviceCheck und APNs wurde
  ausserhalb des Repositories gesichert; Key- und Team-IDs werden nicht im
  Repository dokumentiert.
- [x] Firebase App Check fuer iOS verwendet App Attest und DeviceCheck; alle
  Firebase-Dienste bleiben ohne Erzwingung.
- [x] Der APNs-Authentifizierungsschluessel ist fuer Entwicklung und Produktion
  in Firebase Cloud Messaging hinterlegt; keine Push-Nachricht wurde getestet.
- [x] Der echte Firebase-SMTP-Absender ist `no-reply@plaqa.de`; eine Testmail
  wurde im normalen Posteingang empfangen.
- [x] `no-reply@plaqa.de` ist als Apple-Private-Email-Relay-Quelle registriert.
- [x] Ein separater Apple-Login-Schluessel wurde bewusst nicht erzeugt, weil
  der aktuelle native iOS-Firebase-Flow ihn nicht benoetigt.
- [x] Store-Texte, Privacy Labels, Review-Hinweise und Screenshotplan liegen
  lokal unter `store_assets/app_store/de-DE/` vor.
- [x] App-Store-Connect-Nutzungsbedingungen wurden persoenlich angenommen.
- [x] App-Eintrag `plaqa` mit SKU `plaqa-ios-1` und Apple-ID `6804814664`
  sowie die nicht rechtlich bindenden Metadaten wurden als Entwurf gespeichert.
  Kein Build-Upload, TestFlight, Review oder Release wurde gestartet.
- [x] Altersfreigabe 16+, Inhaltsrechte, Copyright `2026 Sehmus Yildirim`,
  Review-Kontakt und Review-Testkonto sind gespeichert.
- [x] App Privacy ist mit 19 Datentypen als unveroeffentlichter Entwurf
  vorhanden; finaler Build-Abgleich bleibt offen.
- [x] Je acht iPhone- und iPad-Screenshots sind verarbeitet, korrekt geordnet
  und als Entwurf gespeichert; acht iPad-JPEGs sind lokal archiviert.
- [ ] Universal Links nur nach neuer Produktentscheidung, AASA-Datei, Routing,
  erneuter Capability-Aktivierung, Xcode-/Provisioning- und Geraetetest als
  funktionsfaehig markieren.

### Legal-Inventar

- [x] 93 sichtbare In-App-Pruefmarker und insgesamt 95 sichtbare/provisorische
  Fundstellen fachlich bereinigt.
- [x] Offene persoenliche und rechtliche Entscheidungen stehen getrennt in
  `LEGAL_PLACEHOLDER_INVENTORY.md` und `docs/legal_release_inputs.md`.
- [x] Ein kompaktes externes Rechtspruefungsbriefing wurde erstellt.
- [x] Technische Firebase-Projekt-ID `carma-a84e4` und interner
  Keystore-Alias `carma` sind als interne Kennungen erklaert, nicht als
  sichtbare Produktnamen.

## Lokal fertig

- [x] 29 Functions-Exports in `functions/index.js`, global
  `europe-west3`, Node.js 22.
- [x] Gebrandete HTML- und Text-E-Mail-Vorlagen fuer Konto, Support,
  Datenschutz und Partnerschaften liegen lokal im gemeinsamen plaqa-Design vor.
- [x] Drei gebrandete Auth-E-Mail-Functions mit sicheren Firebase-Aktionslinks,
  IONOS-SMTP, gehashten Versandlimits und App Check im Monitoring sind lokal
  implementiert und getestet.
- [x] Drei gebrandete Postfach-Antwort-Functions fuer Support, Datenschutz und
  Partnerschaften sind mit sicherer Absenderpruefung, Deduplizierung und
  getrennten Secret-Manager-Passwoertern implementiert und getestet.
- [x] Account-Security-Code fuer Kontoloeschung und Sitzungswiderruf.
- [x] MFA-Enrollment, MFA-Login fuer E-Mail/Google, Entfernen und Recovery-Code.
- [x] Profilbild- und Anzeigenamen-Synchronisierung einschliesslich Social-
  Unterpfaden.
- [x] Fahrzeugverwaltung, Hauptfahrzeug, Deaktivierung und Standortupdate.
- [x] Dokumentenverifizierung mit Identitaets- und Fahrzeugscheinprozess.
- [x] Ablauf-Erinnerungen bei 30, 14 und 3 Tagen, Ablaufstatus und gezielte
  Nachreichung im Dokumenten-Cleanup vorbereitet.
- [x] Social Feed, Story-Leiste, Likes, Kommentare und Antworten lokal
  implementiert.
- [x] Sicherheits-, Melde- und Kinderschutzpfade lokal in Rules/UI vorhanden.
- [x] Firestore Rules, Storage Rules und sechs Composite Indexes lokal
  definiert.
- [x] App Check ist im Android-Code aktiv vorbereitet; Release nutzt Play
  Integrity, Debug den Debug-Provider und automatische Token-Aktualisierung.
- [x] Auth-Action-Handler unter `hosting/auth/action` lokal vorhanden.

## Veröffentlicht

### Functions

Am 2026-08-25 mit `firebase functions:list --json` read-only nachgewiesen. Die
Namens-/Triggerexistenz beweist nicht die Gleichheit mit dem lokalen Code.

- [x] `searchPlate`
- [x] `requestAccountDeletion`
- [x] `revokeAccountSessions`
- [x] `requestMfaRecovery`
- [x] `getMfaRecoveryStatus`
- [x] `listMfaRecoveryCases`
- [x] `openMfaRecoveryCase`
- [x] `markMfaRecoveryIdentityVerified`
- [x] `reviewMfaRecovery`
- [x] `requestVehicleHeroImage`
- [x] `maintainChatStories`
- [x] `syncProfilePhotoReferences` mit Firestore-Update-Trigger auf
  `public_profiles/{userId}`.
- [x] `syncProfileVisibilityReferences`
- [x] `recordProfileView`
- [x] `submitPlateHint`
- [x] `submitProfileVerification`
- [x] `reviewProfileVerification`
- [x] `saveProfileVehicle`
- [x] `setPrimaryProfileVehicle`
- [x] `deactivateProfileVehicle`
- [x] `updatePrimaryVehicleLocation`
- [x] `maintainPlateHints`
- [x] `cleanupProfileVerificationDocuments`

Die 23 oben gelisteten bisherigen Exports sind live, aktiv, v2, Node.js 22 und
in `europe-west3` gelistet.

- [x] `sendBrandedPasswordResetEmail`
- [x] `sendBrandedEmailVerification`
- [x] `sendBrandedEmailChangeVerification`
- [x] `processSupportMailboxAutoReplies`
- [x] `processPrivacyMailboxAutoReplies`
- [x] `processPartnersMailboxAutoReplies`

Damit sind alle 29 Exports live und aktiv. Die drei gebrandeten Auth-E-Mail-
Functions und die drei Postfach-Antwort-Functions wurden am 2026-08-25 gezielt
als v2/Node.js-22-Functions in `europe-west3` deployt. Sie sind an die
geschuetzten Secrets `PLAQA_NOREPLY_SMTP_PASSWORD`,
`PLAQA_SUPPORT_MAILBOX_PASSWORD`, `PLAQA_PRIVACY_MAILBOX_PASSWORD` und
`PLAQA_PARTNERS_MAILBOX_PASSWORD` gebunden. Die Designs wurden mit
Testnachrichten in Outlook geprueft; die funktionalen Konto- und
Postfach-End-to-End-Tests bleiben offen.

### Indexes und Hosting

- [x] Alle sechs lokalen Firestore-Composite-Indexes sind live, darunter beide
  `social_posts`-Varianten und beide `follow_relationships`-Indexe.
- [x] Firebase-Hosting-Site `carma-a84e4` ist live.
- [x] Startseite, Datenschutz, Kinderschutz, Community-Richtlinien,
  Nutzungsbedingungen, Kontoloeschung, Impressum, Meldestelle, Support,
  Partner und `https://auth.plaqa.de/auth/action` liefern HTTP 200 und stimmen
  nach dem Hosting-Deploy vom 2026-08-25 mit den lokalen HTML-Dateien ueberein.
- [ ] Inhaltliche Gleichheit der live Firestore- und Storage-Rules mit lokalem
  Stand erneut pruefen; die CLI bietet hier keinen sicheren Direktvergleich.

## Blaze und Functions-Deploy

- [x] Blaze/Billing ist aktiv.
- [x] Alle 29 Functions sind live und aktiv.
- [x] Die vier E-Mail-Secrets sind sicher angelegt; ausschliesslich die drei
  gebrandeten Auth-E-Mail-Functions und die drei Postfach-Antwort-Functions
  wurden nach separater Freigabe gezielt deployt.
- [ ] Budgetwarnungen und laufende Kosten vor weiteren Function-Updates
  weiterhin kontrollieren.
- [ ] Versionsgleichheit bleibt je Function durch gezielte Live-Tests zu
  bestaetigen; die Live-Existenz allein ersetzt diese Tests nicht.

## Benötigt Console-Konfiguration

- [CONSOLE] Google-Cloud-Budgetwarnungen und laufende Kosten kontrollieren.
- [CONSOLE] Cloud Functions, Cloud Build, Artifact Registry, Scheduler und bei
  Bedarf Google-AI-/Vertex-AI-APIs und Quoten pruefen.
- [x] App Check fuer `de.plaqa.app` mit Play Integrity registriert.
- [x] Firestore bleibt im Monitoring; Storage und Authentication sind nicht
  erzwungen; Functions erzwingen App Check lokal nicht.
- [CONSOLE] Debug-Token, Play-Integrity-Metriken und echte Release-Anfragen auf
  einem freigegebenen Geraet pruefen.
- [CONSOLE] E-Mail/Passwort- und Google-Provider, autorisierte Domains und
  OAuth-Branding fuer `de.plaqa.app` erneut kontrollieren.
- [CONSOLE] Identity Platform/SMS-MFA, SMS-Regionen, Kontingent, Billing und
  Testnummern erneut kontrollieren.
- [x] Custom SMTP, `no-reply@plaqa.de`, Supportadresse, Action-Domain,
  SMTP-Secret und die drei gebrandeten E-Mail-Functions sind bestaetigt.
  Vor einer neuen App-Version jeden Kontofluss einzeln pruefen.
- [x] Die frueheren IONOS-Text-Eingangsbestaetigungen fuer
  `support@plaqa.de`, `privacy@plaqa.de` und `partners@plaqa.de` sind
  deaktiviert. Die drei gebrandeten HTML-Postfach-Antwort-Functions sind live;
  ihre Designs wurden mit Testnachrichten geprueft.
- [CONSOLE] `auth.plaqa.de` als Auth-/Action-Domain beibehalten und alle
  E-Mail-Aktionsarten testen.
- [x] Store-Name, deutsche Beschreibungen, 512-x-512-App-Icon,
  1024-x-500-Feature-Grafik und acht 900-x-1600-Screenshots sind lokal
  geprueft und gemeinsam als Play-Store-Entwurf gespeichert.
- [x] Interner Release `1 (1.0.0)` ist nach separater Freigabe aktiv; ein
  freigegebener Tester hat die Installation aus Google Play bestaetigt.
- [CONSOLE] Die fuer neue Privatkonten erforderliche geschlossene Testspur erst
  nach Backend-, Legal- und Live-Test-Freigabe anlegen.
- [x] iOS App Check mit App Attest und DeviceCheck registriert; Monitoring ohne
  Erzwingung beibehalten.
- [x] APNs-Key fuer Entwicklung und Produktion in Firebase hinterlegt.
- [x] App Store Connect ist nach persoenlicher Annahme der Nutzungsbedingungen
  freigeschaltet; der App-Eintrag ist als Entwurf angelegt.

## Benötigt Live-Test

- [LIVE] Registrierung, Verifikation, E-Mail-/Google-Login, Logout und
  Session-Neustart.
- [LIVE] Passwort-Reset, E-Mail-Aenderung und Wiederherstellung ueber
  `auth.plaqa.de`.
- [LIVE] Reale Eingangsmails an Support, Datenschutz und Partnerschaften samt
  Scheduler, Antwortthread und Deduplizierung Ende-zu-Ende pruefen.
- [LIVE] SMS-MFA aktivieren, E-Mail-/Google-MFA-Login, Abmelden und Faktor
  entfernen.
- [LIVE] MFA-Recovery mit vertrauenswuerdigem Admin-Claim, Genehmigung,
  Ablehnung, Audit und Token-Widerruf.
- [LIVE] Kontoloeschung ausschliesslich mit freigegebenem Testkonto; Auth,
  Profil, Fahrzeuge, Kennzeichen, Posts, Storys, Medien, Settings und
  gemeinsame/pseudonymisierte Daten einzeln kontrollieren.
- [LIVE] Profilbild, Anzeigename und Sichtbarkeit in Posts, Likes, Kommentaren,
  Antworten, Chats, Anfragen, Storys und Fahrzeugprojektionen synchronisieren.
- [LIVE] Zwei Fahrzeuge speichern, Hauptfahrzeug wechseln, deaktivieren und
  jedes aktive Kennzeichen suchen.
- [LIVE] Dokumente hochladen, einreichen, ablehnen, nachreichen, Ablauf und
  30/14/3-Erinnerungen pruefen; Cleanup separat kontrollieren.
- [LIVE] Social Feed mit mindestens zwei Konten: Follow/Unfollow,
  Sichtbarkeit, Likes, Kommentare, Antworten, Meldungen und Blockierung.
- [LIVE] Firestore-/Storage-Berechtigungen fuer Eigentuemer, Teilnehmer,
  Aussenstehende und Admin nach jedem Rules-Deploy.
- [LIVE] App Check im Debug- und signierten Release-Build beobachten, bevor
  irgendein Produkt erzwungen wird.
- [LIVE] KI-Fahrzeugbild auf Kosten, Rate-Limit, Bildpfad und Fehlerzustand.
- [LIVE] Scheduler fuer Story-, Meldungs- und Dokument-Cleanup in Logs und
  Datenwirkung pruefen.
- [LIVE] Interne Release-Installation ist bestaetigt; eigentliche Funktions-,
  Pre-Launch-, Crash- und ANR-Pruefungen bleiben bewusst offen.
- [LIVE] iOS: Apple Login, Private Relay, App Attest/DeviceCheck, APNs-
  Zustellung, Hintergrund/Antippen und Tokenrotation auf echtem iPhone.
- [LIVE] iOS Universal Links erst nach AASA- und Routing-Einbindung testen.

## Benötigt rechtliche Prüfung

- [LEGAL] Anbieterkennzeichnung und neue ladungsfaehige Anschrift nach dem
  geplanten Umzug.
- [LEGAL] AGB/Nutzungsbedingungen, insbesondere Haftung, Sperrung, Kuendigung,
  Aenderungen und Gerichtsstand.
- [LEGAL] Datenschutzerklaerung, Rechtsgrundlagen, Empfaenger, internationale
  Transfers, Auftragsverarbeitung und feste Loesch-/Aufbewahrungsfristen.
- [LEGAL] Verhaeltnismaessigkeit, Schwaerzung und Rechtsgrundlage fuer
  Identitaets- und Fahrzeugscheinkopien.
- [LEGAL] DSA-Einordnung, Moderation, Beschwerden, Behoerdenmeldungen und
  Streitbeilegung.
- [LEGAL] Datenschutz-Folgenabschaetzung und Erforderlichkeit eines
  Datenschutzbeauftragten; nicht abschliessend entschieden.
- [LEGAL] Verbraucherstreitbeilegung; bei geplant weniger als zehn Personen
  dennoch nicht abschliessend entschieden.
- [LEGAL] Marken- und Namenspruefung fuer `plaqa`.
- [LEGAL] Legal-Versionen und Aktualisierungsdatum final festlegen.

## Benötigt persönliche Bestätigung

- [PERSON] Neue Anschrift nach dem vor Release stattfindenden Umzug bestaetigen.
- [PERSON] Betreiberstatus vor Release erneut bestaetigen und nur dann
  Gesellschafts-, Register- oder Steuerangaben ergaenzen, wenn sie existieren.
- [PERSON] Externe Rechtsfassung abnehmen; technische Bereinigung ist keine
  anwaltliche Freigabe.
- [PERSON] Blaze/Billing und Budgetgrenzen ausdruecklich freigeben.
- [PERSON] Einsatz ausdruecklich freigegebener Testkonten und Testdokumente.
- [x] AAB-Upload und Start der internen Testspur wurden separat freigegeben und
  abgeschlossen.
- [PERSON] Start einer geschlossenen oder offenen Testspur, Einreichung zur
  Pruefung und Produktionsveroeffentlichung weiterhin jeweils separat
  freigeben.
- [x] App-Store-Connect-Nutzungsbedingungen selbst gelesen und angenommen.
- [PERSON] Apple-Altersfreigabe und App Privacy gegen den finalen Build
  bestaetigen.

## Blockiert Release

- [BLOCKER] Die bereits live erreichbaren Rechtsseiten fachlich/rechtlich
  freigeben und nach daraus entstehenden Korrekturen Hosting erneut gezielt
  deployen.
- [BLOCKER] Firestore- und Storage-Rules gegen den Live-Stand pruefen,
  erforderlichen Stand deployen und Berechtigungstests bestehen.
- [BLOCKER] Die 29 live Functions mit freigegebenen Testkonten gruppenweise
  funktional pruefen.
- [BLOCKER] `cleanupProfileVerificationDocuments` live pruefen, bevor die
  Dokumentenverifizierung produktiv freigegeben wird.
- [BLOCKER] App Check im Debug- und signierten Release-Build auf einem echten
  Geraet beobachten; Enforcement erst danach.
- [x] Acht Store-Screenshots erhalten, technisch geprueft und mit Texten,
  App-Icon und Feature-Grafik als Entwurf gespeichert.
- [BLOCKER] Die von Google geforderte geschlossene Testphase mit mindestens
  12 durchgehend teilnehmenden Testern ueber mindestens 14 Tage abschliessen;
  der aktive interne Test ersetzt diese Phase nicht.
- [BLOCKER] Geraete- und Mehrkonten-Livetests ohne kritische Fehler bestehen.
- [BLOCKER] Externe Rechtspruefung und neue Anschrift abschliessen.
- [BLOCKER] Demo-/Beispieldaten im Release entfernen oder nachweislich nur im
  Debug-Modus belassen.
- [BLOCKER] Eine lokale Firebase-Admin-Zugangsschluesseldatei liegt ausserhalb
  des Repositories im Desktop-Adminordner. Vor Release in einen verschluesselten
  Secretspeicher verschieben, Zugriff beschraenken und bei moeglicher
  Offenlegung rotieren. Sie wurde nicht in Git oder der Git-Historie gefunden.
- [BLOCKER] Release-Keystore und KeePass-Datenbank zusaetzlich unabhaengig und
  verschluesselt ausserhalb dieses Laptops sichern.
- [BLOCKER] iOS-Build auf einem Mac signieren, auf echtem iPhone pruefen und
  erst danach kontrolliert per TestFlight bereitstellen.
- [BLOCKER] App Privacy und Store-Metadaten gegen den finalen iOS-Build
  persoenlich abgleichen und erst danach veroeffentlichen beziehungsweise
  einreichen.
- [x] Release-Branch wurde bereits kontrolliert in `main` uebernommen. Der
  aktuelle Abschlussstand wird ohne Force-Push auf `origin/main` gesichert.

## Nächste sichere Reihenfolge

1. Externe Legal-Pruefung und neue Anschrift einarbeiten; geaenderte
   Rechtsseiten anschliessend erneut gezielt hosten.
2. Budgetwarnungen und erforderliche APIs weiter beobachten.
3. Rules nach erneutem Emulatorlauf deployen; Indexes derzeit nicht erneut
   deployen, da alle sechs live sind.
4. Die bereits live vorhandenen Functions gruppenweise mit freigegebenen
   Testkonten pruefen.
5. App Check im Monitoring beobachten und erst nach Geraetetests schrittweise
   erzwingen.
6. Internen Test aktiv lassen; Funktionspruefungen erst nach separater
   Freigabe durchfuehren.
7. Geschlossene Testphase mit mindestens 12 Testern ueber mindestens 14 Tage,
   Pre-Launch-Report und echte Live-Tests getrennt
   abschliessen.
8. Produktion erst nach einer eigenen ausdruecklichen Freigabe einreichen.
