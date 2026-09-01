# Plaqa Incident-Runbook

Stand: 2026-09-01
Verantwortlich: Sehmus Yildirim
Alarmkanal: `yildirim.sehmus4747@gmail.com`
Supportkanal: `support@plaqa.de`

## Ziel

Dieses Runbook beschreibt die erste Reaktion auf Sicherheits-, Datenschutz-,
Verfuegbarkeits- und Kostenereignisse im Projekt `carma-a84e4`. Jede Massnahme
muss Zeit, ausfuehrende Person, betroffenen Dienst, Ergebnis und Rueckweg
protokollieren.

## Prioritaeten

| Stufe | Beispiele | Erstreaktion |
|---|---|---|
| P0 | Konto- oder Datenoffenlegung, aktive Kontouebernahme, unkontrollierter Datenverlust | sofort |
| P1 | Anmeldung oder Kernreise breit ausgefallen, starke Crash-/Kosten-Spitze | innerhalb 30 Minuten |
| P2 | Teilfunktion beeintraechtigt, begrenzte Fehlerrate ohne Datenrisiko | innerhalb 4 Stunden |
| P3 | einzelner Fehler ohne unmittelbare Auswirkung | naechster Arbeitstag |

## Ablauf

1. Alarm bestaetigen und Incident-ID im Format `OPS-JJJJ-MM-TT-NN` vergeben.
2. Beginn, Melder, betroffene Version, Region und Dienste protokollieren.
3. Nutzer- und Datenrisiko vor einer technischen Detailanalyse einstufen.
4. Bei P0/P1 neue Rollouts, riskante Jobs und kostenpflichtige Missbrauchspfade
   kontrolliert pausieren. Sicherheitsregeln niemals pauschal lockern.
5. Letzten bekannten guten Commit, Function-Revision und Rules-Stand bestimmen.
6. Reversible Gegenmassnahme anwenden und den Zielstand unabhaengig auslesen.
7. Anmeldung, Kernreise, Datenintegritaet, Loeschung und Alarmzustand pruefen.
8. Betroffene Nutzer, Datenschutzmeldung und externe Kommunikation bewerten.
9. Incident erst schliessen, wenn Ursache, Wiederherstellung und Rest-Risiko
   dokumentiert sind.
10. Innerhalb von zwei Arbeitstagen Ursache und dauerhafte Praevention erfassen.

## Kontrollierte Wiederherstellung

- Cloud Run/Functions: Traffic nur auf eine bereits bereitstehende, bekannte
  Revision umschalten und nach dem Test wieder auf den Ausgangsstand setzen.
- Firestore/Storage Rules: nur einen zuvor getesteten Repository-Stand
  bereitstellen; keine offenen Notfallregeln verwenden.
- Client: Store-Rollout pausieren und Hotfix mit neuer Buildnummer in der
  internen Testspur pruefen.
- Kosten: betroffenen serverseitigen Pfad begrenzen oder deaktivieren, Budget-
  und Nutzungsmetriken weiter beobachten.

## Nachweis 2026-09-01

- Test-Incident: `OPS-2026-09-01-01`
- Fehlerlog traf die produktive Functions-Alarmregel.
- Der verifizierte E-Mail-Kanal meldete keinen Zustellfehler.
- Der Empfaenger bestaetigte den Eingang der Test-Alarm-Mail.
- Rollback von `requestvehicleheroimage-00014-gap` auf
  `requestvehicleheroimage-00013-jec` wurde ausgefuehrt und bestaetigt.
- Der Ausgangsstand `requestvehicleheroimage-00014-gap` wurde anschliessend zu
  100 Prozent wiederhergestellt und bestaetigt.
- Es wurden keine Nutzerdaten gelesen oder veraendert.

## Noch namentlich zu ergaenzen

Die technische Stellvertretung wird erst nach Zustimmung der betreffenden
Person mit Name und Kontakt eingetragen. Bis dahin liegt die operative
Verantwortung bei Sehmus Yildirim.
