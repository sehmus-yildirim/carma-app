# plaqa Monitoring- und Rollbackplan

Stand: 2026-08-29
Status: technische Vorlage erstellt; reale Empfänger, Schwellenwerte und Übungen
vor Veröffentlichung zu bestätigen

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
| Incident-Leitung | | [ ] |
| Mobile/Backend | | [ ] |
| Firebase/Cloud-Kosten | | [ ] |
| Datenschutz/Recht | | [ ] |
| Moderation/Kinderschutz | | [ ] |
| Nutzer-Support | | [ ] |
| Store-Verantwortlicher | | [ ] |

Ein Deployment oder Rollback in externen Systemen erfolgt nur nach eindeutiger
Freigabe und wird mit Commit, Zeit, Ausführendem und Ergebnis protokolliert.
