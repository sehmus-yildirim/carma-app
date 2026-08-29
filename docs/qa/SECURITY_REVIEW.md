# plaqa Gate 8 Security Review

Stand: 2026-08-29
Scan-ID: `d316c0fd-3693-447f-badf-1864041b52df`
Ergebnis: 11 bestätigte Befunde, davon 5 `HIGH` und 6 `MEDIUM`
Aktueller Stand: SEC-001 bis SEC-005 lokal behoben; SEC-006 bis SEC-011 offen

## Umfang

Geprüft wurden die releasekritischen Vertrauensgrenzen der Flutter-App,
Firebase Authentication, Cloud Functions, Firestore-/Storage-Regeln, Uploads,
Kontolöschung, Android-Native-Bridge, Hosting und Releasekonfiguration. Der
Scan wurde gegen den unveränderten Git-Snapshot
`a8ebd42a9a039f70ff17a50e85adce43f4fdf077` ausgeführt und anschließend
versiegelt. Spätere Gate-8-Korrekturen betreffen Firebase-iOS-Zuordnung,
Onboarding und Paket-Lockfiles, nicht die unten beschriebenen Pfade.

## Nachprüfung der hohen Befunde

SEC-001 bis SEC-005 wurden nach dem versiegelten Ausgangsscan lokal behoben und
mit vollständigen Functions-, Rules- und Flutter-Regressionen geprüft. Die
technischen Maßnahmen und Grenzwerte stehen in
`docs/qa/HIGH_SECURITY_REMEDIATION.md`.

Der Security-Diff-Scan `0f935310-dca6-4856-ba34-a4d8c9591041` fand in einem
Zwischenstand zwei Umgehungsmöglichkeiten: ein fehlendes zielweites
Kennzeichenkontingent und eine Storage-Löschen-/Neuhochladen-Race. Beide wurden
anschließend geschlossen und erneut getestet. Es wurde nichts deployt oder
produktiv erzwungen.

## Ursprüngliche hohe Befunde

| ID | Befund | Hauptpfade | Aktueller Status |
|---|---|---|---|
| SEC-001 | Wiederholte Kennzeichensuchen können einen kürzlich präzise gespeicherten Fahrzeugstandort triangulieren. | `functions/plate_search.js`, `functions/profile_vehicle_management.js` | **BEHOBEN LOKAL** - grobe Standortzelle, Anti-Probing- und Zielkontingente ergänzt. |
| SEC-002 | Bezahlte KI-Bildkontingente sind pro Fahrzeug statt zusätzlich pro Konto begrenzt. | `functions/index.js`, `functions/profile_vehicle_management.js` | **BEHOBEN LOKAL** - transaktionales Konto- und Fahrzeugkontingent vor dem kostenpflichtigen Aufruf. |
| SEC-003 | Direkte Storage-Erstellung erlaubt große verwaiste Medien ohne Gesamtquote oder vollständige Bereinigung. | `storage.rules`, `functions/report_cleanup.js` | **BEHOBEN LOKAL** - Uploadreservierung, Gesamtquoten, Finalisierung und Orphan-Bereinigung ergänzt. |
| SEC-004 | Kontolöschung lässt Likes, Kommentare, Antworten und Reaktionen unter fremden Beiträgen zurück. | `firestore.rules`, `functions/account_security.js` | **BEHOBEN LOKAL** - soziale Fremdpfade werden gelöscht oder irreversibel anonymisiert. |
| SEC-005 | Kontolöschung lässt einen Begegnungsspiegel unter dem überlebenden Fahrzeugprofil zurück. | `profile_vehicle_encounter_repository.dart`, `functions/account_security.js` | **BEHOBEN LOKAL** - beide Spiegel werden vor dem Top-Level-Dokument idempotent entfernt. |

## Mittlere Befunde

| ID | Befund | Releasebedingung |
|---|---|---|
| SEC-006 | Kontaktanfragen besitzen keine belastbare serverseitige Gesamtquote, Ablaufzeit und Resend-Sperre. | Serverzeit, Kontingente und Cooldowns serverseitig erzwingen. |
| SEC-007 | Optionale Kontaktanfrage-Projektionen und Ablaufwerte sind nicht vollständig typ- und zeitgebunden. | Striktes Gesamtschema und serverrelative Zeitgrenzen. |
| SEC-008 | Medienpfade und clientgeschriebene URLs sind nicht fest miteinander verbunden. | Nur kanonische Storage-Pfade oder serverseitig abgeleitete, erlaubte URLs. |
| SEC-009 | Android öffnet beziehungsweise streamt beliebige URI-Schemes ohne feste Zeit- und Byteobergrenzen. | Scheme-/Host-Allowlist, Timeouts, Byte- und MIME-Prüfung. |
| SEC-010 | Profilfotos sind für jedes angemeldete Konto lesbar, unabhängig von Profil- und Blockstatus. | Storage-Zugriff an dieselbe Sichtbarkeits- und Blocklogik binden. |
| SEC-011 | `recordProfileView` kann Zähler und Schreibkosten ohne Deduplizierung oder Limit erhöhen. | Zugriff, PeriodendDuplikat und Account-/Gerätelimits ergänzen. |

## Positive Nachweise

- Firestore und Storage enden mit Default-Deny-Regeln.
- Konto-Löschreservierung blockiert weitere normale Regelzugriffe.
- MFA-Wiederherstellung verlangt verifizierte Identität und zwei getrennte
  aktive Admin-Freigaben.
- Auth-Aktionslinks erlauben nur sichere plaqa-Weiterleitungen.
- Website-Handler besitzt feste Empfänger, Eingabegrenzen, CR/LF-Schutz,
  Honeypot-, Zeit- und Rate-Limit-Kontrollen.
- Hosting setzt CSP, Permissions-Policy, Frame-Schutz, nosniff und
  Referrer-Policy.
- Keine Klartext-Service-Account-, SMTP-, Apple- oder Signierpasswörter wurden
  im geprüften Quellumfang gefunden.
- Android-Release scheitert bei fehlendem Signiermaterial und fällt nicht
  still auf Debug-Signing zurück.

## Externe Grenzen

Nicht als bestanden gewertet wurden: tatsächlich deployte Rules/Functions,
produktive App-Check-Metriken und Erzwingung, Firebase-Budgets, Store- und
Provider-Konfiguration, finale iOS-Entitlements sowie Live-Push. Diese Zustände
lassen sich aus dem Repository nicht beweisen und wurden nicht verändert.

## Weiteres Vorgehen

1. SEC-006 bis SEC-011 schließen oder vor internem Rollout mit dokumentierter
   Verantwortlichkeit und Frist risikoseitig akzeptieren.
2. Nach den verbleibenden Sicherheitsänderungen erneut Vollregression,
   Security-Diff-Scan und neue signierte Artefakte
   ausführen.
3. Erst danach App-Check-Messung, internen Store-Rollout und externe Abnahme
   beginnen.
