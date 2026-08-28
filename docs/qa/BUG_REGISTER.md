# plaqa QA Bug Register

Stand: 2026-08-28

| ID | Priorität | Bereich | Befund | Status | Nachweis |
|---|---:|---|---|---|---|
| BUG-001 | P1 | Kennzeichensuche | Die globale Launch-Konfiguration deaktivierte die Monatsbegrenzung, die UI blockierte bei erschöpftem Legacy-Kontingent dennoch Suche und Kontaktanfrage und zeigte den Kontingentkasten. | FIXED LOCAL | Regressionstest und 231/231 Gesamttests bestanden |
| BUG-002 | P1 | Registrierung/Auth-Gate | Registrierung und Login legten Firestore-Basisdaten parallel zum Auth-Gate an. Das Rennen führte sporadisch zur sichtbaren Meldung, dass Basisdaten nicht vollständig angelegt werden konnten. | FIXED LOCAL | 4/4 Integrationstests, 234/234 Flutter-Regressionstests und Analyze bestanden |
| OBS-001 | P1-Risiko | Firestore Rules | Einzelne Chat-/Kontakt-Negativpfade protokollieren im Emulator das Erreichen der Grenze von 1.000 Regelausdrücken. Alle positiven und negativen Erwartungen bestehen, die Regelkomplexität bleibt aber vor Mehrkontentests zu untersuchen. | OPEN / NOT REPRODUCED AS USER BUG | 104/104 Rules-Tests bestanden; Ein-Konto-Integration ohne diesen Fehler |

## BUG-001 Korrektur

Die Kennzeichensuche verwendet nun dieselbe zentrale Konfiguration wie das
Feature-Gate. Ist die Monatsbegrenzung deaktiviert, bleibt die Suche unabhängig
von alten Kontingentdaten verfügbar und der Kontingentstatus wird nicht gerendert.
Die Änderung betrifft keine Backenddaten und aktiviert keine neue Funktion.

## BUG-002 Korrektur

Die zentrale Auth-Gate-Schicht ist jetzt allein für Profil, öffentliches Profil,
Suchstatus, rechtliche Zustimmungen und Laufzeiteinstellungen verantwortlich.
Login und Registrierung authentifizieren ausschließlich und starten keine zweite
parallele Firestore-Bereitstellung mehr. Kurzzeitige Firestore-Fehler mit den
Codes `unavailable` oder `deadline-exceeded` werden im Auth-Gate höchstens
dreimal verzögert wiederholt; Berechtigungs- und Datenfehler bleiben sichtbar.

## Offene Beobachtungen aus Block 1

- Die globale Line-Coverage beträgt 19,9 Prozent. Große UI- und Firebase-nahe
  Bereiche werden in späteren Integrations- und Emulatorblöcken risikobasiert
  weiter geprüft.
- Legacy-Modelle enthalten weiterhin historische Führerschein-Felder. Der aktive
  Verifizierungsablauf verlangt nachweislich nur Identitätsdokument und
  Fahrzeugschein; eine spätere Bereinigung darf nicht mit einer Verhaltensänderung
  vermischt werden.

## Offene Beobachtungen aus Block 2

- `OBS-001` ist kein Anlass, Rules zu lockern. Block 3 hat keinen Fehler in den
  geprüften legitimen Ein-Konto-Abläufen reproduziert. Im späteren
  Mehrkontentest wird geprüft, ob legitime Zwei-Konten-Abläufe die
  Firestore-Auswertungsgrenze erreichen. Erst ein reproduzierbarer legitimer
  Fehler rechtfertigt eine gezielte Vereinfachung mit vollständiger Rules-
  Regression.
- Der Functions-Einstiegspunkt lädt 30 Exporte unter Node 22 erfolgreich, braucht
  lokal aber rund 30,3 Sekunden. Das ist ein Performancehinweis für spätere
  Deployment-/Cold-Start-Prüfungen, kein fehlgeschlagener Test.
