# plaqa Release Checklist

Stand: 2026-08-22 CEST
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
- [x] Letzter lokaler Commit: `3747951 chore: save release preparation progress`.
- [ ] Der Branch liegt einen lokalen Commit vor
  `origin/codex/android-package-de-plaqa-app`; Push bleibt offen.
- [ ] Diese beiden aktualisierten Dokumente sind nach Abschluss dieses Schritts
  noch nicht committed oder gepusht.
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
- [x] Letzter dokumentierter Flutter-Lauf: 31 Testdateien, 169 Tests bestanden.
- [x] Letzter dokumentierter Analyze-Lauf: `flutter analyze --no-pub` ohne
  Befund.
- [x] Letzter dokumentierter Functions-Lauf: Syntaxchecks der 9 produktiven
  JavaScript-Dateien und 6 Testdateien mit 71 Tests bestanden.
- [x] Letzter dokumentierter Rules-Lauf: 11 Testdateien, 14 Suites, 97 Tests
  bestanden.
- [x] Debug-APK und signiertes Release-AAB erfolgreich erzeugt.
- [x] AAB-Signatur und Upload-Keystore erfolgreich abgeglichen.
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
- [x] Es wurde kein AAB hochgeladen, keine Testspur gestartet und nichts zur
  Pruefung oder Produktion eingereicht.

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
- [x] App Check ist im Android-Code build-gesteuert vorbereitet; Release nutzt
  Play Integrity, Debug einen expliziten Debug-Provider.
- [x] Auth-Action-Handler unter `hosting/auth/action` lokal vorhanden.

## Veröffentlicht

### Functions

Am 2026-08-22 mit `firebase functions:list` read-only nachgewiesen. Die
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
- [x] `syncProfilePhotoReferences` als Live-Name; CLI meldet `https`, waehrend
  lokal ein Firestore-Update-Trigger definiert ist. Diese Abweichung bleibt
  offen.

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

## Benötigt Blaze

- [BLAZE] Billing-Plan und Budgetwarnungen vor jedem neuen oder aktualisierten
  Functions-Deploy bestaetigen.
- [BLAZE] `syncProfileVisibilityReferences`.
- [BLAZE] `recordProfileView`.
- [BLAZE] `submitPlateHint`.
- [BLAZE] `submitProfileVerification`.
- [BLAZE] `reviewProfileVerification`.
- [BLAZE] `saveProfileVehicle`.
- [BLAZE] `setPrimaryProfileVehicle`.
- [BLAZE] `deactivateProfileVehicle`.
- [BLAZE] `updatePrimaryVehicleLocation`.
- [BLAZE] `maintainPlateHints`.
- [BLAZE] `cleanupProfileVerificationDocuments`.
- [BLAZE] Auch Updates der 12 bereits vorhandenen Functions nur kontrolliert
  und mit aktivem Billing ausfuehren.

## Benötigt Console-Konfiguration

- [CONSOLE] Blaze aktivieren und Google-Cloud-Budgetwarnungen setzen.
- [CONSOLE] Cloud Functions, Cloud Build, Artifact Registry, Scheduler und bei
  Bedarf Google-AI-/Vertex-AI-APIs und Quoten pruefen.
- [CONSOLE] App-Check-Registrierung der finalen Android-App, Debug-Provider,
  Play Integrity, Metriken und aktuellen Enforcement-Status pruefen.
- [CONSOLE] App Check zunaechst nur ueberwachen; MFA-Recovery steht lokal
  weiterhin auf `enforceAppCheck: false`.
- [CONSOLE] E-Mail/Passwort- und Google-Provider, autorisierte Domains und
  OAuth-Branding fuer `de.plaqa.app` erneut kontrollieren.
- [CONSOLE] Identity Platform/SMS-MFA, SMS-Regionen, Kontingent, Billing und
  Testnummern erneut kontrollieren.
- [CONSOLE] Firebase-E-Mail-Vorlagen, Absender, Supportadresse, deutsche Texte,
  Action-URL und Custom-SMTP-Status erneut kontrollieren.
- [CONSOLE] `auth.plaqa.de` als Auth-/Action-Domain beibehalten und alle
  E-Mail-Aktionsarten testen.
- [CONSOLE] Store-Name, Kurzbeschreibung, Langbeschreibung, App-Icon,
  Feature-Grafik und Smartphone-Screenshots fertigstellen.
- [CONSOLE] Interne beziehungsweise fuer neue Privatkonten erforderliche
  geschlossene Testspur erst nach Backend- und Legal-Freigabe anlegen.

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
- [LIVE] AAB spaeter in einer Testspur, Pre-Launch-Report sowie Crash-/ANR-
  Berichte pruefen.

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
- [PERSON] AAB-Upload, Start einer Testspur, Einreichung zur Pruefung und
  Produktionsveroeffentlichung jeweils separat freigeben.

## Blockiert Release

- [BLOCKER] Vier lokal neuere Rechtsseiten fachlich/rechtlich freigeben und
  danach Hosting gezielt deployen.
- [BLOCKER] Firestore- und Storage-Rules gegen den Live-Stand pruefen,
  erforderlichen Stand deployen und Berechtigungstests bestehen.
- [BLOCKER] Blaze aktivieren und die benoetigten 11 Functions in kleinen
  Gruppen deployen und live testen.
- [BLOCKER] `cleanupProfileVerificationDocuments` deployen und pruefen, bevor
  Dokumentenverifizierung produktiv freigegeben wird.
- [BLOCKER] Live-Triggerabweichung von `syncProfilePhotoReferences` klaeren.
- [BLOCKER] App Check fuer die finale Android-App konfigurieren und im
  Monitoring erfolgreich nachweisen; Enforcement erst danach.
- [BLOCKER] Store-Texte, Screenshots und Feature-Grafik fertigstellen.
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
- [BLOCKER] Branch nach finaler Kontrolle in `main` uebernehmen und ohne
  Force-Push auf GitHub sichern.

## Nächste sichere Reihenfolge

1. Store-Texte, Screenshot-Konzept und Feature-Grafik lokal fertigstellen.
2. Externe Legal-Pruefung und neue Anschrift einarbeiten; vier abweichende
   Rechtsseiten anschliessend gezielt hosten.
3. Blaze/Budgetwarnungen und erforderliche APIs konfigurieren.
4. Rules nach erneutem Emulatorlauf deployen; Indexes derzeit nicht erneut
   deployen, da alle sechs live sind.
5. Functions gemaess `FIREBASE_DEPLOY_PLAN.md` in kleinen Gruppen deployen und
   je Gruppe live testen.
6. App Check im Monitoring einrichten und erst nach Geraetetests schrittweise
   erzwingen.
7. Alle Flutter-, Functions-, Rules-, Analyze- und Release-Build-Pruefungen
   wiederholen.
8. Branch kontrolliert nach `main` uebernehmen und pushen.
9. AAB/Testspur, Pre-Launch-Report und echte Live-Tests getrennt abschliessen.
10. Produktion erst nach einer eigenen ausdruecklichen Freigabe einreichen.
