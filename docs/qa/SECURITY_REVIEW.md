# plaqa Gate 8 Security Review

Stand: 2026-08-29
Scan-ID: `d316c0fd-3693-447f-badf-1864041b52df`
Ergebnis: 11 bestätigte Befunde, davon 5 `HIGH` und 6 `MEDIUM`

## Umfang

Geprüft wurden die releasekritischen Vertrauensgrenzen der Flutter-App,
Firebase Authentication, Cloud Functions, Firestore-/Storage-Regeln, Uploads,
Kontolöschung, Android-Native-Bridge, Hosting und Releasekonfiguration. Der
Scan wurde gegen den unveränderten Git-Snapshot
`a8ebd42a9a039f70ff17a50e85adce43f4fdf077` ausgeführt und anschließend
versiegelt. Spätere Gate-8-Korrekturen betreffen Firebase-iOS-Zuordnung,
Onboarding und Paket-Lockfiles, nicht die unten beschriebenen Pfade.

## Hohe Befunde

| ID | Befund | Hauptpfade | Releasebedingung |
|---|---|---|---|
| SEC-001 | Wiederholte Kennzeichensuchen können einen kürzlich präzise gespeicherten Fahrzeugstandort triangulieren. | `functions/plate_search.js`, `functions/profile_vehicle_management.js` | Nur grobe Distanz/Zelle zurückgeben, Anti-Probing- und Zielkontingente ergänzen. |
| SEC-002 | Bezahlte KI-Bildkontingente sind pro Fahrzeug statt zusätzlich pro Konto begrenzt. | `functions/index.js`, `functions/profile_vehicle_management.js` | Kontobudget, Fahrzeuglimit/Verifizierung und Kosten-Circuit-Breaker ergänzen. |
| SEC-003 | Direkte Storage-Erstellung erlaubt große verwaiste Medien ohne Gesamtquote oder vollständige Bereinigung. | `storage.rules`, `functions/report_cleanup.js` | Uploadreservierung, Gesamtquoten und vollständige Orphan-Bereinigung einführen. |
| SEC-004 | Kontolöschung lässt Likes, Kommentare, Antworten und Reaktionen unter fremden Beiträgen zurück. | `firestore.rules`, `functions/account_security.js` | Fremdpfade per Collection Group löschen oder irreversibel anonymisieren. |
| SEC-005 | Kontolöschung lässt einen Begegnungsspiegel unter dem überlebenden Fahrzeugprofil zurück. | `profile_vehicle_encounter_repository.dart`, `functions/account_security.js` | Beide Spiegel vor dem Top-Level-Dokument resumierbar entfernen/anonymisieren. |

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

## Behebungsreihenfolge

1. SEC-001 bis SEC-005 in getrennten, reviewbaren Änderungen beheben.
2. Für jeden Befund Unit-, Rules-, Functions- und passende Integrations-/Geräte-
   Regression ergänzen.
3. SEC-006 bis SEC-011 schließen oder vor internem Rollout mit dokumentierter
   Verantwortlichkeit und Frist risikoseitig akzeptieren.
4. Vollregression, neuen Security-Diff-Scan und neue signierte Artefakte
   ausführen.
5. Erst danach App-Check-Messung, internen Store-Rollout und externe Abnahme
   beginnen.
