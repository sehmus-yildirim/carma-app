# Plaqa Pruefpaket fuer die externe Rechtsberatung

Stand: 1. September 2026  
Produkt: Plaqa, mobile Fahrzeugkommunikations- und Social-App  
Gebiet: Deutschland, Oesterreich, Schweiz  
Mindestalter: 16 Jahre

## 1. Betreiberangaben

- Sehmus Yildirim
- Bremer Strasse 254e
- 21077 Hamburg
- Datenschutz: `privacy@plaqa.de`
- Support, Moderation und Kinderschutz: `support@plaqa.de`

Offen: Rechtsform, Gewerbe-/Registerangaben, Umsatzsteuer-ID, Telefonnummer soweit gesetzlich erforderlich, zustaendige Aufsicht und Verbraucherstreitbeilegungsangaben. Diese Daten wurden bewusst nicht erfunden.

## 2. Zur Pruefung uebergebene Unterlagen

- `docs/legal/DATA_FLOW_INVENTORY.md`
- `docs/legal/RETENTION_AND_DELETION_POLICY.md`
- `docs/legal/MODERATION_AND_COMPLAINTS.md`
- `docs/legal/GOOGLE_PLAY_DATA_SAFETY.md`
- App-Texte in `lib/features/settings/presentation/settings_screen.dart`
- Website: Datenschutz, Nutzungsbedingungen, Impressum, Community-Richtlinien, Kinderschutz, Meldestelle und Kontoloeschung unter `hosting/`
- technische Regeln: `firestore.rules`, `storage.rules`, `firestore.indexes.json`
- Kontoloeschung: `functions/account_security.js`

## 3. Kritische Rechtsfragen

1. Rechtliche Einordnung des Dienstes und Anwendbarkeit von DSA, DDG, NetzDG sowie oesterreichischem/schweizerischem Recht.
2. Rechtsgrundlagen fuer Kennzeichenverarbeitung, Standortschutz, Kontaktanbahnung, Profilaufrufe, Meldungen und Moderation.
3. Erforderlichkeit einer Datenschutz-Folgenabschaetzung fuer Standort, Kennzeichen, soziale Beziehungen und spaetere Dokumentverifizierung.
4. Wirksamkeit von Mindestalter 16, Altersabfrage und Kinderschutzstandard.
5. AGB-Einbeziehung, Versionswechsel, Kuendigung, virtuelle Inhalte, Nutzerlizenzen und Moderationsrechte.
6. Haftungsregelung: zwingende Haftung unangetastet; angemessene Begrenzung bei leichter Fahrlaessigkeit; keine unzulaessigen Totalfreizeichnungen.
7. Zulassung der Fahrzeug-/Kennzeichen- und KI-Bildfunktionen sowie Rechte an hochgeladenen/generierten Medien.
8. Auftragsverarbeitung, Unterauftragsverarbeiter und Drittlandtransfers bei Google/Firebase/Google Cloud, Google Play, Apple und IONOS.
9. Aufbewahrungsfristen, Backups, Rechtsverteidigung, Moderationsbeweise und Pseudonymisierung gemeinsamer Inhalte.
10. Google-Play-Datensicherheit, Konto-Loesch-URL und Storekommunikation.

## 4. Schutzklausel-Strategie

Die Texte sollen Plaqa umfassend, aber wirksam schuetzen:

- Plaqa ist kein Notruf-, Pannen-, Abschlepp-, Polizei-, Versicherungs- oder Identitaetsgarantiedienst.
- Nutzerangaben, Kennzeichen, Standorte, Inhalte, KI-Ausgaben, Kontakte und Fahrzeugzuordnungen koennen falsch, unvollstaendig oder missbraeuchlich sein.
- Nutzer bleiben fuer Rechtmaessigkeit, Rechte, Verkehrssicherheit, Beweissicherung und ihre Kommunikation verantwortlich.
- Plaqa darf bei Gefahr, Missbrauch, Rechtsverstoessen und Sicherheitsrisiken Inhalte/Accounts verhaeltnismaessig beschraenken.
- Verfuegbarkeit, Fehlerfreiheit, bestimmte Reichweite, Kontaktreaktion oder erfolgreicher Hinweis werden nicht garantiert.
- Gesetzlich zwingende Haftung, insbesondere fuer Vorsatz, grobe Fahrlaessigkeit, Leben, Koerper, Gesundheit, Garantien und Produkthaftung, wird nicht ausgeschlossen.
- Bei leicht fahrlaessiger Verletzung wesentlicher Vertragspflichten wird die Haftung auf den typischen vorhersehbaren Schaden begrenzt, soweit rechtlich zulaessig.
- Unwirksame Einzelklauseln sollen die uebrigen Bedingungen nicht beseitigen; es gilt die gesetzliche Regelung.

Eine Garantie, dass kein Nutzer Klage erhebt, ist rechtlich und praktisch unmoeglich. Ziel ist, berechtigte Risiken zu reduzieren und unwirksame Ueberabsicherung zu vermeiden.

## 5. Vor externer Freigabe nicht als abgeschlossen markieren

- Rechtsform/Impressumspflichtangaben
- AV-Vertraege und Unterauftragsverarbeiterlisten
- DSFA-Entscheidung und Transferpruefung
- Moderationsorganisation und Kinderschutzeskalation
- finale AGB-/Datenschutz-/Storefreigabe fuer DE/AT/CH
- Verifizierungsfunktion und Dokumentverarbeitung
- Schritt 12 des Auftrags: Anwaltsfeedback kann erst nach Erhalt umgesetzt werden

## 6. Rueckmeldeformat

Die Rechtsberatung soll Aenderungen je Fundstelle liefern: Datei/URL, Abschnitt, Risiko, zwingende Formulierung, Gebiet (DE/AT/CH), Prioritaet und Freigabestatus. Danach werden die Korrekturen technisch umgesetzt, getestet und erneut zur Freigabe vorgelegt.

