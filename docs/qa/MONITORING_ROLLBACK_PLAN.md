# plaqa Monitoring- und Rollbackplan

Stand: 2026-09-01
Status: produktive Kosten- und Fehleralarme, E-Mail-Kanal, Dashboard und
Rollbackübung eingerichtet beziehungsweise nachgewiesen; die externe
verschlüsselte Sicherung folgt nach Beschaffung des Datenträgers

## Produktive Konfiguration

- Firebase-/Google-Cloud-Projekt: `carma-a84e4`
- Alarmempfänger: `yildirim.sehmus4747@gmail.com`
- Monatliches Projektbudget: 25 EUR
- Ist-Ausgaben-Warnungen: 20 %, 40 %, 80 % und 100 %
  (5 EUR, 10 EUR, 20 EUR und 25 EUR)
- Prognosewarnung: erwartete 100 % des Monatsbudgets
- Budgetwarnungen gehen an die Billing-Account-Administratoren und aktivierten
  Projekt-Empfänger. Die Warnung begrenzt oder stoppt Ausgaben nicht.
- Aktive Log-Alarme: produktive Cloud-Run-/Functions-Fehler ab `ERROR` sowie
  Cloud-Scheduler-Fehler ab `ERROR`
- Wiederholungsbegrenzung der Log-Alarme: eine Benachrichtigung je 15 Minuten;
  automatische Schließung nach 24 Stunden ohne weiteren Treffer
- Monitoring-E-Mail-Kanal `Plaqa Betrieb und Sicherheit`: verifiziert und aktiv
- Dashboard `Plaqa Produktionsbetrieb`: App Check, Cloud-Run-5xx und kritische
  Logeinträge

## App-Check-Entscheidung

Die sicherheitskritischen Callable Functions erzwingen App Check bereits
gezielt. Im finalen Redmi-Testfenster ab `2026-08-31T10:00:00Z` waren 22 von 22
Function-Prüfungen `VALID`.

Die serviceweiten Prüfungen im gleichen Fenster ergaben:

| Dienst | gültig | ungültig/unbekannt | Entscheidung |
|---|---:|---:|---|
| Cloud Storage | 8 | 0 | Monitoring fortsetzen; Stichprobe noch klein |
| Cloud Firestore | 9.896 | 2.177 | keine globale Erzwingung vor Ursachenklärung/Testspur |
| Firebase Authentication | 35 | 2 | Monitoring fortsetzen |

Firestore, Storage und Authentication bleiben deshalb bewusst auf
`UNENFORCED`. Eine globale Aktivierung vor der geschlossenen Android-Testphase
könnte legitime Verwaltungs-, Test- oder Altclientpfade blockieren. Vor der
Aktivierung muss die signierte Testspur pro Dienst eine ausreichend große,
nahezu vollständig gültige Stichprobe liefern.

## Rollbackübung 2026-09-01

- Kandidat: Cloud-Run-Service `requestvehicleheroimage` in `europe-west3`
- Sicherheitsprüfung: in den vorherigen 30 Minuten keine Nutzeranfrage
- Ausgangsrevision: `requestvehicleheroimage-00014-gap`, 100 % Traffic
- Rollbackziel: `requestvehicleheroimage-00013-jec`, 100 % Traffic
- Ergebnis Rollback: Routing unabhängig bestätigt
- Wiederherstellung: Revision `requestvehicleheroimage-00014-gap` wieder auf
  100 % gesetzt und unabhängig bestätigt
- Datenänderungen: keine
- Nutzerbeeinträchtigung: keine beobachtet
- Ergebnis: PASS

## Überwachung

| Signal | Beobachtung | Startschwelle | Reaktion |
|---|---|---|---|
| Crash/ANR | Crashlytics, Play Vitals, Xcode Organizer | jeder neue P0/P1-Cluster | Rollout pausieren, Version und Geräte eingrenzen |
| Auth | Firebase Auth/Functions-Fehler | deutlicher Anstieg gegenüber interner Basis | Provider, Domains, Quoten und letzte Änderung prüfen |
| Rules | Firestore-/Storage-Denials | legitime Kernreise schlägt fehl | Rollout stoppen; niemals Regeln pauschal lockern |
| Functions | Fehlerquote, Latenz, Instanzen | anhaltende Fehler oder Timeout-Spitze | betroffene Function isolieren/zurückrollen |
| Kosten | Vertex AI, Storage, Firestore, Egress | Budgetwarnung oder ungewöhnliches Nutzerprofil | kostenpflichtigen Pfad serverseitig sperren |
| App Check | gültig/ungültig/unbekannt je Plattform | legitime unbekannte Tokens über akzeptierter Basis | keine Erzwingung; Konfiguration korrigieren |
| Missbrauch | Suche, Kontakt, Upload, Profilaufruf | Rate-/Musteralarm | Konto/Pfad begrenzen und Incident prüfen |
| Support | Löschung, Export, Meldung, Sicherheit | Frist- oder Zustellungsfehler | manuellen Eskalationsprozess starten |

