# Rechtliches Release-Input

Stand: 2026-07-03

Diese Datei sammelt die Angaben, die vor einem echten Release in Impressum,
Datenschutzerklärung, AGB/Nutzungsbedingungen und Play Console übernommen
werden müssen.

Wichtig: Die aktuellen Texte in der App sind Entwürfe. Finale Texte sollten
juristisch geprüft werden, bevor sie veröffentlicht werden.

## 1. Impressum

Bitte bereitstellen:

- Verantwortlicher Anbieter / Betreiber:
- Rechtsform, falls vorhanden:
- Vollständige ladungsfähige Anschrift:
- E-Mail-Adresse:
- Telefonnummer, falls veröffentlicht:
- Support-E-Mail:
- Vertretungsberechtigte Person, falls Firma:
- Handelsregister / Registergericht / Registernummer, falls vorhanden:
- Umsatzsteuer-ID, falls vorhanden:
- Aufsichtsbehörde oder berufsrechtliche Angaben, falls relevant:

In der App zu befüllen:

- `lib/features/settings/presentation/settings_screen.dart`
- Abschnitt `Rechtliches > Impressum`

## 2. Datenschutzerklärung

Bitte bereitstellen oder bestätigen:

- Verantwortlicher:
- Kontakt für Datenschutzanfragen:
- Datenschutzbeauftragter, falls vorhanden:
- Hosting / Firebase-Projekt:
- Ob Firebase nur in EU-Regionen oder auch außerhalb der EU verarbeitet:
- Ob Google Analytics genutzt werden soll:
- Ob Crashlytics genutzt werden soll:
- Ob Push Notifications genutzt werden sollen:
- Ob App Check genutzt werden soll:
- Support-Kontakt für Auskunft, Löschung und Datenexport:

### Datenarten in plaqa

Bitte prüfen/bestätigen:

- Konto: E-Mail, UID, Auth-Daten
- Profil: Anzeigename, Profilbild, Telefonnummer optional, Geburtsdatum optional
- Fahrzeug: Marke, Modell, Farbe, Kennzeichen
- Standort: Kennzeichen-Suche, Melden, Standortanhang im Chat
- Chat: Nachrichten, Medien, Dokumente, Standort, Kontakte, Sprachnachrichten
- Story: Medien, Text, Sticker, Aufrufe, Antworten
- Hinweise/Melden: Kategorie, Kennzeichen, Adresse/Standort, optional Foto
- Verifizierung: Profil-/Fahrzeug-/Dokumentnachweise
- Sicherheit: Blockierungen, Meldungen, Missbrauchsschutz

### Speicherfristen

Bitte entscheiden:

- Accountdaten:
- Profildaten:
- Kennzeichen-/Fahrzeugdaten:
- Chatnachrichten:
- Chat-Anhänge:
- Storys:
- Story-Aufrufe:
- Meldehinweise:
- Gesendete Hinweise:
- Verifizierungsdokumente:
- Gelöschte Konten:
- Logs/technische Fehlerdaten:

### Nutzerrechte

In der App bereits vorbereitet:

- Datenexport anfordern
- Konto löschen anfordern
- Datenschutz-/Einwilligungsübersicht

Noch final zu entscheiden:

- Wie wird Datenexport tatsächlich bearbeitet?
- Innerhalb welcher Frist wird Datenexport geliefert?
- Wie wird eine Löschung technisch durchgeführt?
- Welche Daten dürfen/ müssen trotz Löschung aufbewahrt werden?

In der App zu befüllen:

- `lib/features/legal/presentation/privacy_policy_screen.dart`
- `lib/features/settings/presentation/settings_screen.dart`
- Abschnitt `Rechtliches > Datenschutzerklärung`

## 3. AGB / Nutzungsbedingungen

Bitte entscheiden:

- Mindestalter:
- Registrierungsvoraussetzungen:
- Zulässige Nutzung:
- Verbotene Nutzung:
- Regeln für Kennzeichen-Suche:
- Regeln für Kontaktanfragen:
- Regeln für Chat und Story:
- Regeln für anonyme Hinweise:
- Notfall-Hinweis: plaqa ersetzt keine Polizei, Feuerwehr oder Rettungsdienste.
- Umgang mit Missbrauch, Sperrung und Löschung:
- Verifizierungspflichten:
- Haftungsgrenzen:
- Verfügbarkeit der App:
- Änderung der Bedingungen:
- Kündigung / Kontoauflösung:

In der App zu befüllen:

- `lib/features/legal/presentation/terms_screen.dart`
- `lib/features/settings/presentation/settings_screen.dart`
- Abschnitt `Rechtliches > AGB`

## 4. Community-Regeln / Verantwortungsvolle Nutzung

Bitte final bestätigen:

- Keine Belästigung
- Keine Falschmeldungen
- Keine Drohungen
- Keine Veröffentlichung fremder personenbezogener Daten
- Keine missbräuchliche Kontaktaufnahme über Kennzeichen
- Keine Nutzung für Notfälle
- Keine diskriminierenden oder rechtswidrigen Inhalte
- Verstöße können zu Sperrung oder Löschung führen

Aktuell technisch vorbereitet:

- Legal Consent `responsibleUse`
- Legal Consent `noEmergencyUse`

## 5. Account löschen und Datenexport

Aktueller Stand:

- Die Einstellungen enthalten bereits Funktionen zum Anfordern von Konto-Löschung
  und Datenexport.
- Der finale Backend-/Support-Prozess muss noch definiert werden.

Bitte entscheiden:

- Wird Konto-Löschung sofort technisch ausgeführt oder zuerst vom Support geprüft?
- Welche Bestätigungs-E-Mail bekommt der Nutzer?
- Welche Daten werden sofort gelöscht?
- Welche Daten werden anonymisiert?
- Welche Daten bleiben aus rechtlichen Gründen zeitweise erhalten?
- In welchem Format wird der Datenexport geliefert?

## 6. Play Console Abgleich

Die finalen Texte müssen mit folgenden Play-Console-Angaben übereinstimmen:

- Datenarten
- Datenzwecke
- Datenweitergabe an Firebase/Google Cloud
- Datenverschlüsselung
- Konto-Löschung
- Datenschutz-URL
- Content Rating

## 7. Quellen / Orientierung

- DSGVO Art. 13: Informationspflichten bei Datenerhebung
  https://gdpr-info.eu/art-13-gdpr/
- DSGVO Art. 15: Auskunftsrecht
  https://gdpr-info.eu/art-15-gdpr/
- DSGVO Art. 17: Recht auf Löschung
  https://gdpr-info.eu/art-17-gdpr/
- DDG § 5 Anbieterkennzeichnung
  https://www.gesetze-im-internet.de/ddg/__5.html

## Nächster Arbeitsschritt

Zuerst Impressum final befüllen. Dafür brauche ich von dir die Angaben aus
Abschnitt 1.
