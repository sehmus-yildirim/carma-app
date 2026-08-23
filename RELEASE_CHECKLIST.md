# plaqa Release Checklist

Stand: 2026-08-23 CEST
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

- [x] Aktueller Branch: `codex/android-package-de-plaqa-app`.
- [x] Ausgangsstand vor dieser Dokumentaktualisierung war sauber.
- [x] Designkorrekturen und App-Check-Integration sind getrennt committed und
  auf `origin/codex/android-package-de-plaqa-app` gesichert.
- [x] Letzte Commits: `9d126ff` und `f7dac26`.
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
- [x] Vollstaendiger Flutter-Lauf am 2026-08-23: 188 Tests bestanden.
- [x] Letzter dokumentierter Analyze-Lauf: `flutter analyze --no-pub` ohne
  Befund.
- [x] Letzter dokumentierter Functions-Lauf: Syntaxchecks der 9 produktiven
  JavaScript-Dateien und 6 Testdateien mit 71 Tests bestanden.
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
- [x] Das gepruefte AAB wurde am 2026-08-23 ausschliesslich als interner
  Testrelease-Entwurf `1 (1.0.0)` hochgeladen und gespeichert.
- [x] Der interne Track bleibt inaktiv; keine Tester wurden ausgewaehlt, keine
  Einladungen versendet und nichts zur Pruefung oder Produktion eingereicht.
- [ ] Acht echte Smartphone-Screenshots werden spaeter vom Nutzer geliefert;
  sie wurden noch nicht hochgeladen.

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

- [x] 23 Functions-Exports in `functions/index.js`, global
  `europe-west3`, Node.js 22.
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

Am 2026-08-23 mit `firebase functions:list --json` read-only nachgewiesen. Die
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

Alle 23 lokalen Exports sind live, aktiv, v2, Node.js 22 und in
`europe-west3` gelistet.

### Indexes und Hosting

- [x] Alle sechs lokalen Firestore-Composite-Indexes sind live, darunter beide
  `social_posts`-Varianten und beide `follow_relationships`-Indexe.
- [x] Firebase-Hosting-Site `carma-a84e4` ist live.
- [x] `https://plaqa.de/`, Kontoloeschung, Impressum, Meldestelle, Support,
  Partner und `https://auth.plaqa.de/auth/action` liefern HTTP 200 und stimmen
  byteweise mit den lokalen HTML-Dateien ueberein.
- [ ] Datenschutz, Kinderschutz, Community-Richtlinien und
  Nutzungsbedingungen sind live erreichbar, aber lokal neuer als die aktuell
  ausgelieferten HTML-Dateien.
- [ ] Inhaltliche Gleichheit der live Firestore- und Storage-Rules mit lokalem
  Stand erneut pruefen; die CLI bietet hier keinen sicheren Direktvergleich.

## Blaze und Functions-Deploy

- [x] Blaze/Billing ist aktiv.
- [x] Alle 23 lokalen Functions sind live und aktiv.
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
- [CONSOLE] Firebase-E-Mail-Vorlagen, Absender, Supportadresse, deutsche Texte,
  Action-URL und Custom-SMTP-Status erneut kontrollieren.
- [CONSOLE] `auth.plaqa.de` als Auth-/Action-Domain beibehalten und alle
  E-Mail-Aktionsarten testen.
- [LOCAL] Store-Name und deutsche Beschreibungen sind vorbereitet. Das
  512-x-512-App-Icon und die 1024-x-500-Feature-Grafik sind lokal geprueft.
- [CONSOLE] App-Icon, Feature-Grafik und die acht spaeter gelieferten echten
  Smartphone-Screenshots gemeinsam in den Store-Entwurf eintragen.
- [CONSOLE] Der interne Testrelease liegt nur als inaktiver Entwurf vor. Tester
  auswaehlen und den Track erst nach separater Freigabe starten.
- [CONSOLE] Die fuer neue Privatkonten erforderliche geschlossene Testspur erst
  nach Backend-, Legal- und Live-Test-Freigabe anlegen.

## Benötigt Live-Test

- [LIVE] Registrierung, Verifikation, E-Mail-/Google-Login, Logout und
  Session-Neustart.
- [LIVE] Passwort-Reset, E-Mail-Aenderung und Wiederherstellung ueber
  `auth.plaqa.de`.
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
- [LIVE] Den vorhandenen internen AAB-Entwurf erst nach separater Freigabe
  starten; danach Pre-Launch-Report sowie Crash-/ANR-Berichte pruefen.

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
- [x] AAB-Upload als inaktiver interner Entwurf wurde separat freigegeben und
  abgeschlossen.
- [PERSON] Start einer Testspur, Einreichung zur Pruefung und
  Produktionsveroeffentlichung weiterhin jeweils separat freigeben.

## Blockiert Release

- [BLOCKER] Vier lokal neuere Rechtsseiten fachlich/rechtlich freigeben und
  danach Hosting gezielt deployen.
- [BLOCKER] Firestore- und Storage-Rules gegen den Live-Stand pruefen,
  erforderlichen Stand deployen und Berechtigungstests bestehen.
- [BLOCKER] Die 23 live Functions mit freigegebenen Testkonten gruppenweise
  funktional pruefen.
- [BLOCKER] `cleanupProfileVerificationDocuments` live pruefen, bevor die
  Dokumentenverifizierung produktiv freigegeben wird.
- [BLOCKER] App Check im Debug- und signierten Release-Build auf einem echten
  Geraet beobachten; Enforcement erst danach.
- [BLOCKER] Acht echte Store-Screenshots vom Nutzer erhalten und pruefen;
  Texte, Screenshot-Konzept, App-Icon und Feature-Grafik sind vorbereitet.
- [BLOCKER] Testspur und von Google geforderte Testphase abschliessen.
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
- [x] Release-Branch wurde bereits kontrolliert in `main` uebernommen. Der
  aktuelle Abschlussstand wird ohne Force-Push auf `origin/main` gesichert.

## Nächste sichere Reihenfolge

1. Externe Legal-Pruefung und neue Anschrift einarbeiten; vier abweichende
   Rechtsseiten anschliessend gezielt hosten.
2. Budgetwarnungen und erforderliche APIs weiter beobachten.
3. Rules nach erneutem Emulatorlauf deployen; Indexes derzeit nicht erneut
   deployen, da alle sechs live sind.
4. Die bereits live vorhandenen Functions gruppenweise mit freigegebenen
   Testkonten pruefen.
5. App Check im Monitoring beobachten und erst nach Geraetetests schrittweise
   erzwingen.
6. Acht echte Store-Screenshots vom Nutzer pruefen und mit den vorbereiteten
   Store-Assets als Entwurf speichern.
7. Tester auswaehlen und den internen Test erst nach separater Freigabe starten.
8. Geschlossene Testphase, Pre-Launch-Report und echte Live-Tests getrennt
   abschliessen.
9. Produktion erst nach einer eigenen ausdruecklichen Freigabe einreichen.
