# plaqa QA Bug Register

Stand: 2026-08-29

| ID | Priorität | Bereich | Befund | Status | Nachweis |
|---|---:|---|---|---|---|
| BUG-001 | P1 | Kennzeichensuche | Die globale Launch-Konfiguration deaktivierte die Monatsbegrenzung, die UI blockierte bei erschöpftem Legacy-Kontingent dennoch Suche und Kontaktanfrage und zeigte den Kontingentkasten. | FIXED LOCAL | Regressionstest und 231/231 Gesamttests bestanden |
| BUG-002 | P1 | Registrierung/Auth-Gate | Registrierung und Login legten Firestore-Basisdaten parallel zum Auth-Gate an. Das Rennen führte sporadisch zur sichtbaren Meldung, dass Basisdaten nicht vollständig angelegt werden konnten. | FIXED LOCAL | 4/4 Integrationstests, 234/234 Flutter-Regressionstests und Analyze bestanden |
| BUG-003 | P0 | Kontaktanfrage/Firestore Rules | Der legitime Client las vor der atomaren Erstellung fehlende deterministische Anfrage-/Chatpfade; die Regeln lehnten diesen Zwei-Konten-Pfad ab. | FIXED LOCAL | Redmi-Suche/Anfrage/Annahme bestanden; 109/109 Rules-Tests |
| BUG-004 | P1 | Chat-Blockierung/Firestore Rules | Fehlende Follow-Dokumente und die Auswertungsreihenfolge konnten beim legitimen Blockieren die 1.000-Ausdruck-Grenze erreichen. | FIXED LOCAL | Blockierung aus beiden Kontoperspektiven und Rules-Regression bestanden |
| BUG-005 | P1 | Story-Abfrage/Firestore Rules | Die aktive Story-Abfrage war nicht vollständig mit Ablaufbedingung und Get/List-Regeln vereinbar. | FIXED LOCAL | Story-Query-Regression und 109/109 Rules-Tests |
| BUG-006 | P1 | Lokale Functions-Tests | Die automatisch gestartete Fahrzeugbildgenerierung konnte aus dem Functions-Emulator einen externen Vertex-AI-Aufruf versuchen. | FIXED LOCAL | 100/100 Functions-Tests; authentifizierter Emulator-Aufruf in 62 ms lokal gesperrt |
| A11Y-001 | P2 | Chat-Composer | Der sichtbare Senden-Knopf hatte keine stabile Semantics-Bezeichnung für Assistenztechnik und UI-Automation. | FIXED LOCAL | Widgettest und echter Nachrichtenaustausch auf dem Redmi bestanden |
| OBS-001 | P1-Risiko | Firestore Rules | Einzelne erwartete Negativpfade protokollieren im Emulator weiter die Grenze von 1.000 Regelausdrücken. Der zuvor betroffene legitime Zwei-Konten-Blockierpfad ist korrigiert und reproduzierbar grün. | MONITORED | 109/109 Rules-Tests und echter Redmi-Mehrkontenpfad bestanden |
| OBS-002 | P1-Risiko | Push/App Check | Firebase Messaging besitzt keinen lokalen Emulator; produktive Tokens, Zustellung und App-Check-Metriken wurden aus Sicherheitsgründen nicht verwendet. | MANUAL REQUIRED | Gate-6-Release-Konfiguration und Messaging-Start geprüft; Live-Geräteprüfung offen |

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

- `OBS-001` ist kein Anlass, Rules zu lockern. Die zuvor betroffene legitime
  Zwei-Konten-Blockierung wurde in Block 5 korrigiert und auf dem Redmi sowie in
  109/109 Rules-Tests bestätigt. Die verbleibenden Meldungen stammen aus
  erwarteten Negativpfaden und bleiben überwacht.
- Der Functions-Einstiegspunkt lädt 30 Exporte unter Node 22 erfolgreich, braucht
  lokal aber rund 30,3 Sekunden. Das ist ein Performancehinweis für spätere
  Deployment-/Cold-Start-Prüfungen, kein fehlgeschlagener Test.

## Block-5-Korrekturen

Die Kontaktanfrage darf fehlende, deterministische Eigenpfade lesen, bevor
Anfrage, Chat und Initialnachricht atomar angelegt werden. Fremde Nutzer erhalten
dadurch keinen zusätzlichen Zugriff. Chat-Blockierung prüft den sicheren
Statuswechsel früh und behandelt fehlende Follow-Beziehungen explizit. Story-
Listen bleiben auf aktive, noch nicht abgelaufene Dokumente begrenzt. Alle
Änderungen wurden gegen die vollständige Rules-Suite und auf dem echten Redmi
mit zwei künstlichen Emulator-Konten geprüft.

Die Fahrzeugbild-Function beendet authentifizierte Aufrufe im lokalen Firebase-
Functions-Emulator jetzt vor Firestore- und Vertex-Zugriffen. Produktion bleibt
unverändert; der Schutz ist durch Unit-Tests und einen echten lokalen Callable-
Aufruf nachgewiesen.

## Gate-6-Ergebnis

Gate 6 erzeugte keinen neuen Produktfehler. Signierung, R8, Resource Shrinking,
AAB/APK-Struktur, Release-Manifest, Installation, Kaltstart, Speicherzustand und
Release-Runtime bestanden. Die MIUI-Bestätigung beim Wiederherstellen der
vorherigen Debug-APK war ein Gerätesicherheitsdialog und kein App-Defekt.