## Rollout

1. Lokale und CI-Vollregression mit exakt dem Release-Commit.
2. Signierte Android-/iOS-Artefakte hashen und archivieren.
3. Nur interne Testspur, mit kleinem benannten Testerkreis.
4. Mindestens 48 Stunden Metriken und Supportsignale beobachten.
5. Erst nach dokumentiertem Review stufenweise erweitern.
6. App Check nie gleichzeitig mit einem neuen App-Build erzwingen.

## Rollbackauslöser

- Kontoübernahme, Datenleck, Standortoffenlegung oder falsche Autorisierung
- reproduzierbarer Datenverlust oder unvollständige Kontolöschung
- Crash-/ANR-Spitze in einer Kernreise
- Anmeldung, Chat, Suche oder Meldung für legitime Nutzer nicht nutzbar
- unkontrollierte KI-, Storage-, Firestore- oder Egress-Kosten
- falsche Store-, Datenschutz- oder Kinderschutzangabe

## Rollbackschritte

1. Store-Rollout sofort pausieren; keine neue Zielgruppe hinzufügen.
2. Incident-Leitung, Technik, Datenschutz/Recht und Support informieren.
3. Betroffene Version, Plattform, Funktion und Backendänderung identifizieren.
4. Reversible Remote-Funktion nur über vorher dokumentierten Kill-Switch
   deaktivieren; keine Regeln spontan öffnen.
5. Functions/Rules/Hosting nur auf einen nachweislich bekannten Commit
   zurücksetzen und separat freigeben.
6. Bei Clientfehlern vorherige Storeversion wieder priorisieren oder Hotfix mit
   neuer Buildnummer in die interne Spur geben.
7. Datenintegrität prüfen, betroffene Nutzer und Meldepflichten bewerten.
8. Ursache, Zeitlinie, Maßnahmen und Wiederholungsprävention dokumentieren.

## Zuständigkeiten vor Release

| Rolle | Person/Kanal | bestätigt |
|---|---|---|
| Incident-Leitung | Sehmus Yildirim | [x] |
| Mobile/Backend | Sehmus Yildirim; technische Stellvertretung noch zu benennen | [x] |
| Firebase/Cloud-Kosten | Sehmus Yildirim, `yildirim.sehmus4747@gmail.com` | [x] |
| Datenschutz/Recht | Sehmus Yildirim; externe Rechtsprüfung separat | [x] |
| Moderation/Kinderschutz | Sehmus Yildirim; Stellvertretung noch zu benennen | [x] |
| Nutzer-Support | Sehmus Yildirim, `support@plaqa.de` | [x] |
| Store-Verantwortlicher | Sehmus Yildirim | [x] |

Die technische Stellvertretung wird nach Abstimmung mit dem Programmierer
namentlich ergänzt. Bis dahin liegt die operative Verantwortung vollständig bei
Sehmus Yildirim.

## Verschlüsselte externe Sicherung

Vor der Veröffentlichung werden mindestens folgende Wiederherstellungsdaten auf
einem vom Laptop getrennten, verschlüsselten Datenträger gesichert:

- Android-Upload-Keystore und Aliasinformation;
- KeePassXC-Datenbank mit den zugehörigen Zugangsdaten;
- vorhandene, tatsächlich benötigte Firebase-/Google-Cloud-Schlüssel;
- eine Wiederherstellungsanleitung ohne Passwörter oder geheime Schlüssel;
- Hashwerte und Erstellungsdatum der gesicherten Dateien.

`key.properties`, Kennwörter und geheime Schlüssel dürfen weder unverschlüsselt
auf dem Datenträger noch im Git-Repository liegen. Nach der Sicherung wird eine
reine Lese- und Entschlüsselungsprobe durchgeführt. Der Datenträger bleibt danach
vom Laptop getrennt und wird an einem sicheren Ort verwahrt.

Ein Deployment oder Rollback in externen Systemen erfolgt nur nach eindeutiger
Freigabe und wird mit Commit, Zeit, Ausführendem und Ergebnis protokolliert.

Der praktisch auszufuehrende Incident-Ablauf mit Prioritaeten, Reaktionszeiten,
Wiederherstellung und Abschlussnachweis steht in
`docs/qa/INCIDENT_RESPONSE_RUNBOOK.md`.
