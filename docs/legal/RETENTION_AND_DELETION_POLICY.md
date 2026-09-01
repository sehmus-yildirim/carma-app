# Plaqa Aufbewahrungs- und Loeschkonzept

Stand: 1. September 2026

## 1. Grundsaetze

Plaqa speichert personenbezogene Daten nur, solange sie fuer die jeweilige App-Funktion, Sicherheit, Rechtsausuebung oder zwingende gesetzliche Pflichten erforderlich sind. Fristen sind Hoechstfristen, keine Mindestfristen. Ein rechtlich dokumentierter Sperrvermerk darf eine Loeschung nur fuer den konkret erforderlichen Datensatz und Zeitraum aussetzen.

## 2. Technisch definierte Fristen

| Daten | Regelfrist | Loeschmechanismus |
|---|---:|---|
| Story-Inhalte und Medien | 24 Stunden | Scheduler plus Storage-Bereinigung |
| Kennzeichenhinweise/-meldungen und zugehoerige Medien | 24 Stunden, soweit kein Moderations-/Rechtsfall | Scheduler plus Storage-Bereinigung |
| ausstehende Kontaktanfragen | 48 Stunden | Ablaufzeit und serverseitige Bereinigung |
| Such-Probes, Cooldowns und Profilaufrufereignisse | 24 Stunden | Ablaufzeit/TTL |
| kurzlebige Kontaktberechtigungen | 10 Minuten | Ablaufzeit/TTL |
| Website-Formularmetadaten | 48 Stunden | Firestore TTL |
| Mail-Autoantwort-Cooldown | 24 Stunden | Firestore TTL |
| pseudonyme Mail-Autoantwortnachweise | 90 Tage | Firestore TTL |
| normale Support-/Feedbackvorgaenge | spaetestens 365 Tage | `retentionUntil` plus Firestore TTL |
| Kinderschutz-/Sicherheitsvorgaenge | spaetestens 730 Tage | `retentionUntil` plus Firestore TTL; kuerzere Loeschung nach Fallabschluss pruefen |
| Datenexport-/Betroffenenrechtsnachweise | spaetestens 3 Jahre | `retentionUntil` plus Firestore TTL |
| Sicherheitsaktivitaeten | spaetestens 365 Tage | serverseitiges `retentionUntil` plus Firestore TTL |
| Kontoloeschungsnachweis | spaetestens 3 Jahre | serverseitiges `retentionUntil` plus Firestore TTL |
| Verifizierungsdokumente nach Entscheidung | hoechstens 30 Tage | Scheduler plus Storage-Bereinigung |
| unvollstaendige Verifizierungssitzung | Sitzungsablauf laut Backendkonfiguration | Firestore TTL; lokale Aufnahmen temporaer loeschen |

TTL-Loeschungen erfolgen bei Firebase nicht sekundengenau. Daten duerfen nach Fristablauf nicht mehr fachlich genutzt werden. Medien mit kaskadierenden Abhaengigkeiten werden durch eigene Bereinigungsfunktionen statt allein durch Firestore TTL geloescht.

## 3. Kontobezogene Daten

- Aktive Konto-, Profil-, Fahrzeug-, Chat- und Feed-Daten bleiben grundsaetzlich bis zur Nutzerloeschung, inhaltlichen Loeschung oder bis zum Wegfall des Funktionszwecks gespeichert.
- Bei Kontoloeschung werden Auth-Konto, private Unterkollektionen, eigene oeffentliche Spiegel, Fahrzeug-/Kennzeichendaten, Medien, Beziehungen und technische Limits entfernt.
- Eigene Likes/Reaktionen in fremden Inhalten werden entfernt.
- Eigene Kommentare/Antworten und gemeinsame Chatmetadaten werden geloescht oder pseudonymisiert, wenn die Rechte anderer Nutzer eine vollstaendige physische Entfernung verhindern. Der Anzeigename wird durch `Geloeschtes Konto` ersetzt; privater Text und Fotoverweise werden entfernt.
- Moderationsmeldungen koennen in datensparsamer Form erhalten bleiben, wenn dies fuer Schutz, Rechtsverteidigung oder Nachweispflichten notwendig ist. Eine konkrete Rechtsgrundlage und Loeschfrist ist je Fall zu dokumentieren.

## 4. Datenexport

Die App legt eine authentifizierte Exportanfrage an. Der Betreiber muss Identitaet, Umfang und sichere Zustellung pruefen, das Exportpaket aus den produktiven Systemen erstellen, Drittpersonendaten begrenzen und den Vorgang dokumentieren. Ein vollautomatischer Download ist derzeit nicht implementiert und darf in Rechtstexten nicht behauptet werden.

## 5. Backups und externe Systeme

Loeschungen muessen auch Google/Firebase-, IONOS- und Plattformprozesse beruecksichtigen. Daten in Sicherungskopien duerfen nur bis zur regulaeren Ueberschreibung gesperrt vorgehalten und nicht wieder produktiv verarbeitet werden. Konkrete Anbieterfristen sind vor Release aus den Auftragsverarbeitungsvertraegen zu uebernehmen.

## 6. Pflichtkontrollen

- monatlicher Stichprobenbericht ueber abgelaufene TTL-Dokumente und Schedulerfehler;
- quartalsweiser Test einer vollstaendigen Kontoloeschung mit zwei verbundenen Testkonten;
- quartalsweiser Test einer Exportanfrage und sicheren Auslieferung;
- sofortige Untersuchung bei Loesch-, Scheduler- oder Storage-Fehlern;
- jaehrliche Fristenpruefung mit Datenschutzberatung.

